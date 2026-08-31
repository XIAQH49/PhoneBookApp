import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { CsvService } from './CsvService';
import { ImportService } from './ImportService';
import type { ImportResult } from './ImportService';
import { ConfigDao } from '../database/ConfigDao';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';

const TAG: string = 'IntentImportService';

/** 每批默认行数（PC 端与 APP 端一致；实测单 intent 参数长度上限后由 PC 端微调） */
export const INTENT_BATCH_SIZE: number = 50;

/** intent 载荷 JSON（与 PC 端 tools/intent_sender/sender.ts 同构） */
export interface IntentPayload {
  action: string;
  transferId: string;
  batch: number;
  total: number;
  headers: string[];
  rows: string[][];
}

/** 接收/导入结果 */
export interface IntentImportResult {
  success: boolean;
  message: string;
  total: number;
}

/**
 * PC 意图直达导入（v0.6）：
 * PC 端 bat（hdc shell aa start --ps payload <base64>）分批推送 JSON 载荷，
 * 本服务按 transferId 累积到沙箱（filesDir/intent_import/<transferId>/batch_<n>.json），
 * 收齐（batch==total 且批次连续无缺）后把 headers+rows 拼装 CSV 文本
 * （CsvService.toCsv），再走 ImportService.importFromBytes 复用现有
 * 解析/合并/入库管线（已打状态取"或"保留）；不写 builtin_last_hash（与内置名单独立）。
 * 新 transferId 到达时清掉旧目录（仅保留最新一次传输）。
 */
export class IntentImportService {
  /** 意图参数键（PC 端 --ps 的 key，与 sender.ts 一致） */
  static readonly PARAM_KEY: string = 'payload';
  /** action 标记（与 sender.ts 一致） */
  static readonly ACTION_IMPORT: string = 'import_rows';

  /** 当前传输目录根（filesDir/intent_import） */
  private static rootDir(context: common.UIAbilityContext): string {
    return context.filesDir + '/intent_import';
  }

  /** 某 transferId 的目录 */
  private static transferDir(context: common.UIAbilityContext, transferId: string): string {
    return IntentImportService.rootDir(context) + '/' + transferId;
  }

  /**
   * 处理一次 want（onCreate 冷启动 / onNewWant 热启动共用）：
   * 读取 --ps payload（base64 UTF-8 JSON）→ 解析 → 落盘批次 → 完成判定 → 导入。
   */
  static async handleWant(context: common.UIAbilityContext, want: Want): Promise<IntentImportResult> {
    try {
      const raw: string = IntentImportService.readParam(want);
      if (raw === '') {
        // 普通拉起（无 payload）：静默返回，不打扰
        return { success: false, message: '', total: 0 };
      }
      const payload: IntentPayload = IntentImportService.decodePayload(raw);
      if (payload.action !== IntentImportService.ACTION_IMPORT) {
        Logger.warn(TAG, 'unknown action: ' + payload.action);
        return { success: false, message: '未知 action: ' + payload.action, total: 0 };
      }
      if (payload.batch < 1 || payload.total < 1 ||
        payload.batch > payload.total || payload.headers.length === 0) {
        return { success: false, message: '载荷字段非法', total: 0 };
      }
      // 新 transferId：清旧目录（仅保留最新传输）
      await IntentImportService.resetForTransfer(context, payload.transferId);
      // 落盘当前批次
      const dir: string = IntentImportService.transferDir(context, payload.transferId);
      await IntentImportService.saveBatch(context, payload, dir);
      Logger.info(TAG, `batch saved: transfer=${payload.transferId} ${payload.batch}/${payload.total}, ` +
        `rows=${payload.rows.length}`);
      // 完成判定：已收批次 = 1..total 连续无缺
      const received: boolean[] = await IntentImportService.collectBatches(context, payload.transferId, payload.total);
      const complete: boolean = IntentImportService.isComplete(received);
      if (!complete) {
        return { success: false, message: '接收不完整，请在 PC 端重发', total: 0 };
      }
      // 完整 → 拼 CSV → 走现有导入管线
      return await IntentImportService.importCollected(context, payload.transferId, payload.headers, payload.total);
    } catch (e) {
      Logger.error(TAG, 'handleWant failed: ' + (e as Error).message);
      return { success: false, message: '接收失败：' + (e as Error).message, total: 0 };
    }
  }

  /** 从 want 读取 payload 参数（--ps payload <base64>）；无参数返回空串 */
  private static readParam(want: Want): string {
    const params: Record<string, Object> | undefined = want.parameters;
    if (params === undefined) {
      return '';
    }
    const v: Object | undefined = params[IntentImportService.PARAM_KEY];
    if (v === undefined) {
      return '';
    }
    return String(v);
  }

