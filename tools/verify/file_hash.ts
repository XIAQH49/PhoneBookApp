/**
 * 打印文件的 FNV-1a 哈希（与 APP 内置名单变更检测同一算法）。
 * 黑盒比对：内网导出文件 与 rawfile 副本是否一致、或与安装包内提取的名单是否一致。
 * 用法：node --import ./tools/verify/register.mjs tools/verify/file_hash.ts <文件1> <文件2> ...
 */
import * as fs from 'node:fs';
import { MergeService } from '../../entry/src/main/ets/service/MergeService.ts';

const args: string[] = process.argv.slice(2);
if (args.length === 0) {
  console.error('用法: node --import ./tools/verify/register.mjs tools/verify/file_hash.ts <文件路径>...');
  process.exit(1);
}
for (const f of args) {
  const bytes: Uint8Array = new Uint8Array(fs.readFileSync(f));
  console.log(`${MergeService.hashBytes(bytes)}  ${f}  (${bytes.length} bytes)`);
}
