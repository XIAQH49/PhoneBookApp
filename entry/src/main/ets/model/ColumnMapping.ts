/**
 * 列映射模型：原表列名 → 业务字段（设计规格 3.1 节 column_mapping）。
 * 键名为业务字段名，值为原表列名；值为空串表示该列不存在。
 * 纯 TS 文件：供 ImportLogic 纯逻辑与 Node 验证直接引用。
 */
export class ColumnMapping {
  assignee: string = '';
  name: string = '';
  empNo: string = '';
  phone: string = '';
  called: string = '';
  connected: string = '';
  intention: string = '';

  /** 序列化为 JSON 存储格式（键名即业务字段名） */
  toRecord(): Record<string, string> {
    const rec: Record<string, string> = {};
    rec['assignee'] = this.assignee;
    rec['name'] = this.name;
    rec['empNo'] = this.empNo;
    rec['phone'] = this.phone;
    rec['called'] = this.called;
    rec['connected'] = this.connected;
    rec['intention'] = this.intention;
    return rec;
  }

  /** 从 JSON 存储格式还原 */
  static fromRecord(r: Record<string, string>): ColumnMapping {
    const m: ColumnMapping = new ColumnMapping();
    m.assignee = r['assignee'] ?? '';
    m.name = r['name'] ?? '';
    m.empNo = r['empNo'] ?? '';
    m.phone = r['phone'] ?? '';
    m.called = r['called'] ?? '';
    m.connected = r['connected'] ?? '';
    m.intention = r['intention'] ?? '';
    return m;
  }
}
