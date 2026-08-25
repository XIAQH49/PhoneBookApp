import { describe, it, expect } from '@ohos/hypium';
import { ImportLogic } from '../../main/ets/service/ImportLogic';
import type { ImportPrepareResult } from '../../main/ets/service/ImportLogic';
import type { ParsedSheet } from '../../main/ets/service/CsvService';
import type { ColumnMapping } from '../../main/ets/model/ColumnMapping';

/**
 * 导入数据准备单测：列识别、行构建、格式探测（与 tools/verify/verify.ts 同源用例）。
 */
export default function importLogicTest() {
  describe('ImportLogicTest', () => {
    it('match_columns_exact_and_contains', 0, () => {
      const headers: string[] = ['责任人', '姓名', '工号', '手机', '是否已打（是/否）', '备注'];
      const m: ColumnMapping = ImportLogic.matchColumns(headers);
      expect(m.assignee).assertEqual('责任人');
      expect(m.name).assertEqual('姓名');
      expect(m.empNo).assertEqual('工号');
      expect(m.phone).assertEqual('手机');
      expect(m.called).assertEqual('是否已打（是/否）');
      expect(m.connected).assertEqual('');
      expect(m.intention).assertEqual('');
    });

    it('prepare_full_row', 0, () => {
      const headers: string[] = ['责任人', '姓名', '工号', '手机', '是否已打（是/否）', '备注'];
      const row1: string[] = ['张三', '张三', '10001', '+86-19999999999（国内）', '是', '重点客户'];
      const rows: string[][] = [row1];
      const sheet: ParsedSheet = { headers: headers, rows: rows };
      const r: ImportPrepareResult = ImportLogic.prepare(sheet);
      expect(r.allColumns.length).assertEqual(6);
      expect(r.rows.length).assertEqual(1);
      expect(r.rows[0].rowKey).assertEqual('E:10001');
      expect(r.rows[0].assignee).assertEqual('张三');
      expect(r.rows[0].phoneNumbers.length).assertEqual(1);
      expect(r.rows[0].phoneNumbers[0]).assertEqual('+8619999999999');
      expect(r.rows[0].calledFromFile).assertTrue();
      expect(r.rows[0].rawData['备注']).assertEqual('重点客户');
      expect(r.calledValueFormat).assertEqual('yes_no');
    });

    it('prepare_uncalled_and_unknown_columns_kept', 0, () => {
      const headers: string[] = ['姓名', '工号', '手机', '是否已打', '未知列X'];
      const row1: string[] = ['李四', '', '13800000000', '', 'hello'];
      const rows: string[][] = [row1];
      const sheet: ParsedSheet = { headers: headers, rows: rows };
      const r: ImportPrepareResult = ImportLogic.prepare(sheet);
      expect(r.rows[0].rowKey.startsWith('H:')).assertTrue();
      expect(r.rows[0].calledFromFile).assertFalse();
      expect(r.rows[0].rawData['未知列X']).assertEqual('hello');
    });
  });
}
