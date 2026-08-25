import { describe, it, expect } from '@ohos/hypium';
import { MergeService, CalledValue } from '../../main/ets/service/MergeService';
import type { MergeRowData, LocalRowSnapshot, MergeUpdate, MergePlan } from '../../main/ets/service/MergeService';

/**
 * FR-2 / R-1 合并算法与已打值映射单测（与 tools/verify/verify.ts 同源用例）。
 */
function makeRow(empNo: string, name: string, phone: string, called: boolean, no: number): MergeRowData {
  const raw: Record<string, string> = {
    '责任人': '张三', '姓名': name, '工号': empNo, '手机': phone
  };
  const nums: string[] = ['+8619999999999'];
  const row: MergeRowData = {
    rowKey: MergeService.buildRowKey(empNo, name, phone),
    rowNo: no,
    assignee: '张三',
    name: name,
    empNo: empNo,
    phoneRaw: phone,
    phoneNumbers: nums,
    rawData: raw,
    calledFromFile: called
  };
  return row;
}

function buildLocalRows(): LocalRowSnapshot[] {
  const l1: LocalRowSnapshot = { id: 1, rowKey: 'E:10001', called: true };
  const l2: LocalRowSnapshot = {
    id: 2, rowKey: MergeService.buildRowKey('', '李四', '13800000000'), called: false
  };
  const l3: LocalRowSnapshot = { id: 3, rowKey: 'E:10003', called: false };
  const list: LocalRowSnapshot[] = [l1, l2, l3];
  return list;
}

export default function mergeServiceTest() {
  describe('MergeServiceTest', () => {
    it('state_takes_or', 0, () => {
      const newRows: MergeRowData[] = [
        makeRow('10001', '张三', '19999999999', false, 1),
        makeRow('', '李四', '13800000000', true, 2)
      ];
      const plan: MergePlan = MergeService.computePlan(newRows, buildLocalRows());
      expect(plan.inserts.length).assertEqual(0);
      expect(plan.updates.length).assertEqual(2);
      const u1: MergeUpdate | undefined =
        plan.updates.find((u: MergeUpdate): boolean => u.localId === 1);
      const u2: MergeUpdate | undefined =
        plan.updates.find((u: MergeUpdate): boolean => u.localId === 2);
      expect(u1 !== undefined && u1.calledMerged === true).assertTrue();
      expect(u2 !== undefined && u2.calledMerged === true).assertTrue();
      expect(plan.removedLocalIds.length).assertEqual(1);
    });

    it('new_row_insert_and_missing_marked_removed', 0, () => {
      const newRows: MergeRowData[] = [makeRow('10009', '王五', '13900000000', false, 9)];
      const plan: MergePlan = MergeService.computePlan(newRows, buildLocalRows());
      expect(plan.inserts.length).assertEqual(1);
      expect(plan.updates.length).assertEqual(0);
      expect(plan.removedLocalIds.length).assertEqual(3);
    });

    it('row_key_prefers_emp_no', 0, () => {
      expect(MergeService.buildRowKey('10001', '张三', '19999999999')).assertEqual('E:10001');
      const keyNoEmp: string = MergeService.buildRowKey('', '张三', '19999999999');
      expect(keyNoEmp.startsWith('H:')).assertTrue();
    });

    it('called_boolean_mapping', 0, () => {
      expect(CalledValue.toBoolean('是')).assertTrue();
      expect(CalledValue.toBoolean('√')).assertTrue();
      expect(CalledValue.toBoolean('1')).assertTrue();
      expect(CalledValue.toBoolean('否')).assertFalse();
      expect(CalledValue.toBoolean('')).assertFalse();
      expect(CalledValue.toBoolean('未知值')).assertFalse();
    });

    it('format_detect_and_export_value', 0, () => {
      const fmt1: string[] = ['是', '否'];
      const fmt2: string[] = ['1', ''];
      const fmt3: string[] = [];
      expect(CalledValue.detectFormat(fmt1)).assertEqual('yes_no');
      expect(CalledValue.detectFormat(fmt2)).assertEqual('one_blank');
      expect(CalledValue.detectFormat(fmt3)).assertEqual('yes_no');
      expect(CalledValue.toExportValue(true, 'yes_no')).assertEqual('是');
      expect(CalledValue.toExportValue(false, 'yes_no')).assertEqual('');
      expect(CalledValue.toExportValue(true, 'one_blank')).assertEqual('1');
    });
  });
}
