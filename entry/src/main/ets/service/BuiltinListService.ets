import { common } from '@kit.AbilityKit';
import { ConfigDao } from '../database/ConfigDao';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { ImportService } from './ImportService';
import type { ImportResult } from './ImportService';
import { MergeService } from './MergeService';

const TAG: string = 'BuiltinListService';

/** 内置名单命名约定：rawfile 目录下名为 名单.xlsx 或 名单.csv（优先 xlsx） */
const BUILTIN_CANDIDATES: string[] = ['名单.xlsx', '名单.csv'];

/**
 * 内置名单服务（v0.5）：
 * 名单文件随 APP 打包（entry/src/main/resources/rawfile/），内网"只能进不能出"场景下
 * 无需 USB 拷贝/手动选择：启动自动检测内置文件内容哈希变化 → 变化即合并导入（已打状态保留，
 * 合并规则同 FR-2 状态取"或"）；亦可在主页点"内置名单"手动导入。
 */
export class BuiltinListService {
  /** 查找内置名单文件（返回文件名；不存在返回空串） */
  static async findBuiltin(context: common.UIAbilityContext): Promise<string> {
    try {
      const list: string[] = await context.resourceManager.getRawFileList('');
      for (const cand of BUILTIN_CANDIDATES) {
        if (list.indexOf(cand) >= 0) {
          return cand;
        }
      }
      return '';
    } catch (e) {
      Logger.error(TAG, 'getRawFileList failed: ' + (e as Error).message);
      return '';
    }
  }

  /**
   * 内置文件变化即导入：
   * 无内置文件 → undefined；内容哈希与上次一致 → undefined；
   * 有变化 → 解析合并导入，成功后记录哈希并返回结果；
   * force=true 时跳过哈希检查强制重新合并导入（恢复旧版去重逻辑丢弃的重复键行，不丢已打状态）。
   */
  static async importIfChanged(context: common.UIAbilityContext,
    force: boolean = false): Promise<ImportResult | undefined> {
    const name: string = await BuiltinListService.findBuiltin(context);
    if (name === '') {
      return undefined;
    }
    try {
      const bytes: Uint8Array = await context.resourceManager.getRawFileContent(name);
      const hash: string = MergeService.hashBytes(bytes);
      const last: string = await ConfigDao.get(Constants.CONFIG_BUILTIN_LAST_HASH);
      if (!force && hash === last) {
        return undefined;
      }
      const result: ImportResult = await ImportService.importFromBytes(bytes, name);
      if (result.success) {
        await ConfigDao.set(Constants.CONFIG_BUILTIN_LAST_HASH, hash);
      }
      return result;
    } catch (e) {
      Logger.error(TAG, 'importIfChanged failed: ' + (e as Error).message);
      const fail: ImportResult = {
        success: false,
        message: '内置名单导入失败：' + (e as Error).message,
        total: 0
      };
      return fail;
    }
  }
}
