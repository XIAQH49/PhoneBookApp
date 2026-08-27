import { common } from '@kit.AbilityKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { CallListDao } from '../database/CallListDao';
import { MetaDao } from '../database/MetaDao';
import { ConfigDao } from '../database/ConfigDao';
import { StatusDao } from '../database/StatusDao';
import type { StatusEntry } from '../database/StatusDao';
import { CallRecord } from '../model/CallRecord';
import { ImportMeta } from '../model/ImportMeta';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { CsvService } from './CsvService';
import { XlsxService } from './XlsxService';
import { ExportLogic } from './ExportLogic';
import type { ExportRow, ExportColumns } from './ExportLogic';

const TAG: string = 'ExportService';

/** 导出结果 */
export interface ExportResult {
  success: boolean;
  message: string;
  fileName: string;
}

/**
 * 导出编排（FR-7，设计规格 4.4 节）：
 * 按范围查询 → 按原列顺序组装（已打列按格式写回）→ CSV 写出（UTF-8 BOM）
 * → 系统保存选择器；xlsx/csv 均按原文件格式导出（xlsx 真机验证见 docs/06 T-1）。
 */
export class ExportService {
  static async exportCsv(context: common.UIAbilityContext, scope: string): Promise<ExportResult> {
    try {
      const meta: ImportMeta | undefined = await MetaDao.getActive();
      if (meta === undefined) {
        return { success: false, message: '尚无数据，请先导入名单', fileName: '' };
      }
      const assignee: string = await ConfigDao.getLastAssignee();
      const all: boolean = scope === Constants.EXPORT_SCOPE_ALL;
      const records: CallRecord[] = await CallListDao.queryExportRows(assignee, all);
      if (records.length === 0) {
        return { success: false, message: '当前范围内没有可导出的数据', fileName: '' };
      }
      // M3：批量读取打通/意向状态（导出写回）
      const ids: number[] = records.map((r: CallRecord): number => r.id);
      const statuses: StatusEntry[] = await StatusDao.getStatuses(ids,
        [Constants.STATUS_KEY_CONNECTED, Constants.STATUS_KEY_INTENTION]);
      const connectedMap: Map<number, boolean> = new Map<number, boolean>();
      const intentionMap: Map<number, boolean> = new Map<number, boolean>();
      for (const s of statuses) {
        if (s.key === Constants.STATUS_KEY_CONNECTED) {
          connectedMap.set(s.rowId, s.value);
        } else if (s.key === Constants.STATUS_KEY_INTENTION) {
          intentionMap.set(s.rowId, s.value);
        }
      }
      const exportRows: ExportRow[] = records.map((r: CallRecord): ExportRow => {
        const row: ExportRow = {
          called: r.called,
          connected: connectedMap.get(r.id) ?? false,
          intention: intentionMap.get(r.id) ?? false,
          rawData: r.rawData
        };
        return row;
      });
      const cols: ExportColumns = {
        called: meta.columnMapping['called'] ?? '',
        calledFormat: meta.calledValueFormat,
        connected: meta.columnMapping['connected'] ?? '',
        connectedFormat: meta.connectedValueFormat,
        intention: meta.columnMapping['intention'] ?? '',
        intentionFormat: meta.intentionValueFormat
      };
      const table: string[][] = ExportLogic.assemble(meta.allColumns, cols, exportRows);
      const isXlsx: boolean = meta.fileFormat === 'xlsx';
      const ext: string = isXlsx ? '.xlsx' : '.csv';
      const fileName: string = ExportLogic.buildFileName(meta.fileName, new Date(), ext);
      let bytes: Uint8Array;
      if (isXlsx) {
        // T-8：与原文件同格式导出 xlsx
        bytes = XlsxService.write(table);
      } else {
        const csvText: string = CsvService.toCsv(table);
        bytes = new util.TextEncoder().encodeInto(csvText);
      }
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      const saveOpts: picker.DocumentSaveOptions = { newFileNames: [fileName] };
      const uris: string[] = await documentPicker.save(saveOpts);
      if (uris.length === 0) {
        return { success: false, message: '已取消导出', fileName: '' };
      }
      ExportService.writeUri(uris[0], bytes);
      Logger.info(TAG, `export ok: ${records.length} rows -> ${fileName}`);
      return { success: true, message: '导出成功：' + fileName, fileName: fileName };
    } catch (e) {
      Logger.error(TAG, 'export failed: ' + (e as Error).message);
      return { success: false, message: '导出失败：' + (e as Error).message, fileName: '' };
    }
  }

  /** 字节写入 uri（供导出结果与导出原始内置文件共用） */
  static writeUri(uri: string, bytes: Uint8Array): void {
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(uri,
        fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, bytes.buffer);
    } catch (e) {
      throw new Error('写入文件失败：' + (e as Error).message);
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
}
