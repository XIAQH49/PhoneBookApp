import { describe, it, expect } from '@ohos/hypium';
import { CsvService } from '../../main/ets/service/CsvService';
import type { ParsedSheet } from '../../main/ets/service/CsvService';

/**
 * CSV 解析/写出单测（编码检测的端侧验证见 T-2 真机 spike；Node 侧已由 tools/verify 覆盖）。
 * 注意：CLI 的 hvigor test 任务不解析 main 目录导入（见 docs/04 第 6 节），本文件在 IDE 中运行。
 */
export default function csvServiceTest() {
  describe('CsvServiceTest', () => {
    it('parse_basic', 0, () => {
      const s: ParsedSheet = CsvService.parseCsv('a,b\n1,2\n3,4');
      expect(s.headers.length).assertEqual(2);
      expect(s.rows.length).assertEqual(2);
      expect(s.rows[1][1]).assertEqual('4');
    });
    it('parse_quoted_comma_and_escaped_quote', 0, () => {
      const s: ParsedSheet = CsvService.parseCsv('姓名,备注\n张三,"包含,逗号"\n李四,"他说""你好"""');
      expect(s.rows[0][1]).assertEqual('包含,逗号');
      expect(s.rows[1][1]).assertEqual('他说"你好"');
    });
    it('parse_bom_crlf_empty_lines', 0, () => {
      const s: ParsedSheet = CsvService.parseCsv('\uFEFFa,b\r\n\r\n1,2\r\n');
      expect(s.headers[0]).assertEqual('a');
      expect(s.rows.length).assertEqual(1);
      expect(s.rows[0][0]).assertEqual('1');
    });
    it('parse_auto_delimiter', 0, () => {
      const s: ParsedSheet = CsvService.parseCsv('a;b\n1;2');
      expect(s.headers[1]).assertEqual('b');
      expect(s.rows[0][1]).assertEqual('2');
    });
    it('parse_short_row_padded', 0, () => {
      const s: ParsedSheet = CsvService.parseCsv('a,b,c\n1');
      expect(s.rows[0][1]).assertEqual('');
      expect(s.rows[0][2]).assertEqual('');
    });
    it('to_csv_bom_and_escaping', 0, () => {
      const out: string = CsvService.toCsv([['a', 'b,1'], ['"q"', 'x']]);
      expect(out.startsWith('\uFEFF')).assertTrue();
      expect(out.indexOf('a,"b,1"') >= 0).assertTrue();
    });
  });
}
