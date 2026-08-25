/**
 * Node 直接运行的纯逻辑验证脚本（Node >= 23.6 原生支持 TS 类型剥离）。
 * 与被测源文件使用同一份代码，避免逻辑漂移。
 * 运行方式：node tools/verify/verify.ts
 * 说明：被测文件必须为纯 TS（无 ArkTS 专属语法、无 Kit 依赖）。
 */
import assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { NumberParseService } from '../../entry/src/main/ets/service/NumberParseService.ts';
import { MergeService, CalledValue } from '../../entry/src/main/ets/service/MergeService.ts';
import type { MergeRowData, LocalRowSnapshot } from '../../entry/src/main/ets/service/MergeService.ts';
import { CsvService } from '../../entry/src/main/ets/service/CsvService.ts';
import type { Decoder, DecoderFactory, ParsedSheet } from '../../entry/src/main/ets/service/CsvService.ts';
import { ImportLogic } from '../../entry/src/main/ets/service/ImportLogic.ts';
import { ExportLogic } from '../../entry/src/main/ets/service/ExportLogic.ts';
import type { ExportRow } from '../../entry/src/main/ets/service/ExportLogic.ts';
import { XlsxService } from '../../entry/src/main/ets/service/XlsxService.ts';
// 与被测服务同一份库文件：功能面 node 往返验证（真机加载/性能见 T-1 spike）
import XLSX from '../../entry/src/main/ets/libs/xlsx.full.min.js';

let passed: number = 0;
function check(name: string, fn: () => void): void {
  fn();
  passed++;
  console.log(`  ✓ ${name}`);
}

const nodeFactory: DecoderFactory = {
  create(encoding: string, fatal: boolean): Decoder {
    return {
      decode(data: Uint8Array): string {
        return new TextDecoder(encoding, { fatal: fatal }).decode(data);
      }
    };
  }
};

console.log('[verify] NumberParseService (FR-9)');
check('single_with_comment', () => {
  assert.deepStrictEqual(NumberParseService.parse('+86-19999999999（国内）'), ['+8619999999999']);
});
check('two_numbers_slash', () => {
  assert.deepStrictEqual(NumberParseService.parse('+86-19999999999/+86-13800000000'),
    ['+8619999999999', '+8613800000000']);
});
check('number_to_string_recovery', () => {
  assert.strictEqual(NumberParseService.numberToString(13800000000), '13800000000');
  assert.deepStrictEqual(NumberParseService.parse(NumberParseService.numberToString(13800000000)),
    ['+8613800000000']);
});
check('spaces_and_comment', () => {
  assert.deepStrictEqual(NumberParseService.parse('138 8888 8888（转123）'), ['+8613888888888']);
});
check('landline', () => {
  assert.deepStrictEqual(NumberParseService.parse('0755-88888888'), ['075588888888']);
});
check('plain_mobile_11', () => {
  assert.deepStrictEqual(NumberParseService.parse('19999999999'), ['+8619999999999']);
});
check('country_code_preserved', () => {
  assert.deepStrictEqual(NumberParseService.parse('+44 1234 56789'), ['+44123456789']);
});
check('invalid_returns_empty', () => {
  assert.deepStrictEqual(NumberParseService.parse('abc'), []);
  assert.deepStrictEqual(NumberParseService.parse(''), []);
});
check('dedupe', () => {
  assert.deepStrictEqual(NumberParseService.parse('19999999999/+8619999999999'),
    ['+8619999999999']);
});
check('unclosed_bracket_keeps_rest', () => {
  const r = NumberParseService.parse('+86-19999999999（国内');
  assert.ok(r.length === 1 && r[0] === '+8619999999999');
});

console.log('[verify] MergeService (FR-2 / R-1)');
function row(empNo: string, name: string, phone: string, called: boolean, no: number): MergeRowData {
  return {
    rowKey: MergeService.buildRowKey(empNo, name, phone),
    name: name, empNo: empNo, assignee: '张三', phoneRaw: phone,
    phoneNumbers: ['+8619999999999'],
    rawData: { '责任人': '张三', '姓名': name, '工号': empNo, '手机': phone },
    calledFromFile: called, rowNo: no
  };
}
const localRows: LocalRowSnapshot[] = [
  { id: 1, rowKey: 'E:10001', called: true },
  { id: 2, rowKey: MergeService.buildRowKey('', '李四', '13800000000'), called: false },
  { id: 3, rowKey: 'E:10003', called: false }
];

