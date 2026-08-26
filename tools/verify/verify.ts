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
import { MergeService, CalledValue, StatusValue } from '../../entry/src/main/ets/service/MergeService.ts';
import type { MergeRowData, LocalRowSnapshot } from '../../entry/src/main/ets/service/MergeService.ts';
import { CsvService } from '../../entry/src/main/ets/service/CsvService.ts';
import type { Decoder, DecoderFactory, ParsedSheet } from '../../entry/src/main/ets/service/CsvService.ts';
import { ImportLogic } from '../../entry/src/main/ets/service/ImportLogic.ts';
import { ExportLogic } from '../../entry/src/main/ets/service/ExportLogic.ts';
import type { ExportRow, ExportColumns } from '../../entry/src/main/ets/service/ExportLogic.ts';
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
    calledFromFile: called,
    connectedFromFile: false,
    intentionFromFile: false,
    rowNo: no
  };
}
const localRows: LocalRowSnapshot[] = [
  { id: 1, rowKey: 'E:10001', called: true, connected: false, intention: false },
  { id: 2, rowKey: MergeService.buildRowKey('', '李四', '13800000000'), called: false, connected: true, intention: true },
  { id: 3, rowKey: 'E:10003', called: false, connected: false, intention: false }
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
check('duplicate_keys_preserved_in_file', () => {
  const dupA: MergeRowData = row('10001', '张三', '19999999999', false, 1);
  const dupB: MergeRowData = row('10001', '张三', '19999999999', false, 2);
  // 无本地行：文件内同键两条都插入（v0.5.3 修复：不再去重丢弃）
  const p1 = MergeService.computePlan([dupA, dupB], []);
  assert.strictEqual(p1.inserts.length, 2);
  assert.strictEqual(p1.updates.length, 0);
  // 一条本地行：一条更新 + 一条插入，状态取"或"保留
  const localOne: LocalRowSnapshot[] = [{ id: 1, rowKey: 'E:10001', called: true, connected: false, intention: false }];
  const p2 = MergeService.computePlan([dupA, dupB], localOne);
  assert.strictEqual(p2.updates.length, 1);
  assert.strictEqual(p2.inserts.length, 1);
  assert.strictEqual(p2.updates[0].calledMerged, true);
  // 两条本地行：两条更新，无移除
  const localTwo: LocalRowSnapshot[] = [
    { id: 1, rowKey: 'E:10001', called: false, connected: false, intention: false },
    { id: 2, rowKey: 'E:10001', called: true, connected: false, intention: false }
  ];
  const p3 = MergeService.computePlan([dupA, dupB], localTwo);
  assert.strictEqual(p3.updates.length, 2);
  assert.strictEqual(p3.inserts.length, 0);
  assert.strictEqual(p3.removedLocalIds.length, 0);
  // 一条新行 vs 两条本地行：一条更新 + 一条移除
  const p4 = MergeService.computePlan([dupA], localTwo);
  assert.strictEqual(p4.updates.length, 1);
  assert.strictEqual(p4.removedLocalIds.length, 1);
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
check('prepare_skips_fully_empty_rows', () => {
  const sheet: ParsedSheet = {
    headers: ['姓名', '工号', '手机'],
    rows: [['', '', ''], ['张三', 'E1', '13800000000'], ['', '', '']]
  };
  const r = ImportLogic.prepare(sheet);
  assert.strictEqual(r.rows.length, 1);
  assert.strictEqual(r.skippedEmpty, 2);
});

console.log('[verify] ExportLogic (FR-7 组装与命名)');
check('assemble_overrides_called_and_keeps_unknown', () => {
  const rows: ExportRow[] = [
    { called: true, connected: false, intention: false, rawData: { '姓名': '张三', '是否已打': '否', '备注': 'x' } },
    { called: false, connected: false, intention: false, rawData: { '姓名': '李四', '是否已打': '', '备注': 'y' } }
  ];
  const cols: ExportColumns = {
    called: '是否已打', calledFormat: 'yes_no',
    connected: '', connectedFormat: 'yes_no',
    intention: '', intentionFormat: 'yes_no'
  };
  const table: string[][] = ExportLogic.assemble(['姓名', '是否已打', '备注'], cols, rows);
  assert.deepStrictEqual(table[0], ['姓名', '是否已打', '备注']);
  assert.deepStrictEqual(table[1], ['张三', '是', 'x']);
  assert.deepStrictEqual(table[2], ['李四', '', 'y']);
});
check('assemble_one_blank_format', () => {
  const rows: ExportRow[] = [
    { called: true, connected: false, intention: false, rawData: { '是否已打': '0' } }
  ];
  const cols: ExportColumns = {
    called: '是否已打', calledFormat: 'one_blank',
    connected: '', connectedFormat: 'yes_no',
    intention: '', intentionFormat: 'yes_no'
  };
  const table: string[][] = ExportLogic.assemble(['是否已打'], cols, rows);
  assert.deepStrictEqual(table[1], ['1']);
});
check('assemble_without_called_column', () => {
  const rows: ExportRow[] = [
    { called: true, connected: false, intention: false, rawData: { '备注': 'z' } }
  ];
  const cols: ExportColumns = {
    called: '', calledFormat: 'yes_no',
    connected: '', connectedFormat: 'yes_no',
    intention: '', intentionFormat: 'yes_no'
  };
  const table: string[][] = ExportLogic.assemble(['备注'], cols, rows);
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
    { id: 1, rowKey: prepared.rows[0].rowKey, called: true, connected: false, intention: false }
  ];
  const plan = MergeService.computePlan([prepared.rows[0]], forcedLocal);
  assert.strictEqual(plan.updates.length, 1);
  assert.strictEqual(plan.updates[0].calledMerged, true, '内置更新不丢已打状态');
  // 未变化文件：哈希一致（服务层据此跳过导入）
  assert.strictEqual(hash1, MergeService.hashBytes(bytes));
});

console.log('[verify] v0.5.3 重复键行全链路保真（xlsx 往返 → 解析 → 合并）');
check('duplicate_key_rows_survive_full_chain', () => {
  // 构造 26 行，其中 2 行同工号（模拟内网多任务行），经 xlsx 写出/解析/准备/合并后必须全部保留
  const headers: string[] = ['责任人', '姓名', '工号', '手机', '是否已打', '备注'];
  const table: string[][] = [headers];
  for (let i = 1; i <= 26; i++) {
    table.push(['张三', '客户' + i, 'E' + (i <= 24 ? 10000 + i : 10001), '+86-199' + (10000000 + i), '', '']);
  }
  const bytes: Uint8Array = XlsxService.write(table);
  const sheet: ParsedSheet = XlsxService.parse(bytes);
  const prepared = ImportLogic.prepare(sheet);
  assert.strictEqual(prepared.rows.length, 26, '解析层不丢行');
  const plan = MergeService.computePlan(prepared.rows, []);
  assert.strictEqual(plan.inserts.length, 26, '合并层不丢重复键行');
  assert.strictEqual(plan.updates.length, 0);
  // 有本地数据时（模拟第二次导入）：全部匹配更新，不产生重复
  const locals: LocalRowSnapshot[] = plan.inserts.map((r: MergeRowData, i: number): LocalRowSnapshot => {
    return { id: i + 1, rowKey: r.rowKey, called: false, connected: false, intention: false };
  });
  const plan2 = MergeService.computePlan(prepared.rows, locals);
  assert.strictEqual(plan2.updates.length, 26);
  assert.strictEqual(plan2.inserts.length, 0);
  assert.strictEqual(plan2.removedLocalIds.length, 0);
});

console.log('[verify] M3 StatusValue 通用判定表 / 三状态合并 / 导出写回 (FR-10/FR-11/R-8/R-9)');
check('status_value_mapping_table', () => {
  for (const v of ['是', '有', '有意向', '打通', '√', '1', 'YES']) {
    assert.strictEqual(StatusValue.toBoolean(v), true, 'should be true: ' + v);
  }
  for (const v of ['否', '无', '无意向', '0', '', '   ', '未知值']) {
    assert.strictEqual(StatusValue.toBoolean(v), false, 'should be false: ' + v);
  }
});
check('status_format_detect_and_export', () => {
  assert.strictEqual(StatusValue.detectFormat(['有', '无', '']), 'has_none');
  assert.strictEqual(StatusValue.detectFormat(['是', '否']), 'yes_no');
  assert.strictEqual(StatusValue.detectFormat(['1']), 'one_blank');
  assert.strictEqual(StatusValue.detectFormat([]), 'yes_no');
  assert.strictEqual(StatusValue.toExportValue(true, 'has_none'), '有');
  assert.strictEqual(StatusValue.toExportValue(false, 'has_none'), '');
  assert.strictEqual(StatusValue.toExportValue(true, 'yes_no'), '是');
  assert.strictEqual(StatusValue.toExportValue(true, 'one_blank'), '1');
});
check('merge_three_status_takes_or', () => {
  // 本地已打通 + 新文件未打通 → 合并后打通（R-8）
  const locals: LocalRowSnapshot[] = [
    { id: 1, rowKey: 'E:10001', called: false, connected: true, intention: false },
    { id: 2, rowKey: 'E:10002', called: false, connected: false, intention: true }
  ];
  const fileRows: MergeRowData[] = [
    row('10001', '张三', '19999999999', false, 1),
    row('10002', '李四', '13800000000', false, 2)
  ];
  fileRows[0].connectedFromFile = false;
  fileRows[1].intentionFromFile = false;
  const plan = MergeService.computePlan(fileRows, locals);
  assert.strictEqual(plan.updates.length, 2);
  assert.strictEqual(plan.updates[0].connectedMerged, true, 'local connected kept (OR)');
  assert.strictEqual(plan.updates[1].intentionMerged, true, 'local intention kept (OR)');
  // 新文件真值也要保留
  fileRows[0].connectedFromFile = true;
  const plan2 = MergeService.computePlan([fileRows[0]], [{ id: 1, rowKey: 'E:10001', called: false, connected: false, intention: false }]);
  assert.strictEqual(plan2.updates[0].connectedMerged, true, 'file connected kept (OR)');
});
check('import_prepare_three_status_and_formats', () => {
  const sheet: ParsedSheet = {
    headers: ['姓名', '工号', '手机', '是否已打', '是否打通', '是否有意向'],
    rows: [
      ['张三', 'E1', '19999999999', '是', '是', '有'],
      ['李四', 'E2', '13800000000', '', '否', '无']
    ]
  };
  const r = ImportLogic.prepare(sheet);
  assert.strictEqual(r.rows[0].connectedFromFile, true);
  assert.strictEqual(r.rows[0].intentionFromFile, true);
  assert.strictEqual(r.rows[1].connectedFromFile, false);
  assert.strictEqual(r.rows[1].intentionFromFile, false);
  assert.strictEqual(r.calledValueFormat, 'yes_no');
  assert.strictEqual(r.connectedValueFormat, 'yes_no');
  assert.strictEqual(r.intentionValueFormat, 'has_none');
  assert.strictEqual(r.rows[0].rawData['是否有意向'], '有', '原值保留');
});
check('export_three_columns_write_back', () => {
  const rows: ExportRow[] = [
    { called: true, connected: true, intention: true, rawData: { '姓名': '张三', '是否已打': '否', '是否打通': '否', '是否有意向': '无' } },
    { called: false, connected: false, intention: false, rawData: { '姓名': '李四', '是否已打': '', '是否打通': '', '是否有意向': '' } }
  ];
  const cols: ExportColumns = {
    called: '是否已打', calledFormat: 'yes_no',
    connected: '是否打通', connectedFormat: 'one_blank',
    intention: '是否有意向', intentionFormat: 'has_none'
  };
  const table: string[][] = ExportLogic.assemble(
    ['姓名', '是否已打', '是否打通', '是否有意向'], cols, rows);
  assert.deepStrictEqual(table[1], ['张三', '是', '1', '有']);
  assert.deepStrictEqual(table[2], ['李四', '', '', '']);
  // 三列均不存在时：全原样
  const colsNone: ExportColumns = {
    called: '', calledFormat: 'yes_no',
    connected: '', connectedFormat: 'yes_no',
    intention: '', intentionFormat: 'yes_no'
  };
  const table2: string[][] = ExportLogic.assemble(['姓名', '备注'], colsNone, rows);
  assert.deepStrictEqual(table2[1], ['张三', '']);
});
check('sample_2000_connected_columns_parsed', () => {
  const bytes: Uint8Array = new Uint8Array(
    fs.readFileSync(path.resolve('samples/名单样例_2000行.xlsx')));
  const prepared = ImportLogic.prepare(XlsxService.parse(bytes));
  const t = prepared.rows.filter(r => r.connectedFromFile).length;
  assert.strictEqual(t, 400, '2000 行样本含 400 条已打通');
  assert.strictEqual(prepared.connectedValueFormat, 'yes_no');
});

check('sample_m3_20rows_status_columns', () => {
  const bytes: Uint8Array = new Uint8Array(
    fs.readFileSync(path.resolve('samples/名单样例_M3_20行.xlsx')));
  const prepared = ImportLogic.prepare(XlsxService.parse(bytes));
  assert.strictEqual(prepared.rows.length, 20);
  assert.strictEqual(prepared.connectedValueFormat, 'yes_no');
  assert.strictEqual(prepared.intentionValueFormat, 'has_none');
  const connectedTrue = prepared.rows.filter(r => r.connectedFromFile).length;
  const intentionTrue = prepared.rows.filter(r => r.intentionFromFile).length;
  assert.strictEqual(connectedTrue, 10, '偶数行打通');
  assert.strictEqual(intentionTrue, 6, 'i%3==0 行有意向（i=3..18 共 6 行）');
});

console.log(`[verify] ALL ${passed} CHECKS PASSED`);
