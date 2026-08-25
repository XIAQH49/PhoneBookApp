/**
 * T-1 性能预验证（Node，使用与被测应用同一份 xlsx 库文件）：
 * 生成 2000 行 × 8 列（含中文/号码/备注）→ 写出 xlsx → 重新解析，统计耗时。
 * 说明：Node 为设备 JS 引擎的性能下界参考；设备侧达标判据仍以 docs/06 T-1 实测为准（≤10s）。
 * 运行：node --import ./tools/verify/register.mjs tools/verify/perf.ts
 */
import { XlsxService } from '../../entry/src/main/ets/service/XlsxService.ts';

const ROWS = 2000;
const HEADERS: string[] = ['责任人', '姓名', '工号', '手机', '是否已打', '是否打通', '是否有意向', '备注'];
const ASSIGNEES: string[] = ['张三', '李四', '王五', '赵六', '钱七'];

function buildTable(): string[][] {
  const table: string[][] = [HEADERS];
  for (let i = 1; i <= ROWS; i++) {
    const phone: string = '+86-199' + String(10000000 + i);
    const row: string[] = [
      ASSIGNEES[i % ASSIGNEES.length],
      '客户' + i,
      'E' + (10000 + i),
      phone + (i % 7 === 0 ? '（国内）' : ''),
      i % 3 === 0 ? '是' : '',
      '',
      '',
      '备注内容' + i
    ];
    table.push(row);
  }
  return table;
}

console.log(`[perf] 生成 ${ROWS} 行 x ${HEADERS.length} 列表格…`);
const table: string[][] = buildTable();

let t0 = Date.now();
const bytes: Uint8Array = XlsxService.write(table);
const tWrite = Date.now() - t0;
console.log(`[perf] xlsx 写出: ${tWrite} ms, ${(bytes.length / 1024).toFixed(1)} KB`);

t0 = Date.now();
const parsed = XlsxService.parse(bytes);
const tParse = Date.now() - t0;
console.log(`[perf] xlsx 解析: ${tParse} ms, 行数=${parsed.rows.length}`);

t0 = Date.now();
const parsed2 = XlsxService.parse(bytes);
const tParse2 = Date.now() - t0;
console.log(`[perf] xlsx 解析(第二次,热缓存): ${tParse2} ms`);

if (parsed.rows.length !== ROWS) {
  console.error('[perf] FAIL: 行数不一致');
  process.exit(1);
}
const last = parsed.rows[parsed.rows.length - 1];
console.log(`[perf] 抽查末行: ${last[1]} / ${last[3]} / 已打=${last[4]}`);
console.log('[perf] DONE');