check('state_takes_or_local_wins', () => {
  const plan = MergeService.computePlan(
    [row('10001', '张三', '19999999999', false, 1), row('', '李四', '13800000000', true, 2)],
    localRows);
  assert.strictEqual(plan.inserts.length, 0);
  assert.strictEqual(plan.updates.length, 2);
  const u1 = plan.updates.find(u => u.localId === 1);
  const u2 = plan.updates.find(u => u.localId === 2);
  assert.ok(u1 !== undefined && u1.calledMerged === true, 'local called kept (OR)');
  assert.ok(u2 !== undefined && u2.calledMerged === true, 'file called kept (OR)');
  assert.deepStrictEqual(plan.removedLocalIds, [3]);
});
check('new_row_insert_and_missing_marked_removed', () => {
  const plan = MergeService.computePlan([row('10009', '王五', '13900000000', false, 9)], localRows);
  assert.strictEqual(plan.inserts.length, 1);
  assert.strictEqual(plan.updates.length, 0);
  assert.deepStrictEqual(plan.removedLocalIds, [1, 2, 3]);
});
check('row_key_prefers_emp_no', () => {
  assert.strictEqual(MergeService.buildRowKey('10001', '张三', '19999999999'), 'E:10001');
  assert.notStrictEqual(MergeService.buildRowKey('', '张三', '19999999999'), 'E:');
});

console.log('[verify] CalledValue (FR-2 判定表 / R-5)');
check('boolean_mapping_table', () => {
  for (const v of ['是', '已打', '已拨打', '√', '✓', '1', 'true', 'TRUE', 'Y', 'YES', '完成']) {
    assert.strictEqual(CalledValue.toBoolean(v), true, `should be true: ${v}`);
  }
  for (const v of ['否', '未打', '0', 'false', 'N', 'NO', '', '   ']) {
    assert.strictEqual(CalledValue.toBoolean(v), false, `should be false: ${v}`);
  }
  assert.strictEqual(CalledValue.toBoolean('未知值'), false);
});
check('format_detect_and_export_value', () => {
  assert.strictEqual(CalledValue.detectFormat(['是', '否', '']), 'yes_no');
  assert.strictEqual(CalledValue.detectFormat(['1', '']), 'one_blank');
  assert.strictEqual(CalledValue.detectFormat(['√']), 'one_blank');
  assert.strictEqual(CalledValue.detectFormat([]), 'yes_no');
  assert.strictEqual(CalledValue.toExportValue(true, 'yes_no'), '是');
  assert.strictEqual(CalledValue.toExportValue(false, 'yes_no'), '');
  assert.strictEqual(CalledValue.toExportValue(true, 'one_blank'), '1');
  assert.strictEqual(CalledValue.toExportValue(false, 'one_blank'), '');
});

console.log('[verify] CsvService (FR-1 编码检测/解析/写出)');
check('detect_utf8_bom', () => {
  const enc = new TextEncoder();
  const body = enc.encode('姓名,手机\n张三,13800000000');
  const bytes = new Uint8Array(body.length + 3);
  bytes.set([0xEF, 0xBB, 0xBF], 0);
  bytes.set(body, 3);
  const r = CsvService.detectAndDecode(bytes, nodeFactory);
  assert.strictEqual(r.encoding, 'utf-8');
  assert.ok(r.text.startsWith('姓名'));
});
check('detect_utf8_no_bom', () => {
  const enc = new TextEncoder();
  const r = CsvService.detectAndDecode(enc.encode('a,b\n1,2'), nodeFactory);
  assert.strictEqual(r.encoding, 'utf-8');
});
check('detect_gbk_fallback', () => {
  // '中文' 的 GBK 编码：中=0xD6D0 文=0xCEC4；这些字节在严格 UTF-8 下非法
  const bytes = new Uint8Array([0xD6, 0xD0, 0xCE, 0xC4]);
  const r = CsvService.detectAndDecode(bytes, nodeFactory);
  assert.strictEqual(r.encoding, 'gbk');
  assert.strictEqual(r.text, '中文');
});
check('parse_basic', () => {
  const s: ParsedSheet = CsvService.parseCsv('a,b\n1,2\n3,4');
  assert.deepStrictEqual(s.headers, ['a', 'b']);
  assert.deepStrictEqual(s.rows, [['1', '2'], ['3', '4']]);
});
check('parse_quoted_comma_and_escaped_quote', () => {
  const s: ParsedSheet = CsvService.parseCsv('姓名,备注\n张三,"包含,逗号"\n李四,"他说""你好"""');
  assert.strictEqual(s.rows[0][1], '包含,逗号');
  assert.strictEqual(s.rows[1][1], '他说"你好"');
});
check('parse_crlf_bom_and_empty_lines', () => {
  const s: ParsedSheet = CsvService.parseCsv('\uFEFFa,b\r\n\r\n1,2\r\n');
  assert.deepStrictEqual(s.headers, ['a', 'b']);
  assert.deepStrictEqual(s.rows, [['1', '2']]);
});
check('parse_auto_delimiter_semicolon', () => {
  const s: ParsedSheet = CsvService.parseCsv('a;b\n1;2');
  assert.deepStrictEqual(s.headers, ['a', 'b']);
  assert.deepStrictEqual(s.rows, [['1', '2']]);
});
check('parse_short_row_padded', () => {
  const s: ParsedSheet = CsvService.parseCsv('a,b,c\n1');
  assert.deepStrictEqual(s.rows, [['1', '', '']]);
});
check('to_csv_bom_and_escaping', () => {
  const out: string = CsvService.toCsv([['a', 'b,1'], ['"q"', 'x']]);
  assert.ok(out.startsWith('\uFEFF'));
  assert.ok(out.indexOf('a,"b,1"') >= 0);
  assert.ok(out.indexOf('"""q"""') >= 0);
});

