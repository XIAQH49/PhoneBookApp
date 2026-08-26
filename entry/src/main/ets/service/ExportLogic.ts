/**
 * 导出组装纯逻辑（FR-7，设计规格 4.4 节）：
 * 按原列顺序组装表格，已打/打通/意向列按各自格式写回，其余列取原始值（未知列不丢）。
 */
import { CalledValue, StatusValue } from './MergeService';

/** 导出用行数据 */
export interface ExportRow {
  called: boolean;
  /** M3：是否打通 */
  connected: boolean;
  /** M3：是否有意向 */
  intention: boolean;
  rawData: Record<string, string>;
}

/** 状态列导出配置（列名 + 各自格式；列名为空串表示原表无该列） */
export interface ExportColumns {
  called: string;
  calledFormat: string;
  connected: string;
  connectedFormat: string;
  intention: string;
  intentionFormat: string;
}

export class ExportLogic {
  /**
   * 组装导出表格（首行为表头，与原文件列顺序一致）。
   * @param allColumns 原表全部列名及顺序
   * @param cols 状态列配置（列名与格式）
   * @param rows 导出行
   */
  static assemble(allColumns: string[], cols: ExportColumns, rows: ExportRow[]): string[][] {
    const out: string[][] = [];
    out.push(allColumns.slice());
    for (const row of rows) {
      const line: string[] = [];
      for (const col of allColumns) {
        if (col === cols.called) {
          line.push(CalledValue.toExportValue(row.called, cols.calledFormat));
        } else if (col === cols.connected) {
          line.push(StatusValue.toExportValue(row.connected, cols.connectedFormat));
        } else if (col === cols.intention) {
          line.push(StatusValue.toExportValue(row.intention, cols.intentionFormat));
        } else {
          line.push(row.rawData[col] ?? '');
        }
      }
      out.push(line);
    }
    return out;
  }

  /** 导出文件名：原名_yyyyMMdd_HHmm.扩展名（评审 P2-10） */
  static buildFileName(originalName: string, now: Date, ext: string): string {
    const dot: number = originalName.lastIndexOf('.');
    const base: string = dot > 0 ? originalName.substring(0, dot) : originalName;
    const pad = (n: number): string => (n < 10 ? '0' + n.toString() : n.toString());
    const ts: string = now.getFullYear().toString() + pad(now.getMonth() + 1) + pad(now.getDate()) +
      '_' + pad(now.getHours()) + pad(now.getMinutes());
    return base + '_' + ts + ext;
  }
}
