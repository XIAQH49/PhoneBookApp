/**
 * PC 端意图发送器（v0.6）：解析 Excel/CSV 名单 → 分批 → base64(UTF-8 JSON) → hdc aa start 推送。
 *
 * 复用 entry 下的同一套纯 TS 解析代码（XlsxService/CsvService），与 APP 端解析一致；
 * 载荷格式与 APP 端 IntentImportService.IntentPayload 同构。
 *
 * 运行（由 send_list.bat 调用）：
 *   node --import ../verify/register.mjs sender.ts <文件> [--batch 50] [--max-chars 8000] [--dry]
 *
 * 分批策略（v0.6.1）：按载荷大小自适应分批——逐行累加，精确编码后超过
 *   --max-chars（默认 8000 字符）即切批，同时受 --batch 行数上限约束。
 *   宽表（如 20 列真实名单）与窄表（6 列样例）单行字节差异可达 4 倍，
 *   固定行数分批会产生 23KB+ 的超长 intent 参数，故改为大小优先。
 *
 * 环境：HDC 环境变量可覆盖 hdc 路径；默认 DevEco SDK 固定路径。
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { spawnSync } from 'node:child_process';
import { XlsxService } from '../../entry/src/main/ets/service/XlsxService.ts';
import { CsvService } from '../../entry/src/main/ets/service/CsvService.ts';
import type { ParsedSheet } from '../../entry/src/main/ets/service/CsvService.ts';

const HDC_DEFAULT = 'D:\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';
const BUNDLE = 'com.example.phonebookapp';
const ABILITY = 'EntryAbility';
const ACTION = 'import_rows';
const PARAM_KEY = 'payload';

interface RowPayload {
  action: string;
  transferId: string;
  batch: number;
  total: number;
  headers: string[];
  rows: string[][];
}

function fail(msg: string): never {
  console.error('[sender] FAIL: ' + msg);
  process.exit(1);
}

function parseArgs(): { file: string; batch: number; maxChars: number; dry: boolean } {
  const argv = process.argv.slice(2);
  let file = '';
  let batch = 50;
  let maxChars = 8000;
  let dry = false;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--batch' && i + 1 < argv.length) {
      batch = parseInt(argv[i + 1], 10);
      i++;
    } else if (argv[i] === '--max-chars' && i + 1 < argv.length) {
      maxChars = parseInt(argv[i + 1], 10);
      i++;
    } else if (argv[i] === '--dry') {
      dry = true;
    } else if (!file) {
      file = argv[i];
    }
  }
  if (!file) {
    fail('缺少文件参数');
  }
  if (!fs.existsSync(file)) {
    fail('文件不存在: ' + file);
  }
  if (batch < 1 || maxChars < 512) {
    fail('--batch 须 >= 1 且 --max-chars 须 >= 512');
  }
  return { file, batch, maxChars, dry };
}

/** 读取并解析表格（xlsx / csv，与 APP 同一套解析代码） */
function parseSheet(file: string): ParsedSheet {
  const bytes = new Uint8Array(fs.readFileSync(file));
  const lower = file.toLowerCase();
  if (lower.endsWith('.xlsx')) {
    return XlsxService.parse(bytes);
  }
  if (lower.endsWith('.csv')) {
    // Node 侧用全局 TextDecoder 适配（与 verify 套件一致）
    const decoded = CsvService.detectAndDecode(bytes, {
      create(encoding: string, fatal: boolean) {
        return {
          decode(data: Uint8Array): string {
            const td = new TextDecoder(encoding, { fatal });
            return td.decode(data);
          }
        };
      }
    });
    return CsvService.parseCsv(decoded.text);
  }
  fail('仅支持 .xlsx / .csv');
}

/** base64（标准）编码 UTF-8 字符串 */
function base64Of(text: string): string {
  return Buffer.from(text, 'utf8').toString('base64');
}

