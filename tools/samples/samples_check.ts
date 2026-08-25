/**
 * 验证 samples/ 目录生成的三个样本文件可被 APP 正确解析（同一套解析代码）。
 * 运行：node --import ./tools/verify/register.mjs tools/samples/samples_check.ts
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { CsvService } from '../../entry/src/main/ets/service/CsvService.ts';
import { XlsxService } from '../../entry/src/main/ets/service/XlsxService.ts';
import { ImportLogic } from '../../entry/src/main/ets/service/ImportLogic.ts';
import type { Decoder, DecoderFactory } from '../../entry/src/main/ets/service/CsvService.ts';

const factory: DecoderFactory = {
  create(encoding: string, fatal: boolean): Decoder {
    return {
      decode(data: Uint8Array): string {
        return new TextDecoder(encoding, { fatal: fatal }).decode(data);
      }
    };
  }
};

const dir = path.resolve('samples');
const files = fs.readdirSync(dir);
console.log('[check] samples:', files.join(', '));

for (const f of files) {
  const p = path.join(dir, f);
  const bytes = new Uint8Array(fs.readFileSync(p));
  if (f.endsWith('.csv')) {
    const r = CsvService.detectAndDecode(bytes, factory);
    const sheet = CsvService.parseCsv(r.text);
    const prep = ImportLogic.prepare(sheet);
    console.log(`[check] ${f}: encoding=${r.encoding}, 行数=${prep.rows.length}, ` +
      `首行姓名=${prep.rows[0].name}, 号码=${prep.rows[0].phoneNumbers[0]}, ` +
      `已打=${prep.rows[0].calledFromFile}`);
  } else if (f.endsWith('.xlsx')) {
    const sheet = XlsxService.parse(bytes);
    const prep = ImportLogic.prepare(sheet);
    const assignees = new Set<string>();
    for (const r of prep.rows) {
      assignees.add(r.assignee);
    }
    console.log(`[check] ${f}: 行数=${prep.rows.length}, 责任人=${assignees.size} 个` +
      (assignees.has('') ? '(含未分配)' : ''), `, 末行=${prep.rows[prep.rows.length - 1].name}`);
  }
}
console.log('[check] DONE');