console.log('[verify] ImportLogic (列识别 / 行构建 / 格式探测)');
check('match_columns_exact_and_contains', () => {
  const m = ImportLogic.matchColumns(['责任人', '姓名', '工号', '手机', '是否已打（是/否）', '备注']);
  assert.strictEqual(m.assignee, '责任人');
  assert.strictEqual(m.name, '姓名');
  assert.strictEqual(m.empNo, '工号');
  assert.strictEqual(m.phone, '手机');
  assert.strictEqual(m.called, '是否已打（是/否）');
  assert.strictEqual(m.connected, '');
  assert.strictEqual(m.intention, '');
});
check('prepare_full_row', () => {
  const sheet: ParsedSheet = {
    headers: ['责任人', '姓名', '工号', '手机', '是否已打（是/否）', '备注'],
    rows: [['张三', '张三', '10001', '+86-19999999999（国内）', '是', '重点客户']]
  };
  const r = ImportLogic.prepare(sheet);
  assert.strictEqual(r.allColumns.length, 6);
  assert.strictEqual(r.rows.length, 1);
  assert.strictEqual(r.rows[0].rowKey, 'E:10001');
  assert.strictEqual(r.rows[0].assignee, '张三');
  assert.deepStrictEqual(r.rows[0].phoneNumbers, ['+8619999999999']);
  assert.strictEqual(r.rows[0].calledFromFile, true);
  assert.strictEqual(r.rows[0].rawData['备注'], '重点客户');
  assert.strictEqual(r.calledValueFormat, 'yes_no');
});
check('prepare_uncalled_and_unknown_columns_kept', () => {
  const sheet: ParsedSheet = {
    headers: ['姓名', '工号', '手机', '是否已打', '未知列X'],
    rows: [['李四', '', '13800000000', '', 'hello']]
  };
  const r = ImportLogic.prepare(sheet);
  assert.ok(r.rows[0].rowKey.startsWith('H:'));
  assert.strictEqual(r.rows[0].calledFromFile, false);
  assert.strictEqual(r.rows[0].rawData['未知列X'], 'hello');
  assert.strictEqual(r.calledValueFormat, 'yes_no');
});

console.log('[verify] ExportLogic (FR-7 组装与命名)');
check('assemble_overrides_called_and_keeps_unknown', () => {
  const rows: ExportRow[] = [
    { called: true, rawData: { '姓名': '张三', '是否已打': '否', '备注': 'x' } },
    { called: false, rawData: { '姓名': '李四', '是否已打': '', '备注': 'y' } }
  ];
  const table: string[][] = ExportLogic.assemble(
    ['姓名', '是否已打', '备注'], '是否已打', 'yes_no', rows);
  assert.deepStrictEqual(table[0], ['姓名', '是否已打', '备注']);
  assert.deepStrictEqual(table[1], ['张三', '是', 'x']);
  assert.deepStrictEqual(table[2], ['李四', '', 'y']);
});
check('assemble_one_blank_format', () => {
  const rows: ExportRow[] = [
    { called: true, rawData: { '是否已打': '0' } }
  ];
  const table: string[][] = ExportLogic.assemble(['是否已打'], '是否已打', 'one_blank', rows);
  assert.deepStrictEqual(table[1], ['1']);
});
check('assemble_without_called_column', () => {
  const rows: ExportRow[] = [
    { called: true, rawData: { '备注': 'z' } }
  ];
  const table: string[][] = ExportLogic.assemble(['备注'], '', 'yes_no', rows);
  assert.deepStrictEqual(table[1], ['z']);
});
check('file_name_timestamp', () => {
  const name: string = ExportLogic.buildFileName('外呼名单.csv', new Date(2025, 0, 15, 15, 30), '.csv');
  assert.strictEqual(name, '外呼名单_20250115_1530.csv');
  const noExt: string = ExportLogic.buildFileName('名单', new Date(2025, 11, 1, 9, 5), '.csv');
  assert.strictEqual(noExt, '名单_20251201_0905.csv');
});

