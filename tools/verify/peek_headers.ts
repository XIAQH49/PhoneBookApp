// 临时工具：样本表头与首行值（M3 断言准备）
import * as fs from 'node:fs';
import * as path from 'node:path';
import { XlsxService } from '../../entry/src/main/ets/service/XlsxService.ts';
import { ImportLogic } from '../../entry/src/main/ets/service/ImportLogic.ts';

const bytes = new Uint8Array(fs.readFileSync(path.resolve('samples', '名单样例_2000行.xlsx')));
const sheet = XlsxService.parse(bytes);
console.log('headers:', JSON.stringify(sheet.headers));
console.log('row1:', JSON.stringify(sheet.rows[0]));
console.log('row2:', JSON.stringify(sheet.rows[1]));
const p = ImportLogic.prepare(sheet);
console.log('mapping:', JSON.stringify(p.mapping.toRecord()));
console.log('calledFormat:', p.calledValueFormat, '| connectedFormat:', p.connectedValueFormat, '| intentionFormat:', p.intentionValueFormat);
const t = p.rows.filter(r => r.connectedFromFile).length;
const i = p.rows.filter(r => r.intentionFromFile).length;
console.log('connectedTrue rows:', t, '| intentionTrue rows:', i);
