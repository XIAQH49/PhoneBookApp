import { relationalStore } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from './DbHelper';
import { Logger } from '../common/Logger';

const TAG: string = 'ConfigDao';

/**
 * app_config 键值配置读写（设计规格 3.1 节）。
 *
 * M2-1：SDK 调用点统一 try/catch 包装（W-3 警告清零）；失败向上抛出带上下文的
 * Error，由服务边界统一捕获，运行期语义不变。
 */
export class ConfigDao {
  static async get(key: string): Promise<string> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.querySql(
        'SELECT value FROM app_config WHERE key = ?', [key]);
      let value: string = '';
      if (rs.goToNextRow()) {
        value = rs.getString(rs.getColumnIndex('value'));
      }
      return value;
    } catch (e) {
      Logger.error(TAG, 'get failed: ' + (e as Error).message);
      throw new Error('get failed: ' + (e as Error).message);
    } finally {
      if (rs !== undefined) {
        try {
          rs.close();
        } catch (e) {
          // 关闭失败忽略：不影响查询结果
        }
      }
    }
  }

  static async set(key: string, value: string): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    try {
      await store.executeSql('INSERT OR REPLACE INTO app_config(key, value) VALUES(?, ?)', [key, value]);
    } catch (e) {
      Logger.error(TAG, 'set failed: ' + (e as Error).message);
      throw new Error('set failed: ' + (e as Error).message);
    }
  }

  static async getLastAssignee(): Promise<string> {
    return await ConfigDao.get(Constants.CONFIG_LAST_ASSIGNEE);
  }

  static async setLastAssignee(assignee: string): Promise<void> {
    await ConfigDao.set(Constants.CONFIG_LAST_ASSIGNEE, assignee);
  }
}