console.log('[verify] XlsxService (T-8 功能面：同一库文件的 node 往返)');
check('xlsx_roundtrip_chinese_and_special_chars', () => {
  const src: ParsedSheet = {
    headers: ['责任人', '姓名', '工号', '手机', '是否已打', '备注'],
    rows: [['张三', '张三', '10001', '+86-19999999999（国内）', '是', '重点,客户']]
  };
  const table: string[][] = [src.headers, src.rows[0]];
  const bytes: Uint8Array = XlsxService.write(table);
  assert.ok(bytes.length > 1000, 'xlsx bytes should be non-trivial');
  const parsed: ParsedSheet = XlsxService.parse(bytes);
  assert.deepStrictEqual(parsed.headers, src.headers);
  assert.deepStrictEqual(parsed.rows, src.rows);
});
check('xlsx_number_cell_recovery', () => {
  // 模拟内网导出为数字型的手机列（Excel 中显示 1.38E+10 的根因场景）
  const ws = XLSX.utils.aoa_to_sheet([['手机'], [13800000000]]);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'S');
  const buf: ArrayBuffer = XLSX.write(wb, { type: 'array', bookType: 'xlsx' });
  const parsed: ParsedSheet = XlsxService.parse(new Uint8Array(buf));
  assert.strictEqual(parsed.rows[0][0], '13800000000');
});
check('xlsx_multi_rows_and_empty_pad', () => {
  const table: string[][] = [['a', 'b', 'c'], ['1', '2', '3'], ['x']];
  const parsed: ParsedSheet = XlsxService.parse(XlsxService.write(table));
  assert.strictEqual(parsed.rows.length, 2);
  assert.deepStrictEqual(parsed.rows[1], ['x', '', '']);
});

console.log('[verify] MergeService.hashBytes (v0.5 内置文件变更检测)');
check('hash_bytes_stable_and_sensitive', () => {
  const a: Uint8Array = new Uint8Array([1, 2, 3, 4]);
  const b: Uint8Array = new Uint8Array([1, 2, 3, 4]);
  const c: Uint8Array = new Uint8Array([1, 2, 3, 5]);
  const empty: Uint8Array = new Uint8Array([]);
  assert.strictEqual(MergeService.hashBytes(a), MergeService.hashBytes(b));
  assert.notStrictEqual(MergeService.hashBytes(a), MergeService.hashBytes(c));
  assert.strictEqual(MergeService.hashBytes(empty), '811c9dc5');
});

console.log('[verify] v0.5 内置名单链路（哈希检测 → 解析 → 合并保留已打）');
check('builtin_flow_preserves_called_state', () => {
  // 与真机 rawfile 同一解析链路：读取 xlsx 字节 → 哈希 → XlsxService → ImportLogic → MergeService
  const bytes: Uint8Array = new Uint8Array(
    fs.readFileSync(path.resolve('samples/名单样例_2000行.xlsx')));
  const hash1: string = MergeService.hashBytes(bytes);
  assert.strictEqual(hash1, MergeService.hashBytes(bytes), '同内容哈希稳定');
  const sheet: ParsedSheet = XlsxService.parse(bytes);
  const prepared = ImportLogic.prepare(sheet);
  assert.strictEqual(prepared.rows.length, 2000);
  // 模拟"本地已打 + 内置文件未打"：合并结果必须保持已打（状态取"或"，R-1）
  const forcedLocal: LocalRowSnapshot[] = [
    { id: 1, rowKey: prepared.rows[0].rowKey, called: true }
  ];
  const plan = MergeService.computePlan([prepared.rows[0]], forcedLocal);
  assert.strictEqual(plan.updates.length, 1);
  assert.strictEqual(plan.updates[0].calledMerged, true, '内置更新不丢已打状态');
  // 未变化文件：哈希一致（服务层据此跳过导入）
  assert.strictEqual(hash1, MergeService.hashBytes(bytes));
});

console.log(`[verify] ALL ${passed} CHECKS PASSED`);
