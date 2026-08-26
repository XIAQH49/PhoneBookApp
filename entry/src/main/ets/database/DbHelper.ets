import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';

const TAG: string = 'DbHelper';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'phonebook.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const SQL_CREATE_META: string = `
CREATE TABLE IF NOT EXISTS import_meta (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  file_name TEXT NOT NULL DEFAULT '',
  file_format TEXT NOT NULL DEFAULT '',
  file_encoding TEXT NOT NULL DEFAULT '',
  column_mapping TEXT NOT NULL DEFAULT '{}',
  all_columns TEXT NOT NULL DEFAULT '[]',
  called_value_format TEXT NOT NULL DEFAULT '',
  active INTEGER NOT NULL DEFAULT 0,
  imported_at INTEGER NOT NULL DEFAULT 0
)`;

const SQL_CREATE_CALL_LIST: string = `
CREATE TABLE IF NOT EXISTS call_list (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  meta_id INTEGER NOT NULL DEFAULT 0,
  row_no INTEGER NOT NULL DEFAULT 0,
  row_key TEXT NOT NULL DEFAULT '',
  assignee TEXT NOT NULL DEFAULT '',
  name TEXT NOT NULL DEFAULT '',
  emp_no TEXT NOT NULL DEFAULT '',
  phone_raw TEXT NOT NULL DEFAULT '',
  phone_numbers TEXT NOT NULL DEFAULT '[]',
  called INTEGER NOT NULL DEFAULT 0,
  raw_data TEXT NOT NULL DEFAULT '{}',
  in_file INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL DEFAULT 0
)`;

const SQL_CREATE_CALL_STATUS: string = `
CREATE TABLE IF NOT EXISTS call_status (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  row_id INTEGER NOT NULL,
  status_key TEXT NOT NULL,
  value INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL DEFAULT 0,
  UNIQUE(row_id, status_key)
)`;

const SQL_CREATE_APP_CONFIG: string = `
CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL DEFAULT ''
)`;

const SQL_INDEX_LIST: string[] = [
  'CREATE INDEX IF NOT EXISTS idx_call_list_assignee ON call_list(assignee)',
  'CREATE INDEX IF NOT EXISTS idx_call_list_status ON call_list(assignee, called)',
  'CREATE INDEX IF NOT EXISTS idx_call_list_key ON call_list(row_key)',
  'CREATE INDEX IF NOT EXISTS idx_call_list_meta ON call_list(meta_id)',
  'CREATE INDEX IF NOT EXISTS idx_call_status_row ON call_status(row_id)'
];

/**
 * 数据库初始化与事务封装（设计规格 2.2 / 3.1 节）。
 * 幂等：init 可重复调用；必须在首个页面使用前由 EntryAbility 调用。
 */
export class DbHelper {
  private static store: relationalStore.RdbStore | undefined = undefined;
  private static initPromise: Promise<void> | undefined = undefined;

  static isReady(): boolean {
    return DbHelper.store !== undefined;
  }

  /** 幂等初始化：并发调用共享同一初始化 Promise */
  static init(context: common.Context): Promise<void> {
    if (DbHelper.store !== undefined) {
      return Promise.resolve();
    }
    if (DbHelper.initPromise !== undefined) {
      return DbHelper.initPromise;
    }
    DbHelper.initPromise = DbHelper.doInit(context);
    return DbHelper.initPromise;
  }

  /** 等待初始化完成（供页面冷启动时 await，解决 DB 异步就绪竞态） */
  static async ready(): Promise<void> {
    if (DbHelper.store !== undefined) {
      return;
    }
    if (DbHelper.initPromise !== undefined) {
      await DbHelper.initPromise;
      return;
    }
    throw new Error('DbHelper not initialized');
  }

  private static async doInit(context: common.Context): Promise<void> {
    try {
      const store: relationalStore.RdbStore =
        await relationalStore.getRdbStore(context, STORE_CONFIG);
      try {
        await store.executeSql(SQL_CREATE_META);
        await store.executeSql(SQL_CREATE_CALL_LIST);
        await store.executeSql(SQL_CREATE_CALL_STATUS);
        await store.executeSql(SQL_CREATE_APP_CONFIG);
        for (const sql of SQL_INDEX_LIST) {
          await store.executeSql(sql);
        }
      } catch (e) {
        Logger.error(TAG, 'executeSql failed: ' + (e as Error).message);
        throw e as Error;
      }
      // M3 迁移：import_meta 增列（幂等；老库升级场景）
      await DbHelper.migrateImportMeta(store);
      DbHelper.store = store;
      Logger.info(TAG, 'database ready');
    } catch (e) {
      // 失败后重置，允许后续重试（冷启动竞态/瞬时失败场景）
      DbHelper.initPromise = undefined;
      throw e as Error;
    }
  }

  /** M3 迁移：import_meta 增加 connected_value_format / intention_value_format 列（幂等） */
  private static async migrateImportMeta(store: relationalStore.RdbStore): Promise<void> {
    const additions: string[] = [
      "ALTER TABLE import_meta ADD COLUMN connected_value_format TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE import_meta ADD COLUMN intention_value_format TEXT NOT NULL DEFAULT ''"
    ];
    try {
      const rs: relationalStore.ResultSet = await store.querySql('PRAGMA table_info(import_meta)', []);
      const cols: string[] = [];
      try {
        while (rs.goToNextRow()) {
          cols.push(rs.getString(rs.getColumnIndex('name')));
        }
      } finally {
        try {
          rs.close();
        } catch (e) {
          // 忽略关闭失败
        }
      }
      for (const sql of additions) {
        const col: string = sql.indexOf('connected_value_format') >= 0 ?
          'connected_value_format' : 'intention_value_format';
        if (cols.indexOf(col) < 0) {
          await store.executeSql(sql);
          Logger.info(TAG, 'migrated import_meta: ' + col);
        }
      }
    } catch (e) {
      // 迁移失败不阻塞初始化：新列缺失时格式默认为空串（yes_no 兜底），功能可降级
      Logger.error(TAG, 'migrateImportMeta failed: ' + (e as Error).message);
    }
  }

  static getStore(): relationalStore.RdbStore {
    if (DbHelper.store === undefined) {
      throw new Error('DbHelper not initialized');
    }
    return DbHelper.store;
  }

  /**
   * 单事务编排：fn 内部所有 DAO 纯操作（不含 beginTransaction）统一提交或回滚。
   * 注意：fn 内部禁止再调用带事务的复合方法，避免事务嵌套。
   */
  static async runInTransaction(fn: () => Promise<void>): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    try {
      store.beginTransaction();
    } catch (e) {
      Logger.error(TAG, 'beginTransaction failed: ' + (e as Error).message);
      throw e as Error;
    }
    try {
      await fn();
    } catch (e) {
      try {
        store.rollBack();
      } catch (rbErr) {
        Logger.error(TAG, 'rollBack failed: ' + (rbErr as Error).message);
      }
      throw e as Error;
    }
    try {
      store.commit();
    } catch (e) {
      try {
        store.rollBack();
      } catch (rbErr) {
        Logger.error(TAG, 'rollBack failed: ' + (rbErr as Error).message);
      }
      Logger.error(TAG, 'commit failed: ' + (e as Error).message);
      throw e as Error;
    }
  }
}
