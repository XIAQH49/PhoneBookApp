import { common } from '@kit.AbilityKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { DbHelper } from '../database/DbHelper';
import { CallListDao } from '../database/CallListDao';
import { MetaDao } from '../database/MetaDao';
import { StatusDao } from '../database/StatusDao';
import { ImportMeta } from '../model/ImportMeta';
import { CallRecord } from '../model/CallRecord';
import { Logger } from '../common/Logger';
import { CsvService, Decoder, DecoderFactory, ParsedSheet } from './CsvService';
import { XlsxService } from './XlsxService';
import { ImportLogic, ImportPrepareResult } from './ImportLogic';
import { MergeService, MergeRowData, LocalRowSnapshot, MergePlan } from './MergeService';

const TAG: string = 'ImportService';

/** 导入结果 */
export interface ImportResult {
  success: boolean;
  message: string;
  total: number;
}

/** 导入进度（百分比 + 阶段文案） */
export interface ProgressInfo {
  percent: number;
  stage: string;
}

/**
 * 导入编排（FR-1 / FR-2，设计规格 4.1 / 4.2 节）：
 * picker 选文件 → 读取字节 → 格式识别 → CSV 解码/解析（xlsx 待 T-1 验证后接入 T8）
 * → ImportLogic 构建 → MergeService 合并计划 → 单事务入库 + active 切换。
 */
