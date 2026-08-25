import { relationalStore } from '@kit.ArkData';
import { DbHelper } from './DbHelper';
import { ConfigDao } from './ConfigDao';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';

const TAG: string = 'DataResetService';

/**
 * 数据重置服务（v0.5.1）：
 * 一键清除全部导入数据（名单行、状态、导入元信息），并重置内置名单哈希与责任人选择，
 * 清除后可通过"内置名单"按钮或重新导入恢复数据。
 */
export class DataResetService {
  static async clearAllData(): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    await DbHelper.runInTransaction(async () => {
      try {
        await store.executeSql('DELETE FROM call_status');
      } catch (e) {
        throw e as Error;
      }
      try {
        await store.executeSql('DELETE FROM call_list');
      } catch (e) {
        throw e as Error;
      }
      try {
        await store.executeSql('DELETE FROM import_meta');
      } catch (e) {
        throw e as Error;
      }
    });
    await ConfigDao.set(Constants.CONFIG_BUILTIN_LAST_HASH, '');
    await ConfigDao.set(Constants.CONFIG_LAST_ASSIGNEE, '');
    Logger.info(TAG, 'all data cleared');
  }
}
