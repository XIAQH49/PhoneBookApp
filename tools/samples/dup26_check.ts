/**
 * 自检：26 行含重复工号样本经 APP 同链路解析/准备/合并后必须 26 行全保留。
 * 运行：node --import ./tools/verify/register.mjs tools/samples/dup26_check.ts
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { XlsxService } from '../../entry/src/main/ets/service/XlsxService.ts';
import { ImportLogic } from '../../entry/src/main/ets/service/ImportLogic.ts';
import { MergeService } from '../../entry/src/main/ets/service/MergeService.ts';

export function run(): void {
  const bytes = new Uint8Array(fs.readFileSync(path.resolve('samples/名单样例_26行_含重复工号.xlsx')));
  const sheet = XlsxService.parse(bytes);
  const prepared = ImportLogic.prepare(sheet);
  const plan = MergeService.computePlan(prepared.rows, []);
  console.log(`[check] 解析行数=${prepared.rows.length}, 合并后保留=${plan.inserts.length}`);
  if (prepared.rows.length !== 26 || plan.inserts.length !== 26) {
    console.error('[check] FAIL: 应 26/26');
    process.exit(1);
  }
  console.log('[check] PASS: 26/26 全保留（旧版会丢 2 行）');
}

run();
