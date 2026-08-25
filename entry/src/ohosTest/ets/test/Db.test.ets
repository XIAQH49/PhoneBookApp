import { describe, beforeAll, it, expect } from '@ohos/hypium';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { DbHelper } from '../../../main/ets/database/DbHelper';
import { CallListDao } from '../../../main/ets/database/CallListDao';
import { StatusDao } from '../../../main/ets/database/StatusDao';
import { ConfigDao } from '../../../main/ets/database/ConfigDao';
import { CallRecord } from '../../../main/ets/model/CallRecord';

const DOMAIN: number = 0x0001;

function makeRecord(empNo: string): CallRecord {
  const rec: CallRecord = new CallRecord();
  rec.metaId = 0;
  rec.rowNo = 1;
  rec.rowKey = 'TEST:' + empNo;
  rec.assignee = '测试责任人';
  rec.name = '测试' + empNo;
  rec.empNo = empNo;
  rec.phoneRaw = '13800000000';
  rec.phoneNumbers = ['+8613800000000'];
  rec.called = false;
  rec.rawData = {};
  rec.inFile = true;
  return rec;
}

/**
 * 数据库集成测试（ohosTest，真机/模拟器执行）：
 * 覆盖设计规格 3.2 双写一致性、NFR-5 事务回滚。
 * 执行：连接设备后 IDE 右键 ohosTest 运行（模拟器可跑，不依赖电话能力）。
 */
export default function dbTest() {
  describe('DbTest', () => {
    beforeAll(async () => {
      const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
      await DbHelper.init(context);
      hilog.info(DOMAIN, 'DbTest', 'database ready');
    });

    it('dual_write_consistency', 0, async () => {
      const rec: CallRecord = makeRecord('T001');
      const rowId: number = await CallListDao.insertPlain(rec);
      expect(rowId > 0).assertTrue();
      await StatusDao.setCalled(rowId, true);
      const status: boolean = await StatusDao.getCalled(rowId);
      const fetched: CallRecord | undefined = await CallListDao.getById(rowId);
      expect(status).assertTrue();
      expect(fetched !== undefined && fetched.called).assertTrue();
      // 撤销
      await StatusDao.setCalled(rowId, false);
      const status2: boolean = await StatusDao.getCalled(rowId);
      expect(status2).assertFalse();
    });

    it('transaction_rollback_on_failure', 0, async () => {
      const before: number = await CallListDao.countAllActive();
      let thrown: boolean = false;
      try {
        await DbHelper.runInTransaction(async () => {
          await CallListDao.insertPlain(makeRecord('T002'));
          throw new Error('simulated failure');
        });
      } catch (e) {
        thrown = true;
      }
      expect(thrown).assertTrue();
      const after: number = await CallListDao.countAllActive();
      expect(after).assertEqual(before);
    });

    it('config_roundtrip', 0, async () => {
      await ConfigDao.set('db_test_key', 'v1');
      expect(await ConfigDao.get('db_test_key')).assertEqual('v1');
    });
  });
}
