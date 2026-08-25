import { relationalStore } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from './DbHelper';

/**
 * app_config 键值配置读写（设计规格 3.1 节）。
 */
export class ConfigDao {
  static async get(key: string): Promise<string> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT value FROM app_config WHERE key = ?', [key]);
    let value: string = '';
    if (rs.goToNextRow()) {
      value = rs.getString(rs.getColumnIndex('value'));
    }
    rs.close();
    return value;
  }

  static async set(key: string, value: string): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    await store.executeSql('INSERT OR REPLACE INTO app_config(key, value) VALUES(?, ?)', [key, value]);
  }

  static async getLastAssignee(): Promise<string> {
    return await ConfigDao.get(Constants.CONFIG_LAST_ASSIGNEE);
  }

  static async setLastAssignee(assignee: string): Promise<void> {
    await ConfigDao.set(Constants.CONFIG_LAST_ASSIGNEE, assignee);
  }
}
