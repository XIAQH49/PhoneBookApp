/**
 * 生成真机验证用样本文件（samples/）：
 *  - 名单样例_2000行.xlsx（责任人/姓名/工号/手机/是否已打/是否打通/是否有意向/备注，2000 行）
 *  - 名单样例_UTF8.csv（UTF-8 BOM，与 xlsx 同内容前 20 行）
 * 运行：node --import ./tools/verify/register.mjs tools/samples/gen_samples.ts
 */
import { XlsxService } from '../../entry/src/main/ets/service/XlsxService.ts';
import { CsvService } from '../../entry/src/main/ets/service/CsvService.ts';
import * as fs from 'node:fs';
import * as path from 'node:path';

const HEADERS: string[] = ['责任人', '姓名', '工号', '手机', '是否已打', '是否打通', '是否有意向', '备注'];
const ASSIGNEES: string[] = ['张三', '李四', '王五', '赵六', '钱七'];

function buildRows(count: number): string[][] {
  const table: string[][] = [HEADERS];
  for (let i = 1; i <= count; i++) {
    const phone: string = '+86-199' + String(10000000 + i);
    let phoneCell: string = phone;
    if (i % 7 === 0) {
      phoneCell = phone + '（国内）';
    } else if (i % 11 === 0) {
      phoneCell = phone + '/' + '+86-138' + String(10000000 + i);
    }
    const row: string[] = [
      i % 13 === 0 ? '' : ASSIGNEES[i % ASSIGNEES.length], // 约 7.7% 未分配
      '客户' + i,
      'E' + (10000 + i),
      phoneCell,
      i % 3 === 0 ? '是' : '',
      i % 5 === 0 ? '是' : '',
      '',
      '备注内容' + i
    ];
    table.push(row);
  }
  return table;
}

const samplesDir = path.resolve('samples');
fs.mkdirSync(samplesDir, { recursive: true });

// xlsx 2000 行
const table = buildRows(2000);
const xlsxBytes = XlsxService.write(table);
fs.writeFileSync(path.join(samplesDir, '名单样例_2000行.xlsx'), xlsxBytes);
console.log('[gen] xlsx:', xlsxBytes.length, 'bytes');

// UTF-8 CSV（前 20 行 + 表头）
const csvTable = buildRows(20);
const csvText = CsvService.toCsv(csvTable);
fs.writeFileSync(path.join(samplesDir, '名单样例_UTF8.csv'), csvText, 'utf8');
console.log('[gen] csv(utf8):', csvText.length, 'chars');
console.log('[gen] DONE ->', samplesDir);
