/**
 * CSV 服务（设计规格 4.1 节）：编码检测、RFC4180 解析、写出（UTF-8 BOM）。
 *
 * 纯逻辑文件（.ts）：不依赖 ArkTS Kit；解码器通过工厂注入，
 * 设备侧用 util.TextDecoder 适配，Node 侧用全局 TextDecoder 适配。
 */

/** 解码器抽象（兼容 util.TextDecoder 与 Node TextDecoder 的 decode 签名） */
export interface Decoder {
  decode(data: Uint8Array): string;
}

/** 解码器工厂：encoding 支持 'utf-8' / 'gbk'；fatal=true 时无效字节抛异常 */
export interface DecoderFactory {
  create(encoding: string, fatal: boolean): Decoder;
}

/** 解码结果 */
export interface DecodeResult {
  text: string;
  encoding: string;
}

/** 解析后的表格（表头 + 数据行，均为字符串单元格） */
export interface ParsedSheet {
  headers: string[];
  rows: string[][];
}

export class CsvService {
  /**
   * 编码检测：UTF-8 BOM 优先；无 BOM 时严格 UTF-8 解码失败回退 GBK（评审 P1-5）。
   */
  static detectAndDecode(bytes: Uint8Array, factory: DecoderFactory): DecodeResult {
    if (bytes.length >= 3 && bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF) {
      return { text: factory.create('utf-8', false).decode(bytes), encoding: 'utf-8' };
    }
    try {
      const text: string = factory.create('utf-8', true).decode(bytes);
      return { text: text, encoding: 'utf-8' };
    } catch (e) {
      return { text: factory.create('gbk', false).decode(bytes), encoding: 'gbk' };
    }
  }

  /**
   * RFC4180 解析：引号转义（"" → "）、字段内换行/分隔符、CRLF/LF；
   * 分隔符自动识别（, / ; / \t，取表头行中出现次数最多者，默认逗号）；
   * 剥离首部 BOM；跳过完全空行；行长按表头截断/补齐。
   */
  static parseCsv(text: string): ParsedSheet {
    let content: string = text;
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }
    const delimiter: string = CsvService.detectDelimiter(content);
    const rows: string[][] = [];
    let row: string[] = [];
    let field: string = '';
    let inQuotes: boolean = false;
    let i: number = 0;
    const n: number = content.length;
    while (i < n) {
      const ch: string = content.charAt(i);
      if (inQuotes) {
        if (ch === '"') {
          if (i + 1 < n && content.charAt(i + 1) === '"') {
            field += '"';
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        field += ch;
        i++;
        continue;
      }
      if (ch === '"') {
        inQuotes = true;
        i++;
        continue;
      }
      if (ch === delimiter) {
        row.push(field);
        field = '';
        i++;
        continue;
      }
      if (ch === '\r' || ch === '\n') {
        row.push(field);
        field = '';
        rows.push(row);
        row = [];
        if (ch === '\r' && i + 1 < n && content.charAt(i + 1) === '\n') {
          i += 2;
        } else {
          i++;
        }
        continue;
      }
      field += ch;
      i++;
    }
    if (field !== '' || row.length > 0) {
      row.push(field);
      rows.push(row);
    }
    // 跳过完全空行（单空字段行）
    const cleaned: string[][] = [];
    for (const r of rows) {
      if (r.length === 1 && r[0] === '') {
        continue;
      }
      cleaned.push(r);
    }
    if (cleaned.length === 0) {
      return { headers: [], rows: [] };
    }
    const headers: string[] = cleaned[0];
    const dataRows: string[][] = [];
    for (let k = 1; k < cleaned.length; k++) {
      const line: string[] = cleaned[k];
      const normalized: string[] = [];
      for (let c = 0; c < headers.length; c++) {
        normalized.push(c < line.length ? line[c] : '');
      }
      dataRows.push(normalized);
    }
    return { headers: headers, rows: dataRows };
  }

  /**
   * 写出 CSV（RFC4180 + UTF-8 BOM），供 Excel 直接打开不乱码（FR-7）。
   */
  static toCsv(rows: string[][]): string {
    const lines: string[] = [];
    for (const row of rows) {
      const cells: string[] = [];
      for (const cell of row) {
        cells.push(CsvService.escapeCell(cell));
      }
      lines.push(cells.join(','));
    }
    return '\uFEFF' + lines.join('\r\n');
  }

  private static escapeCell(cell: string): string {
    if (cell.indexOf(',') >= 0 || cell.indexOf('"') >= 0 ||
      cell.indexOf('\n') >= 0 || cell.indexOf('\r') >= 0) {
      return '"' + cell.replace(/"/g, '""') + '"';
    }
    return cell;
  }

  /** 分隔符自动识别：在首个换行前（表头行）统计引号外的候选字符出现次数 */
  private static detectDelimiter(content: string): string {
    const candidates: string[] = [',', ';', '\t'];
    const counts: number[] = [0, 0, 0];
    let inQuotes: boolean = false;
    let i: number = 0;
    const n: number = content.length;
    while (i < n) {
      const ch: string = content.charAt(i);
      if (ch === '"') {
        if (inQuotes && i + 1 < n && content.charAt(i + 1) === '"') {
          i += 2;
          continue;
        }
        inQuotes = !inQuotes;
        i++;
        continue;
      }
      if (!inQuotes) {
        if (ch === '\r' || ch === '\n') {
          break;
        }
        for (let c = 0; c < candidates.length; c++) {
          if (ch === candidates[c]) {
            counts[c]++;
            break;
          }
        }
      }
      i++;
    }
    let bestIdx: number = 0;
    for (let c = 1; c < candidates.length; c++) {
      if (counts[c] > counts[bestIdx]) {
        bestIdx = c;
      }
    }
    return candidates[bestIdx];
  }
}
