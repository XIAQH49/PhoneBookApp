/**
 * 导入数据准备（设计规格 4.1 节）：列识别、行构建、已打格式探测。
 * 纯逻辑文件（.ts）：输入 ParsedSheet（CSV/XLSX 解析结果），输出合并行数据与元信息。
 */
import { ColumnMapping } from '../model/ColumnMapping';
import { NumberParseService } from './NumberParseService';
import { MergeService, CalledValue } from './MergeService';
import type { MergeRowData } from './MergeService';
import type { ParsedSheet } from './CsvService';

/** 导入准备结果 */
export interface ImportPrepareResult {
  mapping: ColumnMapping;
  allColumns: string[];
  rows: MergeRowData[];
  calledValueFormat: string;
  /** 跳过的完全空行数（诊断用） */
  skippedEmpty: number;
}

interface KnownColumnDef {
  field: string;
  candidates: string[];
}

/** 已知列定义：候选名按优先级排列，支持"包含匹配"（如"是否已打（是/否）"） */
const KNOWN_COLUMNS: KnownColumnDef[] = [
  { field: 'assignee', candidates: ['责任人'] },
  { field: 'name', candidates: ['姓名'] },
  { field: 'empNo', candidates: ['工号'] },
  { field: 'phone', candidates: ['手机', '手机号', '联系电话', '电话'] },
  { field: 'called', candidates: ['是否已打', '已打', '是否已拨打'] },
  { field: 'connected', candidates: ['是否打通', '打通'] },
  { field: 'intention', candidates: ['是否有意向', '意向'] }
];

export class ImportLogic {
  /**
   * 从解析出的表格构建导入数据：
   * 列识别（精确优先、包含兜底，每个表头至多匹配一个业务字段）、
   * 行构建（rawData 保留全部原始列、号码清洗、行键、已打判定）、
   * 已打列导出格式探测。
   */
  static prepare(sheet: ParsedSheet): ImportPrepareResult {
    const headers: string[] = sheet.headers;
    const mapping: ColumnMapping = ImportLogic.matchColumns(headers);
    const calledValues: string[] = [];
    const rows: MergeRowData[] = [];
    let skippedEmpty: number = 0;
    let rowNo: number = 2; // 表头为第 1 行
    for (const values of sheet.rows) {
      const raw: Record<string, string> = {};
      for (let c = 0; c < headers.length; c++) {
        raw[headers[c]] = c < values.length ? values[c] : '';
      }
      const name: string = ImportLogic.cell(raw, mapping.name);
      const empNo: string = ImportLogic.cell(raw, mapping.empNo);
      const phoneRaw: string = ImportLogic.cell(raw, mapping.phone);
      const assignee: string = ImportLogic.cell(raw, mapping.assignee);
      const calledRaw: string = ImportLogic.cell(raw, mapping.called);
      // 完全空行（姓名/工号/手机/责任人均为空）跳过并计数，避免产生无意义行
      if (name.trim() === '' && empNo.trim() === '' && phoneRaw.trim() === '' && assignee.trim() === '') {
        skippedEmpty++;
        rowNo++;
        continue;
      }
      if (mapping.called !== '') {
        calledValues.push(calledRaw);
      }
      const data: MergeRowData = {
        rowKey: MergeService.buildRowKey(empNo, name, phoneRaw),
        rowNo: rowNo,
        assignee: assignee.trim(),
        name: name,
        empNo: empNo,
        phoneRaw: phoneRaw,
        phoneNumbers: NumberParseService.parse(phoneRaw),
        rawData: raw,
        calledFromFile: CalledValue.toBoolean(calledRaw)
      };
      rows.push(data);
      rowNo++;
    }
    const result: ImportPrepareResult = {
      mapping: mapping,
      allColumns: headers.slice(),
      rows: rows,
      calledValueFormat: CalledValue.detectFormat(calledValues),
      skippedEmpty: skippedEmpty
    };
    return result;
  }

  /** 列识别：精确匹配优先，其次包含匹配；每列至多被一个业务字段占用 */
  static matchColumns(headers: string[]): ColumnMapping {
    const mapping: ColumnMapping = new ColumnMapping();
    const used: Set<number> = new Set<number>();
    for (const def of KNOWN_COLUMNS) {
      let idx: number = ImportLogic.findIndex(headers, used, def, true);
      if (idx < 0) {
        idx = ImportLogic.findIndex(headers, used, def, false);
      }
      if (idx >= 0) {
        used.add(idx);
        ImportLogic.setField(mapping, def.field, headers[idx]);
      }
    }
    return mapping;
  }

  private static findIndex(headers: string[], used: Set<number>,
    def: KnownColumnDef, exact: boolean): number {
    for (let i = 0; i < headers.length; i++) {
      if (used.has(i)) {
        continue;
      }
      const h: string = headers[i].trim();
      for (const cand of def.candidates) {
        if (exact) {
          if (h === cand) {
            return i;
          }
        } else {
          if (h.indexOf(cand) >= 0) {
            return i;
          }
        }
      }
    }
    return -1;
  }

  private static setField(mapping: ColumnMapping, field: string, value: string): void {
    if (field === 'assignee') {
      mapping.assignee = value;
    } else if (field === 'name') {
      mapping.name = value;
    } else if (field === 'empNo') {
      mapping.empNo = value;
    } else if (field === 'phone') {
      mapping.phone = value;
    } else if (field === 'called') {
      mapping.called = value;
    } else if (field === 'connected') {
      mapping.connected = value;
    } else if (field === 'intention') {
      mapping.intention = value;
    }
  }

  private static cell(raw: Record<string, string>, header: string): string {
    if (header === '') {
      return '';
    }
    return raw[header] ?? '';
  }
}
