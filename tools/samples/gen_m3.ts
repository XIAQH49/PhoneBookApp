// M3 样本生成：20 行 xlsx，含 是否打通（是/空）与 是否有意向（有/空）两列。
// 用于真机回归：导入判定、详情勾选、重启保持、导出写回格式（yes_no / has_none）。
// 运行：node --import ./tools/verify/register.mjs tools/samples/gen_m3.ts
import * as fs from 'node:fs';
import * as path from 'node:path';
import { XlsxService } from '../../entry/src/main/ets/service/XlsxService.ts';

const headers: string[] = ['责任人', '姓名', '工号', '手机', '是否已打', '是否打通', '是否有意向', '备注'];
const table: string[][] = [headers];
for (let i = 1; i <= 20; i++) {
  const connected = i % 2 === 0 ? '是' : '';
  const intention = i % 3 === 0 ? '有' : '';
  table.push([
    '张三',
    '客户' + i,
    'M3' + (10000 + i),
    '+86-199' + (10000000 + i) + '（国内）',
    '',
    connected,
    intention,
    'M3测试' + i
  ]);
}
const bytes: Uint8Array = XlsxService.write(table);
const out = path.resolve('samples', '名单样例_M3_20行.xlsx');
fs.writeFileSync(out, bytes);
console.log('written:', out, bytes.length, 'bytes');
