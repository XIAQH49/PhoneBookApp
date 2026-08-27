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

    it('v054_dedupe_halves_race_duplicates', 0, async () => {
      // v0.5.4 修复验证（对半去重）：并发导入产生两份时每组保留一半；
      // 源文件自身重复的行（文件内出现两次 × 两次导入 = 4 份）保留 2 份；
      // 状态与后半成对取"或"；同键但 raw_data 不同的行必须保留（v0.5.3 语义）。
      const store = DbHelper.getStore();
      // A 组：文件内 1 次 × 导入 2 次 = 2 份 → 保留 1
      const recA1: CallRecord = makeRecord('DUP001');
      recA1.rawData = { '姓名': '测试A', '备注': 'x' };
      const recA2: CallRecord = makeRecord('DUP001');
      recA2.rawData = { '姓名': '测试A', '备注': 'x' };
      const idA1: number = await CallListDao.insertPlain(recA1);
      const idA2: number = await CallListDao.insertPlain(recA2);
      await StatusDao.setCalled(idA1, true);
      await StatusDao.setCalled(idA2, false);
      await StatusDao.setValue(idA2, 'connected', true);
      // B 组：文件内 2 次 × 导入 2 次 = 4 份 → 保留 2，成对取"或"
      const idsB: number[] = [];
      for (let i = 0; i < 4; i++) {
        const r: CallRecord = makeRecord('DUP002');
        r.rawData = { '姓名': '测试B', '备注': 'y' };
        idsB.push(await CallListDao.insertPlain(r));
      }
      // 第一次导入的两份（idsB[0], idsB[1]）：一份已打；第二次导入的两份未打
      await StatusDao.setCalled(idsB[0], true);
      // 同键但内容不同：必须保留
      const recC1: CallRecord = makeRecord('DUP001');
      recC1.rawData = { '姓名': '测试C', '备注': 'z' };
      const idC1: number = await CallListDao.insertPlain(recC1);
      const before: number = await CallListDao.countAllActive();
      expect(before).assertEqual(7);
      await DbHelper.runInTransaction(async () => {
        await DbHelper.dedupeExactDuplicates(store);
      });
      const after: number = await CallListDao.countAllActive();
      expect(after).assertEqual(4);
      // A 组保留 1（idA1）：called 取"或"=true，connected 合并=true
      const keptA: CallRecord | undefined = await CallListDao.getById(idA1);
      expect(keptA !== undefined && keptA.called).assertTrue();
      expect(await StatusDao.getValue(idA1, 'connected')).assertTrue();
      // B 组保留 2（idsB[0], idsB[1]）：成对 OR——idsB[0] 与 idsB[2] 配对 → called=true
      expect((await CallListDao.getById(idsB[0])) !== undefined).assertTrue();
      expect((await CallListDao.getById(idsB[1])) !== undefined).assertTrue();
      const keptB0: CallRecord | undefined = await CallListDao.getById(idsB[0]);
      expect(keptB0 !== undefined && keptB0.called).assertTrue();
      const keptB1: CallRecord | undefined = await CallListDao.getById(idsB[1]);
      expect(keptB1 !== undefined && !keptB1.called).assertTrue();
      // C 行未被误删
      expect((await CallListDao.getById(idC1)) !== undefined).assertTrue();
    });
  });
}
