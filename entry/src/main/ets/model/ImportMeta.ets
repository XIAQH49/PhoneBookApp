/**
 * 导入元信息模型（对应 import_meta 表，设计规格 3.1 节）。
 * 导出保真依赖：allColumns（原列顺序）+ calledValueFormat（已打列值格式）。
 */
export class ImportMeta {
  id: number = 0;
  fileName: string = '';
  fileFormat: string = '';
  fileEncoding: string = '';
  /** 业务字段 → 原表列名映射（JSON 存储） */
  columnMapping: Record<string, string> = {};
  /** 原表全部列名及顺序（含未知列，JSON 存储） */
  allColumns: string[] = [];
  /** 已打列导出值格式：yes_no / one_blank */
  calledValueFormat: string = '';
  /** 仅一份为生效数据集 */
  active: boolean = false;
  importedAt: number = 0;
}