export class ImportService {
  /** 从文件选择器选取文件并导入（UI 入口） */
  static async pickAndImport(context: common.UIAbilityContext,
    onProgress?: (p: ProgressInfo) => void): Promise<ImportResult> {
    let uris: string[];
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const opts: picker.DocumentSelectOptions = {
        maxSelectNumber: 1,
        fileSuffixFilters: ['.csv', '.xlsx']
      };
      uris = await documentPicker.select(opts);
    } catch (e) {
      Logger.error(TAG, 'picker failed: ' + (e as Error).message);
      return { success: false, message: '选择文件失败', total: 0 };
    }
    if (uris.length === 0) {
      return { success: false, message: '未选择文件', total: 0 };
    }
    return await ImportService.importFromUri(uris[0], onProgress);
  }

  /** 从指定 uri 导入（供 pickAndImport 与测试复用） */
  static async importFromUri(uri: string,
    onProgress?: (p: ProgressInfo) => void): Promise<ImportResult> {
    try {
      if (onProgress !== undefined) {
        onProgress({ percent: 5, stage: '读取文件' });
      }
      const bytes: Uint8Array = ImportService.readUri(uri);
      const fileName: string = ImportService.extractFileName(uri);
      return await ImportService.importFromBytes(bytes, fileName, onProgress);
    } catch (e) {
      Logger.error(TAG, 'importFromUri failed: ' + (e as Error).message);
      return { success: false, message: '导入失败：' + (e as Error).message, total: 0 };
    }
  }

  /** 从字节导入（内置文件/内存数据共用核心：解码 → 解析 → 合并入库） */
  static async importFromBytes(bytes: Uint8Array, fileName: string,
    onProgress?: (p: ProgressInfo) => void): Promise<ImportResult> {
    try {
      if (!DbHelper.isReady()) {
        return { success: false, message: '数据库未就绪，请稍后重试', total: 0 };
      }
      const lower: string = fileName.toLowerCase();
      let sheet: ParsedSheet;
      let encoding: string;
      let format: string;
      if (lower.endsWith('.csv')) {
        if (onProgress !== undefined) {
          onProgress({ percent: 15, stage: '编码检测' });
        }
        const decoded = CsvService.detectAndDecode(bytes, ImportService.decoderFactory());
        encoding = decoded.encoding;
        if (onProgress !== undefined) {
          onProgress({ percent: 30, stage: '解析CSV' });
        }
        sheet = CsvService.parseCsv(decoded.text);
        format = 'csv';
      } else if (lower.endsWith('.xlsx')) {
        // T-8：内置 SheetJS 解析（功能面 Node 已验证；真机加载与性能见 T-1 spike）
        if (onProgress !== undefined) {
          onProgress({ percent: 30, stage: '解析XLSX' });
        }
        sheet = XlsxService.parse(bytes);
        encoding = 'n/a';
        format = 'xlsx';
      } else {
        return { success: false, message: '不支持的文件类型，请选择 .csv 或 .xlsx', total: 0 };
      }
      if (sheet.headers.length === 0 || sheet.rows.length === 0) {
        return { success: false, message: '文件为空或仅含表头', total: 0 };
      }
      if (onProgress !== undefined) {
        onProgress({ percent: 50, stage: '构建数据' });
      }
      const prepared: ImportPrepareResult = ImportLogic.prepare(sheet);
      if (onProgress !== undefined) {
        onProgress({ percent: 70, stage: '合并入库' });
      }
      await ImportService.persist(prepared, fileName, format, encoding);
      if (onProgress !== undefined) {
        onProgress({ percent: 100, stage: '完成' });
      }
      Logger.info(TAG, `import ok: ${prepared.rows.length} rows, file=${fileName}, encoding=${encoding}`);
      return { success: true, message: '导入成功', total: prepared.rows.length };
    } catch (e) {
      Logger.error(TAG, 'import failed: ' + (e as Error).message);
      return { success: false, message: '导入失败：' + (e as Error).message, total: 0 };
    }
  }

  /** 合并计划落库（单事务：插入/更新/移除/元信息切换原子生效，NFR-5） */
  private static async persist(prepared: ImportPrepareResult, fileName: string,
    format: string, encoding: string): Promise<void> {
    const localKeyRows = await CallListDao.getActiveKeyRows();
    const snapshots: LocalRowSnapshot[] = localKeyRows.map((k): LocalRowSnapshot => {
      return { id: k.id, rowKey: k.rowKey, called: k.called };
    });
    const plan: MergePlan = MergeService.computePlan(prepared.rows, snapshots);
    // 导入诊断日志（内网设备丢行排查用）：hilog 过滤 'ImportService' 即可见
    Logger.info(TAG,
      `merge stats: parsed=${prepared.rows.length}, skippedEmpty=${prepared.skippedEmpty}, ` +
      `inserts=${plan.inserts.length}, updates=${plan.updates.length}, removed=${plan.removedLocalIds.length}`);
    await DbHelper.runInTransaction(async () => {
      const meta: ImportMeta = new ImportMeta();
      meta.fileName = fileName;
      meta.fileFormat = format;
      meta.fileEncoding = encoding;
      meta.columnMapping = prepared.mapping.toRecord();
      meta.allColumns = prepared.allColumns;
      meta.calledValueFormat = prepared.calledValueFormat;
      meta.active = false;
      meta.importedAt = Date.now();
      const metaId: number = await MetaDao.insert(meta);
      for (const row of plan.inserts) {
        const record: CallRecord = ImportService.toRecord(metaId, row, row.calledFromFile);
        await CallListDao.insertPlain(record);
      }
      for (const u of plan.updates) {
        await CallListDao.updateFromFile(u.localId, u.data, u.calledMerged);
        await StatusDao.upsertCalledPlain(u.localId, u.calledMerged ? 1 : 0);
      }
      await CallListDao.markRemoved(plan.removedLocalIds);
      await MetaDao.clearActivePlain();
      await MetaDao.setActivePlain(metaId);
    });
  }

  private static toRecord(metaId: number, data: MergeRowData, called: boolean): CallRecord {
    const record: CallRecord = new CallRecord();
    record.metaId = metaId;
    record.rowNo = data.rowNo;
    record.rowKey = data.rowKey;
    record.assignee = data.assignee;
    record.name = data.name;
    record.empNo = data.empNo;
    record.phoneRaw = data.phoneRaw;
    record.phoneNumbers = data.phoneNumbers;
    record.called = called;
    record.rawData = data.rawData;
    record.inFile = true;
    return record;
  }

  /** 读取文件全部字节（picker uri 支持 file:// 与 datashare uri） */
  private static readUri(uri: string): Uint8Array {
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat: fs.Stat = fs.statSync(file.fd);
      const buf: ArrayBuffer = new ArrayBuffer(stat.size);
      const readLen: number = fs.readSync(file.fd, buf);
      return new Uint8Array(buf, 0, readLen);
    } catch (e) {
      throw new Error('读取文件失败：' + (e as Error).message);
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (e) {
          // 关闭失败不影响主流程
        }
      }
    }
  }

  private static extractFileName(uri: string): string {
    let name: string = uri;
    const q: number = name.indexOf('?');
    if (q >= 0) {
      name = name.substring(0, q);
    }
    const slash: number = name.lastIndexOf('/');
    if (slash >= 0) {
      name = name.substring(slash + 1);
    }
    try {
      name = decodeURIComponent(name);
    } catch (e) {
      // 保持原名
    }
    return name;
  }

  /** util.TextDecoder 适配（T-2 真机验证 gbk 支持度） */
  private static decoderFactory(): DecoderFactory {
    return {
      create(encoding: string, fatal: boolean): Decoder {
        return {
          decode(data: Uint8Array): string {
            const opts: util.TextDecoderOptions = { fatal: fatal };
            const td: util.TextDecoder = new util.TextDecoder(encoding, opts);
            return td.decode(data);
          }
        };
      }
    };
  }
}
