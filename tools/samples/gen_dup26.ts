/**
 * 生成 v0.5.3 丢行 bug 复现样本：26 行，其中第 25/26 行同工号（同姓名+手机、备注不同），
 * 旧版去重逻辑会丢 2 行（26→24），修复后应 26 行全保留。
 * 运行：node --import ./tools/verify/register.mjs tools/samples/gen_dup26.ts
 */
import { XlsxService } from '../../entry/src/main/ets/service/XlsxService.ts';
import * as fs from 'node:fs';
import * as path from 'node:path';

const HEADERS: string[] = ['责任人', '姓名', '工号', '手机', '是否已打', '备注'];
const table: string[][] = [HEADERS];
for (let i = 1; i <= 26; i++) {
  const dup: boolean = i >= 25; // 第 25/26 行同工号
  const emp: string = dup ? 'E10001' : 'E' + (10000 + i);
  table.push([
    '张三',
    dup ? '重复客户' : '客户' + i,
    emp,
    dup ? '+86-19999999999' : '+86-199' + (10000000 + i),
    '',
    '任务' + i
  ]);
}
const bytes: Uint8Array = XlsxService.write(table);
const out: string = path.resolve('samples/名单样例_26行_含重复工号.xlsx');
fs.writeFileSync(out, bytes);
console.log('[gen]', out, bytes.length, 'bytes, 26 行（第 25/26 行同工号 E10001）');
