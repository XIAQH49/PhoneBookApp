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
      // v0.5.4 一次性修复：并发导入竞态产生的完全重复行去重（标记守卫，仅执行一次）
      await DbHelper.repairDuplicateRows(store);
      // v0.5.4 二次修复：恢复被测试/误导入批次遮蔽的真实数据（标记守卫，仅执行一次）
      await DbHelper.restoreRemovedBatch(store);
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

  /** v0.5.4 修复标记键 */
  private static readonly REPAIR_FLAG_KEY: string = 'repair_dup_done_v1';

  /**
   * v0.5.4 一次性修复：并发导入竞态产生的重复行对半去重。
   * 规则：并发 bug 恰好产生两份（两次导入各一份），同一 row_key 且 raw_data 完全一致的组
   * 按 id 升序（第一次导入在前）保留前半，与后半成对做状态"或"合并后删除后半；
   * 源文件自身的重复行（如"没打通再次加进来"）原样保留，不合并；
   * 同键但内容不同的行不动（v0.5.3 丢行修复语义不回退）。
   * 用 app_config 标记守卫：正常路径仅执行一次（供测试直接调用 dedupeExactDuplicates）。
   */
  static async repairDuplicateRows(store: relationalStore.RdbStore): Promise<void> {
    try {
      let done: boolean = false;
      let flagRs: relationalStore.ResultSet | undefined = undefined;
      try {
        flagRs = await store.querySql(
          'SELECT value FROM app_config WHERE key = ?', [DbHelper.REPAIR_FLAG_KEY]);
        if (flagRs.goToNextRow()) {
          done = flagRs.getString(flagRs.getColumnIndex('value')) === '1';
        }
      } finally {
        if (flagRs !== undefined) {
          try {
            flagRs.close();
          } catch (e) {
            // 忽略关闭失败
          }
        }
      }
      if (done) {
        return;
      }
      // 注意：初始化阶段 DbHelper.store 尚未赋值，不能走 runInTransaction，直接开事务
      try {
        store.beginTransaction();
      } catch (e) {
        Logger.error(TAG, 'repair beginTransaction failed: ' + (e as Error).message);
        throw e as Error;
      }
      try {
        const removed: number = await DbHelper.dedupeExactDuplicates(store);
        if (removed > 0) {
          Logger.info(TAG, 'repaired duplicate rows: removed=' + removed);
        }
        await store.executeSql(
          'INSERT OR REPLACE INTO app_config(key, value) VALUES(?, ?)',
          [DbHelper.REPAIR_FLAG_KEY, '1']);
      } catch (e) {
        try {
          store.rollBack();
        } catch (rb) {
          // 忽略回滚失败
        }
        throw e as Error;
      }
      try {
        store.commit();
      } catch (e) {
        Logger.error(TAG, 'repair commit failed: ' + (e as Error).message);
        throw e as Error;
      }
    } catch (e) {
      // 修复失败不阻塞初始化：重复行问题可后续重试（标记未写入则下次启动再试）
      Logger.error(TAG, 'repairDuplicateRows failed: ' + (e as Error).message);
    }
  }

  /** v0.5.4 二次修复标记键 */
  private static readonly RESTORE_FLAG_KEY: string = 'restore_removed_batch_v1';

  /**
   * v0.5.4 二次修复：恢复"文件中已移除"（in_file=0）的真实数据批次。
   * 场景：并发导入 bug 修复期间，误导入的测试批次把真实批次标记为移除（隐藏），
   * 用户没有源文件可重新导入。规则：
   *  1. 取 in_file=0 行数最多的 meta 批次（真实数据批次）；
   *  2. 若当前生效批次行数远小于恢复批次（<=100 且 <恢复批次/10），判定为误导入
   *     的小测试批次，删除其行/状态/元信息（避免垃圾行混入列表）；
   *  3. 恢复批次置 in_file=1，切换 import_meta.active。
   * 标记守卫：仅执行一次；无隐藏批次时仅写标记。
   */
  static async restoreRemovedBatch(store: relationalStore.RdbStore): Promise<void> {
    try {
      let done: boolean = false;
      let flagRs: relationalStore.ResultSet | undefined = undefined;
      try {
        flagRs = await store.querySql(
          'SELECT value FROM app_config WHERE key = ?', [DbHelper.RESTORE_FLAG_KEY]);
        if (flagRs.goToNextRow()) {
          done = flagRs.getString(flagRs.getColumnIndex('value')) === '1';
        }
      } finally {
        if (flagRs !== undefined) {
          try {
            flagRs.close();
          } catch (e) {
            // 忽略关闭失败
          }
        }
      }
      if (done) {
        return;
      }
      try {
        store.beginTransaction();
      } catch (e) {
        Logger.error(TAG, 'restore beginTransaction failed: ' + (e as Error).message);
        throw e as Error;
      }
      try {
        // 1. 最大的隐藏批次
        let hiddenMetaId: number = -1;
        let hiddenCount: number = 0;
        let hiddenRs: relationalStore.ResultSet | undefined = undefined;
        try {
          hiddenRs = await store.querySql(
            'SELECT meta_id, COUNT(*) AS cnt FROM call_list WHERE in_file = 0 ' +
            'GROUP BY meta_id ORDER BY cnt DESC LIMIT 1', []);
          if (hiddenRs.goToNextRow()) {
            hiddenMetaId = hiddenRs.getLong(hiddenRs.getColumnIndex('meta_id'));
            hiddenCount = hiddenRs.getLong(hiddenRs.getColumnIndex('cnt'));
          }
        } finally {
          if (hiddenRs !== undefined) {
            try {
              hiddenRs.close();
            } catch (e) {
              // 忽略关闭失败
            }
          }
        }
        // 2. 当前生效批次与行数
        let activeMetaId: number = -1;
        let metaRs: relationalStore.ResultSet | undefined = undefined;
        try {
          metaRs = await store.querySql(
            'SELECT id FROM import_meta WHERE active = 1 LIMIT 1', []);
          if (metaRs.goToNextRow()) {
            activeMetaId = metaRs.getLong(metaRs.getColumnIndex('id'));
          }
        } finally {
          if (metaRs !== undefined) {
            try {
              metaRs.close();
            } catch (e) {
              // 忽略关闭失败
            }
          }
        }
        let activeCount: number = 0;
        if (activeMetaId > 0) {
          let cntRs: relationalStore.ResultSet | undefined = undefined;
          try {
            cntRs = await store.querySql(
              'SELECT COUNT(*) AS cnt FROM call_list WHERE meta_id = ?', [activeMetaId]);
            if (cntRs.goToNextRow()) {
              activeCount = cntRs.getLong(cntRs.getColumnIndex('cnt'));
            }
          } finally {
            if (cntRs !== undefined) {
              try {
                cntRs.close();
              } catch (e) {
                // 忽略关闭失败
              }
            }
          }
        }
        // 3. 生效批次判定为误导入的小测试批次时清理之（含状态与元信息）
        if (activeMetaId > 0 && hiddenCount > 0 && activeCount <= 100 &&
          activeCount * 10 < hiddenCount) {
          await store.executeSql(
            'DELETE FROM call_status WHERE row_id IN (SELECT id FROM call_list WHERE meta_id = ?)',
            [activeMetaId]);
          await store.executeSql('DELETE FROM call_list WHERE meta_id = ?', [activeMetaId]);
          await store.executeSql('DELETE FROM import_meta WHERE id = ?', [activeMetaId]);
          Logger.info(TAG, 'removed mistaken test batch: metaId=' + activeMetaId +
            ', rows=' + activeCount);
        }
        // 4. 恢复隐藏批次并切换生效批次
        if (hiddenMetaId > 0) {
          await store.executeSql(
            'UPDATE call_list SET in_file = 1, updated_at = ? WHERE meta_id = ? AND in_file = 0',
            [Date.now(), hiddenMetaId]);
          await store.executeSql('UPDATE import_meta SET active = 0 WHERE active = 1');
          await store.executeSql('UPDATE import_meta SET active = 1 WHERE id = ?', [hiddenMetaId]);
          Logger.info(TAG, 'restored removed batch: metaId=' + hiddenMetaId +
            ', rows=' + hiddenCount);
        }
        await store.executeSql(
          'INSERT OR REPLACE INTO app_config(key, value) VALUES(?, ?)',
          [DbHelper.RESTORE_FLAG_KEY, '1']);
      } catch (e) {
        try {
          store.rollBack();
        } catch (rb) {
          // 忽略回滚失败
        }
        throw e as Error;
      }
      try {
        store.commit();
      } catch (e) {
        Logger.error(TAG, 'restore commit failed: ' + (e as Error).message);
        throw e as Error;
      }
    } catch (e) {
      // 恢复失败不阻塞初始化：标记未写入则下次启动再试
      Logger.error(TAG, 'restoreRemovedBatch failed: ' + (e as Error).message);
    }
  }

  /** 去重核心（纯操作，调用方保证在事务内）：返回删除的行数 */
  static async dedupeExactDuplicates(store: relationalStore.RdbStore): Promise<number> {
    const groups: DupGroup[] = await DbHelper.findDupGroups(store);
    let removed: number = 0;
    for (const g of groups) {
      const ids: number[] = await DbHelper.findGroupIds(store, g);
      if (ids.length <= 1) {
        continue;
      }
      // 对半去重：并发导入 bug 恰好产生两份（两次导入各一份），
      // 组内按 id 升序（第一次导入在前、第二次在后）保留前半，
      // 与后半成对做状态"或"合并后删除后半——源文件自身的重复行原样保留。
      const keepCount: number = Math.ceil(ids.length / 2);
      const kept: number[] = [];
      const dupIds: number[] = [];
      for (let i: number = 0; i < ids.length; i++) {
        if (i < keepCount) {
          kept.push(ids[i]);
        } else {
          dupIds.push(ids[i]);
        }
      }
      for (let i: number = 0; i < dupIds.length; i++) {
        await DbHelper.mergePairStatus(store, kept[i % kept.length], dupIds[i]);
      }
      // 删除重复行及其状态
      const dupPh: string = dupIds.map((): string => '?').join(',');
      await DbHelper.safeExecuteSql(store,
        'DELETE FROM call_status WHERE row_id IN (' + dupPh + ')', dupIds);
      await DbHelper.safeExecuteSql(store,
        'DELETE FROM call_list WHERE id IN (' + dupPh + ')', dupIds);
      removed += dupIds.length;
    }
    return removed;
  }

  /** 查询完全重复分组（同 row_key + raw_data 且 in_file=1 的多行组） */
  private static async findDupGroups(store: relationalStore.RdbStore): Promise<DupGroup[]> {
    const groups: DupGroup[] = [];
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.querySql(
        'SELECT row_key, raw_data, COUNT(*) AS cnt ' +
        'FROM call_list GROUP BY row_key, raw_data HAVING cnt > 1', []);
      while (rs.goToNextRow()) {
        const g: DupGroup = new DupGroup();
        g.rowKey = rs.getString(rs.getColumnIndex('row_key'));
        g.rawData = rs.getString(rs.getColumnIndex('raw_data'));
        groups.push(g);
      }
      return groups;
    } catch (e) {
      Logger.error(TAG, 'findDupGroups failed: ' + (e as Error).message);
      throw new Error('findDupGroups failed: ' + (e as Error).message);
    } finally {
      if (rs !== undefined) {
        try {
          rs.close();
        } catch (e) {
          // 忽略关闭失败
        }
      }
    }
  }

  /** 查询组内全部行 id */
  private static async findGroupIds(store: relationalStore.RdbStore, g: DupGroup): Promise<number[]> {
    const ids: number[] = [];
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.querySql(
        'SELECT id FROM call_list WHERE row_key = ? AND raw_data = ? ORDER BY id ASC',
        [g.rowKey, g.rawData]);
      while (rs.goToNextRow()) {
        ids.push(rs.getLong(rs.getColumnIndex('id')));
      }
      return ids;
    } catch (e) {
      Logger.error(TAG, 'findGroupIds failed: ' + (e as Error).message);
      throw new Error('findGroupIds failed: ' + (e as Error).message);
    } finally {
      if (rs !== undefined) {
        try {
          rs.close();
        } catch (e) {
          // 忽略关闭失败
        }
      }
    }
  }

  /** 成对状态"或"合并：把 removedId 的状态并入 keptId（called 缓存列 + call_status 三键） */
  private static async mergePairStatus(store: relationalStore.RdbStore,
    keptId: number, removedId: number): Promise<void> {
    // called 缓存列 OR
    let rc: number = 0;
    let rcRs: relationalStore.ResultSet | undefined = undefined;
    try {
      rcRs = await store.querySql('SELECT called FROM call_list WHERE id = ?', [removedId]);
      if (rcRs.goToNextRow()) {
        rc = rcRs.getLong(rcRs.getColumnIndex('called'));
      }
    } catch (e) {
      Logger.error(TAG, 'mergePairStatus read called failed: ' + (e as Error).message);
      throw new Error('mergePairStatus read called failed: ' + (e as Error).message);
    } finally {
      if (rcRs !== undefined) {
        try {
          rcRs.close();
        } catch (e) {
          // 忽略关闭失败
        }
      }
    }
    if (rc === 1) {
      await DbHelper.safeExecuteSql(store,
        'UPDATE call_list SET called = 1, updated_at = ? WHERE id = ?',
        [Date.now(), keptId]);
    }
    // call_status：removed 行值为 1 的状态键并入 kept
    const statusRows: StatusMerge[] = [];
    let stRs: relationalStore.ResultSet | undefined = undefined;
    try {
      stRs = await store.querySql(
        'SELECT status_key, value FROM call_status WHERE row_id = ?', [removedId]);
      while (stRs.goToNextRow()) {
        const m: StatusMerge = new StatusMerge();
        m.key = stRs.getString(stRs.getColumnIndex('status_key'));
        m.v = stRs.getLong(stRs.getColumnIndex('value'));
        statusRows.push(m);
      }
    } catch (e) {
      Logger.error(TAG, 'mergePairStatus read status failed: ' + (e as Error).message);
      throw new Error('mergePairStatus read status failed: ' + (e as Error).message);
    } finally {
      if (stRs !== undefined) {
        try {
          stRs.close();
        } catch (e) {
          // 忽略关闭失败
        }
      }
    }
    for (const m of statusRows) {
      if (m.v === 1) {
        await DbHelper.safeExecuteSql(store,
          'INSERT OR REPLACE INTO call_status(row_id, status_key, value, updated_at) VALUES(?, ?, 1, ?)',
          [keptId, m.key, Date.now()]);
      }
    }
  }

  /** executeSql 包装（W-3 约定：失败抛带上下文 Error） */
  private static async safeExecuteSql(store: relationalStore.RdbStore, sql: string,
    args: relationalStore.ValueType[]): Promise<void> {
    try {
      await store.executeSql(sql, args);
    } catch (e) {
      Logger.error(TAG, 'safeExecuteSql failed: ' + (e as Error).message);
      throw new Error('safeExecuteSql failed: ' + (e as Error).message);
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

/** v0.5.4 重复行分组信息 */
class DupGroup {
  rowKey: string = '';
  rawData: string = '';
}

/** v0.5.4 状态"或"合并条目 */
class StatusMerge {
  key: string = '';
  v: number = 0;
}