  /** base64 → UTF-8 JSON 载荷 */
  private static decodePayload(raw: string): IntentPayload {
    const bytes: Uint8Array = IntentImportService.base64ToBytes(raw);
    const text: string = util.TextDecoder.create('utf-8', { fatal: false }).decodeToString(bytes) ?? '';
    return JSON.parse(text) as IntentPayload;
  }

  /** base64 字符串 → 字节（ArkTS 无 atob；用 util.Base64Helper） */
  private static base64ToBytes(raw: string): Uint8Array {
    const helper: util.Base64Helper = new util.Base64Helper();
    const u8: Uint8Array = helper.decodeSync(raw);
    return u8;
  }

  /** 清掉旧 transferId 目录（保留最新的），再建当前 transfer 目录 */
  private static async resetForTransfer(context: common.UIAbilityContext, transferId: string): Promise<void> {
    const root: string = IntentImportService.rootDir(context);
    try {
      if (fs.accessSync(root)) {
        const names: string[] = fs.listFileSync(root);
        for (const n of names) {
          if (n !== transferId) {
            try {
              fs.rmdirSync(root + '/' + n);
            } catch (e) {
              // 删除失败忽略（不阻塞新传输）
            }
          }
        }
      }
    } catch (e) {
      // 根目录不存在，忽略
    }
    try {
      fs.mkdirSync(IntentImportService.transferDir(context, transferId), true);
    } catch (e) {
      // 已存在则忽略
    }
  }

  /** 保存单个批次到 batch_<n>.json（UTF-8） */
  private static async saveBatch(context: common.UIAbilityContext, payload: IntentPayload,
    dir: string): Promise<void> {
    const file: string = dir + '/batch_' + payload.batch + '.json';
    const bytes: Uint8Array = IntentImportService.encodeUtf8(JSON.stringify(payload));
    const fd: number = fs.openSync(file, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(fd, bytes.buffer);
    } finally {
      fs.closeSync(fd);
    }
  }

  /** 收集 1..total 批次是否齐全（按文件名 batch_<n>.json 判定） */
  private static async collectBatches(context: common.UIAbilityContext, transferId: string,
    total: number): Promise<boolean[]> {
    const received: boolean[] = new Array<boolean>(total).fill(false);
    const dir: string = IntentImportService.transferDir(context, transferId);
    try {
      const names: string[] = fs.listFileSync(dir);
      for (const n of names) {
        const m: RegExpMatchArray | null = n.match(/^batch_(\d+)\.json$/);
        if (m !== null) {
          const idx: number = parseInt(m[1], 10);
          if (idx >= 1 && idx <= total) {
            received[idx - 1] = true;
          }
        }
      }
    } catch (e) {
      Logger.error(TAG, 'collectBatches failed: ' + (e as Error).message);
    }
    return received;
  }

  private static isComplete(received: boolean[]): boolean {
    for (const r of received) {
      if (!r) {
        return false;
      }
    }
    return true;
  }

  /** 已收齐：按批次顺序拼 rows → toCsv → importFromBytes（'intent_import.csv'） */
  private static async importCollected(context: common.UIAbilityContext, transferId: string,
    headers: string[], total: number): Promise<IntentImportResult> {
    const dir: string = IntentImportService.transferDir(context, transferId);
    const allRows: string[][] = [];
    for (let b = 1; b <= total; b++) {
      const file: string = dir + '/batch_' + b + '.json';
      const fd: number = fs.openSync(file, fs.OpenMode.READ_ONLY);
      let text: string = '';
      try {
        const stat: fs.Stat = fs.statSync(fd);
        const buf: ArrayBuffer = new ArrayBuffer(stat.size);
        fs.readSync(fd, buf);
        const u8: Uint8Array = new Uint8Array(buf);
        text = util.TextDecoder.create('utf-8', { fatal: false }).decodeToString(u8) ?? '';
      } finally {
        fs.closeSync(fd);
      }
      const p: IntentPayload = JSON.parse(text) as IntentPayload;
      allRows.push(...p.rows);
    }
    // headers + rows → CSV 文本（表头在首行）
    const table: string[][] = [headers.slice()];
    table.push(...allRows);
    const csv: string = CsvService.toCsv(table);
    const bytes: Uint8Array = IntentImportService.encodeUtf8(csv);
    const result: ImportResult = await ImportService.importFromBytes(bytes, 'intent_import.csv');
    Logger.info(TAG, `intent import done: total=${result.total}, ok=${result.success}, msg=${result.message}`);
    if (result.success) {
      // 写入 UI 标记（Index.onPageShow 检测后 toast + 刷新 + 清除）
      await ConfigDao.set(Constants.CONFIG_LAST_INTENT_IMPORT,
        result.total + '@' + Date.now());
    }
    return { success: result.success, message: result.message, total: result.total };
  }

  private static encodeUtf8(text: string): Uint8Array {
    const encoder: util.TextEncoder = new util.TextEncoder();
    const u8: Uint8Array = encoder.encodeInto(text);
    return u8;
  }
}
