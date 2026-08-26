import { relationalStore } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from './DbHelper';
import { CallListDao } from './CallListDao';
import { Logger } from '../common/Logger';

const TAG: string = 'StatusDao';

/**
 * 状态键值表读写（设计规格 3.2 节双写规则）。
 * upsertCalledPlain 为纯操作（导入合并事务内使用）；
 * setCalled 自带事务（UI 标记/撤销场景单独调用）。
 *
 * M2-1：SDK 调用点统一 try/catch 包装（W-3 警告清零）；失败向上抛出带上下文的
 * Error，由服务边界统一捕获，运行期语义不变。
 */
export class StatusDao {
  /** 纯 upsert：无事务，调用方保证在事务内 */
  static async upsertCalledPlain(rowId: number, value: number): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_STATUS);
    pred.equalTo('row_id', rowId).and().equalTo('status_key', Constants.STATUS_KEY_CALLED);
    // 保持原语义：先关闭结果集再进行写入（查询/写入分离，避免同一连接游标挂起）
    let exists: boolean = false;
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.query(pred, ['id']);
      exists = rs.goToNextRow();
    } catch (e) {
      Logger.error(TAG, 'upsertCalledPlain query failed: ' + (e as Error).message);
      throw new Error('upsertCalledPlain query failed: ' + (e as Error).message);
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
          'status_key': Constants.STATUS_KEY_CALLED,
          'value': value,
          'updated_at': Date.now()
        };
        await store.insert(Constants.TABLE_CALL_STATUS, vb);
      }
    } catch (e) {
      Logger.error(TAG, 'upsertCalledPlain write failed: ' + (e as Error).message);
      throw new Error('upsertCalledPlain write failed: ' + (e as Error).message);
    }
  }

  /** 标记/撤销已打（FR-6）：单事务双写 call_status + call_list.called */
  static async setCalled(rowId: number, value: boolean): Promise<void> {
    const v: number = value ? 1 : 0;
    await DbHelper.runInTransaction(async () => {
      await StatusDao.upsertCalledPlain(rowId, v);
      await CallListDao.setCalledCache(rowId, v);
    });
  }

  /** 读取已打状态（测试与详情校验用） */
  static async getCalled(rowId: number): Promise<boolean> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_STATUS);
    pred.equalTo('row_id', rowId).and().equalTo('status_key', Constants.STATUS_KEY_CALLED);
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.query(pred, ['value']);
      let value: number = 0;
      if (rs.goToNextRow()) {
        value = rs.getLong(rs.getColumnIndex('value'));
      }
      return value === 1;
    } catch (e) {
      Logger.error(TAG, 'getCalled failed: ' + (e as Error).message);
      throw new Error('getCalled failed: ' + (e as Error).message);
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
