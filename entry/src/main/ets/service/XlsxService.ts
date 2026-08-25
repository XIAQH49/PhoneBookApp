/**
 * XLSX 解析/写出服务（T-8，设计规格 4.1/4.4 节）：
 * 基于内置 SheetJS 社区版（libs/xlsx.full.min.js，Apache-2.0）。
 * 功能面已在 Node 用同一库文件做往返验证；真机加载与性能验证见 T-1 spike（docs/06）。
 */
import XLSX from '../libs/xlsx.full.min.js';
import type { XlsxWorkBook, XlsxWorkSheet } from '../libs/xlsx.full.min';
import { NumberParseService } from './NumberParseService';
import type { ParsedSheet } from './CsvService';

export class XlsxService {
  /** 解析 xlsx 为表格（数字型单元格还原为整数文本，防科学计数法） */
  static parse(bytes: Uint8Array): ParsedSheet {
    const wb: XlsxWorkBook = XLSX.read(bytes.buffer, { type: 'array' });
    const first: string = wb.SheetNames[0];
    const ws: XlsxWorkSheet = wb.Sheets[first];
    const rows: Array<Array<string | number | boolean | null | undefined>> =
      XLSX.utils.sheet_to_json(ws, { header: 1, raw: true, defval: '' });
    const strRows: string[][] = [];
    for (const row of rows) {
      const line: string[] = [];
      for (const cell of row) {
        line.push(XlsxService.cellToString(cell));
      }
      strRows.push(line);
    }
    return XlsxService.normalize(strRows);
  }

  /** 写出 xlsx（首行为表头，单工作表"名单"） */
  static write(table: string[][]): Uint8Array {
    const aoa: Array<Array<string | number | boolean>> = [];
    for (const row of table) {
      const line: Array<string | number | boolean> = [];
      for (const cell of row) {
        line.push(cell);
      }
      aoa.push(line);
    }
    const ws: XlsxWorkSheet = XLSX.utils.aoa_to_sheet(aoa);
    const wb: XlsxWorkBook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, '名单');
    const out: ArrayBuffer = XLSX.write(wb, { type: 'array', bookType: 'xlsx' });
    return new Uint8Array(out);
  }

  /** 单元格归一化：数字→整数文本（11 位手机号 float64 无损）、布尔→true/false、空→'' */
  private static cellToString(cell: string | number | boolean | null | undefined): string {
    if (cell === undefined || cell === null) {
      return '';
    }
    if (typeof cell === 'number') {
      return NumberParseService.numberToString(cell);
    }
    if (typeof cell === 'boolean') {
      return cell ? 'true' : 'false';
    }
    return cell;
  }

  /** 与 CsvService 一致的行归一化：跳空行、按表头补齐/截断 */
  private static normalize(rows: string[][]): ParsedSheet {
    const cleaned: string[][] = [];
    for (const r of rows) {
      if (r.length === 1 && r[0] === '') {
        continue;
      }
      cleaned.push(r);
    }
    if (cleaned.length === 0) {
      const empty: ParsedSheet = { headers: [], rows: [] };
      return empty;
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
    const sheet: ParsedSheet = { headers: headers, rows: dataRows };
    return sheet;
  }
}
