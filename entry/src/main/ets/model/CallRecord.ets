/**
 * 名单行模型（对应 call_list 表，设计规格 3.1 节）。
 */
export class CallRecord {
  id: number = 0;
  metaId: number = 0;
  rowNo: number = 0;
  rowKey: string = '';
  assignee: string = '';
  name: string = '';
  empNo: string = '';
  phoneRaw: string = '';
  /** FR-9 清洗后的规范化号码列表（JSON 存储于 phone_numbers 列） */
  phoneNumbers: string[] = [];
  /** 冗余缓存列（与 call_status 双写，列表查询免联表） */
  called: boolean = false;
  /** 该行全部原始列值（含未知列），导出原样写回 */
  rawData: Record<string, string> = {};
  /** 1=新文件中存在；0=已从新文件消失（保留本机数据） */
  inFile: boolean = true;
  createdAt: number = 0;
  updatedAt: number = 0;
}

/** 状态统计结果（FR-4 进度条） */
export interface CountResult {
  total: number;
  called: number;
}
