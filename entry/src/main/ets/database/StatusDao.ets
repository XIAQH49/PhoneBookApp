import { relationalStore } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from './DbHelper';
import { CallListDao } from './CallListDao';
import { Logger } from '../common/Logger';

const TAG: string = 'StatusDao';

/** 状态条目（批量读取用） */
export interface StatusEntry {
  rowId: number;
  key: string;
  value: boolean;
}

/**
 * 状态键值表读写（设计规格 3.2 节）。
 * called：双写 call_status + call_list.called 缓存列（列表查询/筛选免联表）；
 * connected / intention（M3）：仅写 call_status（列表不展示不筛选，详情页/导出按行读取）。
 * 纯操作不带事务；setCalled/setValue 自带事务（UI 场景）；导入合并事务内用 Plain 方法。
 */
export class StatusDao {
  /** 通用纯 upsert：无事务，调用方保证在事务内 */
  static async upsertStatusPlain(rowId: number, key: string, value: number): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_STATUS);
    pred.equalTo('row_id', rowId).and().equalTo('status_key', key);
    // 保持原语义：先关闭结果集再进行写入（查询/写入分离，避免同一连接游标挂起）
    let exists: boolean = false;
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.query(pred, ['id']);
      exists = rs.goToNextRow();
    } catch (e) {
      Logger.error(TAG, 'upsertStatusPlain query failed: ' + (e as Error).message);
      throw new Error('upsertStatusPlain query failed: ' + (e as Error).message);
    } finally {
      if (rs !== undefined) {
        try {
          rs.close();
        } catch (e) {
          // 关闭失败忽略：不影响写入结果
        }
      }
    }
    try {
      if (exists) {
        const vb: relationalStore.ValuesBucket = { 'value': value, 'updated_at': Date.now() };
        await store.update(vb, pred);
      } else {
        const vb: relationalStore.ValuesBucket = {
          'row_id': rowId,
          'status_key': key,
          'value': value,
          'updated_at': Date.now()
        };
        await store.insert(Constants.TABLE_CALL_STATUS, vb);
      }
    } catch (e) {
      Logger.error(TAG, 'upsertStatusPlain write failed: ' + (e as Error).message);
      throw new Error('upsertStatusPlain write failed: ' + (e as Error).message);
    }
  }

  /** 已打纯 upsert（导入合并事务内使用，保持既有语义） */
  static async upsertCalledPlain(rowId: number, value: number): Promise<void> {
    await StatusDao.upsertStatusPlain(rowId, Constants.STATUS_KEY_CALLED, value);
  }

  /** 标记/撤销已打（FR-6）：单事务双写 call_status + call_list.called */
  static async setCalled(rowId: number, value: boolean): Promise<void> {
    const v: number = value ? 1 : 0;
    await DbHelper.runInTransaction(async () => {
      await StatusDao.upsertStatusPlain(rowId, Constants.STATUS_KEY_CALLED, v);
      await CallListDao.setCalledCache(rowId, v);
    });
  }

  /**
   * 标记/撤销打通/意向（M3，FR-10/FR-11）：仅写 call_status（无缓存列），自带事务。
   * 勿在外部事务内调用（与 runInTransaction 互斥）。
   */
  static async setValue(rowId: number, key: string, value: boolean): Promise<void> {
    const v: number = value ? 1 : 0;
    await DbHelper.runInTransaction(async () => {
      await StatusDao.upsertStatusPlain(rowId, key, v);
    });
  }

  /** 读取单个状态值（缺省为 false） */
  static async getValue(rowId: number, key: string): Promise<boolean> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_STATUS);
    pred.equalTo('row_id', rowId).and().equalTo('status_key', key);
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.query(pred, ['value']);
      let value: number = 0;
      if (rs.goToNextRow()) {
        value = rs.getLong(rs.getColumnIndex('value'));
      }
      return value === 1;
    } catch (e) {
      Logger.error(TAG, 'getValue failed: ' + (e as Error).message);
      throw new Error('getValue failed: ' + (e as Error).message);
    } finally {
      if (rs !== undefined) {
        try {
          rs.close();
        } catch (e) {
          // 关闭失败忽略：不影响查询结果
        }
      }
    }
  }

  /** 读取已打状态（测试与详情校验用，保持既有方法） */
  static async getCalled(rowId: number): Promise<boolean> {
    return await StatusDao.getValue(rowId, Constants.STATUS_KEY_CALLED);
  }

  /** 批量读取状态（导出组装用）：返回 rowId+key+value 三元组列表 */
  static async getStatuses(rowIds: number[], keys: string[]): Promise<StatusEntry[]> {
    if (rowIds.length === 0 || keys.length === 0) {
      return [];
    }
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_STATUS);
    pred.in('row_id', rowIds).and().in('status_key', keys);
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.query(pred, ['row_id', 'status_key', 'value']);
      const list: StatusEntry[] = [];
      while (rs.goToNextRow()) {
        const entry: StatusEntry = {
          rowId: rs.getLong(rs.getColumnIndex('row_id')),
          key: rs.getString(rs.getColumnIndex('status_key')),
          value: rs.getLong(rs.getColumnIndex('value')) === 1
        };
        list.push(entry);
      }
      return list;
    } catch (e) {
      Logger.error(TAG, 'getStatuses failed: ' + (e as Error).message);
      throw new Error('getStatuses failed: ' + (e as Error).message);
    } finally {
      if (rs !== undefined) {
        try {
          rs.close();
        } catch (e) {
          // 关闭失败忽略：不影响查询结果
        }
      }
    }
  }
}
