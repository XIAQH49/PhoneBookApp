/**
 * 全局常量：表名、状态键、配置键、分页等。
 */
export class Constants {
  // 数据表
  static readonly TABLE_IMPORT_META: string = 'import_meta';
  static readonly TABLE_CALL_LIST: string = 'call_list';
  static readonly TABLE_CALL_STATUS: string = 'call_status';
  static readonly TABLE_APP_CONFIG: string = 'app_config';

  // 状态键（6.2 节可扩展状态模型；M3 增加 connected / intention）
  static readonly STATUS_KEY_CALLED: string = 'called';

  // 配置键
  static readonly CONFIG_LAST_ASSIGNEE: string = 'last_assignee';
  static readonly CONFIG_CONFIRM_BEFORE_CALL: string = 'confirm_before_call';
  static readonly CONFIG_EXPORT_SCOPE: string = 'export_scope';
  static readonly CONFIG_CALL_STRIP_COUNTRY: string = 'call_strip_country_code';

  // 导出范围
  static readonly EXPORT_SCOPE_MINE: string = 'mine';
  static readonly EXPORT_SCOPE_ALL: string = 'all';

  // 已打值导出格式
  static readonly CALLED_FORMAT_YES_NO: string = 'yes_no';
  static readonly CALLED_FORMAT_ONE_BLANK: string = 'one_blank';

  // 列表分页大小
  static readonly PAGE_SIZE: number = 100;

  // 未分配责任人（空值）
  static readonly UNASSIGNED: string = '';
}