function runHdc(args: string[]): { code: number; out: string } {
  const hdc = process.env.HDC ?? HDC_DEFAULT;
  const r = spawnSync(hdc, args, { encoding: 'utf8', timeout: 30000 });
  return { code: r.status ?? -1, out: ((r.stdout ?? '') + (r.stderr ?? '')).trim() };
}

/** 编码某批载荷（total 用上限占位，长度估算偏保守） */
function encodeBatch(transferId: string, headers: string[], batchNo: number,
  total: number, rows: string[][]): string {
  const payload: RowPayload = {
    action: ACTION,
    transferId,
    batch: batchNo,
    total,
    headers: headers.slice(),
    rows
  };
  return base64Of(JSON.stringify(payload));
}

/**
 * 按载荷大小自适应分批：逐行累加，精确编码长度超过 maxChars 即切批
 * （行数同时受 batchCap 约束）；单行超长的行单独成批并告警。
 */
function splitBatches(transferId: string, headers: string[], rows: string[][],
  batchCap: number, maxChars: number): string[][][] {
  const chunks: string[][][] = [];
  let cur: string[][] = [];
  for (const row of rows) {
    cur.push(row);
    if (cur.length >= batchCap ||
      encodeBatch(transferId, headers, 1, 99999, cur).length > maxChars) {
      if (cur.length > 1 &&
        encodeBatch(transferId, headers, 1, 99999, cur).length > maxChars) {
        // 超长由最后一行触发：弹出该行，单独成批或留给下一批
        cur.pop();
        chunks.push(cur);
        cur = [row];
        if (encodeBatch(transferId, headers, 1, 99999, cur).length > maxChars) {
          console.warn(`[sender] 警告：单行载荷超 ${maxChars} 字符，单独成批发送`);
          chunks.push(cur);
          cur = [];
        }
      } else {
        chunks.push(cur);
        cur = [];
      }
    }
  }
  if (cur.length > 0) {
    chunks.push(cur);
  }
  return chunks;
}

function main(): void {
  const { file, batch, maxChars, dry } = parseArgs();
  const sheet = parseSheet(file);
  if (sheet.headers.length === 0 || sheet.rows.length === 0) {
    fail('表格为空或仅含表头');
  }
  console.log(`[sender] ${path.basename(file)}: headers=${sheet.headers.length} 列, rows=${sheet.rows.length} 行`);
  console.log(`[sender] headers: ${sheet.headers.join(' / ')}`);

  const transferId = String(Date.now());
  const chunks: string[][][] = splitBatches(transferId, sheet.headers, sheet.rows, batch, maxChars);
  const totalBatches = chunks.length;
  console.log(`[sender] transferId=${transferId}, rowCap=${batch}, maxChars=${maxChars}, totalBatches=${totalBatches}`);

  let okCount = 0;
  for (let b = 1; b <= totalBatches; b++) {
    const rows = chunks[b - 1];
    const encoded = encodeBatch(transferId, sheet.headers, b, totalBatches, rows);
    if (dry) {
      console.log(`[sender][dry] batch ${b}/${totalBatches}: ${rows.length} 行, payload ${encoded.length} 字符`);
      okCount++;
      continue;
    }
    const r = runHdc(['shell', 'aa', 'start', '-b', BUNDLE, '-a', ABILITY,
      '--ps', PARAM_KEY, encoded]);
    // 严格匹配 aa 成功输出（"start ability successfully."），避免 usage/帮助文本误匹配
    const ok = /^start ability successfully/im.test(r.out);
    if (ok) {
      okCount++;
      console.log(`[sender] batch ${b}/${totalBatches}: OK (${rows.length} 行)`);
    } else {
      console.error(`[sender] batch ${b}/${totalBatches}: FAIL -> ${r.out}`);
      console.error(`[sender] 停止发送（剩余批次未发）；请检查 hdc 与设备连接后重试`);
      process.exit(1);
    }
  }
  console.log(`[sender] 完成：${okCount}/${totalBatches} 批，共 ${sheet.rows.length} 行`);
  console.log(`[sender] 如 APP 提示“接收不完整”，请原样重跑本脚本（transferId 会刷新）`);
}

main();
