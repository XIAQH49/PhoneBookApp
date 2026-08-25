import { describe, it, expect } from '@ohos/hypium';
import { NumberParseService } from '../../main/ets/service/NumberParseService';

/**
 * FR-9 号码解析单测（与 tools/verify/verify.ts 同源用例）。
 */
export default function numberParseTest() {
  describe('NumberParseTest', () => {
    it('single_with_comment', 0, () => {
      const r: string[] = NumberParseService.parse('+86-19999999999（国内）');
      expect(r.length).assertEqual(1);
      expect(r[0]).assertEqual('+8619999999999');
    });
    it('two_numbers_slash', 0, () => {
      const r: string[] = NumberParseService.parse('+86-19999999999/+86-13800000000');
      expect(r.length).assertEqual(2);
      expect(r[0]).assertEqual('+8619999999999');
      expect(r[1]).assertEqual('+8613800000000');
    });
    it('number_to_string_recovery', 0, () => {
      expect(NumberParseService.numberToString(13800000000)).assertEqual('13800000000');
      const r: string[] = NumberParseService.parse(NumberParseService.numberToString(13800000000));
      expect(r[0]).assertEqual('+8613800000000');
    });
    it('spaces_and_comment', 0, () => {
      const r: string[] = NumberParseService.parse('138 8888 8888（转123）');
      expect(r[0]).assertEqual('+8613888888888');
    });
    it('landline', 0, () => {
      const r: string[] = NumberParseService.parse('0755-88888888');
      expect(r[0]).assertEqual('075588888888');
    });
    it('plain_mobile_11', 0, () => {
      const r: string[] = NumberParseService.parse('19999999999');
      expect(r[0]).assertEqual('+8619999999999');
    });
    it('invalid_returns_empty', 0, () => {
      expect(NumberParseService.parse('abc').length).assertEqual(0);
      expect(NumberParseService.parse('').length).assertEqual(0);
    });
    it('dedupe_keeps_first', 0, () => {
      const r: string[] = NumberParseService.parse('19999999999/+8619999999999');
      expect(r.length).assertEqual(1);
    });
    it('unclosed_bracket_treated_as_comment', 0, () => {
      const r: string[] = NumberParseService.parse('+86-19999999999（国内');
      expect(r.length).assertEqual(1);
      expect(r[0]).assertEqual('+8619999999999');
    });
  });
}
