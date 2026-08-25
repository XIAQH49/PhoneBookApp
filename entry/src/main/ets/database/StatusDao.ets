import { relationalStore } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from './DbHelper';
import { CallListDao } from './CallListDao';

/**
 * 状态键值表读写（设计规格 3.2 节双写规则）。
 * upsertCalledPlain 为纯操作（导入合并事务内使用）；
 * setCalled 自带事务（UI 标记/撤销场景单独调用）。
 */
export class StatusDao {
  /** 纯 upsert：无事务，调用方保证在事务内 */
  static async upsertCalledPlain(rowId: number, value: number): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_STATUS);
    pred.equalTo('row_id', rowId).and().equalTo('status_key', Constants.STATUS_KEY_CALLED);
    const rs: relationalStore.ResultSet = await store.query(pred, ['id']);
    const exists: boolean = rs.goToNextRow();
    rs.close();
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
    const rs: relationalStore.ResultSet = await store.query(pred, ['value']);
    let value: number = 0;
    if (rs.goToNextRow()) {
      value = rs.getLong(rs.getColumnIndex('value'));
    }
    rs.close();
    return value === 1;
  }
}
