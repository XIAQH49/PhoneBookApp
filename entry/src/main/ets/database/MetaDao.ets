import { relationalStore } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from './DbHelper';
import { ImportMeta } from '../model/ImportMeta';
import { ColumnMapping } from '../model/ColumnMapping';
import { Logger } from '../common/Logger';

const TAG: string = 'MetaDao';

/**
 * import_meta 表读写（设计规格 3.1 节）。
 * 注意：insert / setActive 内部不开事务（导入编排由 DbHelper.runInTransaction 统一管理），
 * 仅当 setActive 需要原子切换 active 标记时内部自行开事务——调用方须保证不嵌套。
 *
 * M2-1：SDK 调用点统一 try/catch 包装（W-3 警告清零）；失败向上抛出带上下文的
 * Error，由服务边界统一捕获，运行期语义不变。
 */
export class MetaDao {
  /** 纯插入（事务由调用方管理） */
  static async insert(meta: ImportMeta): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const vb: relationalStore.ValuesBucket = {
      'file_name': meta.fileName,
      'file_format': meta.fileFormat,
      'file_encoding': meta.fileEncoding,
      'column_mapping': JSON.stringify(meta.columnMapping),
      'all_columns': JSON.stringify(meta.allColumns),
      'called_value_format': meta.calledValueFormat,
      'connected_value_format': meta.connectedValueFormat,
      'intention_value_format': meta.intentionValueFormat,
      'active': meta.active ? 1 : 0,
      'imported_at': meta.importedAt
    };
    try {
      return await store.insert(Constants.TABLE_IMPORT_META, vb);
    } catch (e) {
      Logger.error(TAG, 'insert failed: ' + (e as Error).message);
      throw new Error('insert failed: ' + (e as Error).message);
    }
  }

  /** 仅将指定批次置为生效（自带事务；供独立调用场景使用，勿在外部事务内调用） */
  static async setActive(metaId: number): Promise<void> {
    await DbHelper.runInTransaction(async () => {
      await MetaDao.clearActivePlain();
      await MetaDao.setActivePlain(metaId);
    });
  }

  /** 全部批次置为非生效；纯操作（事务由调用方管理） */
  static async clearActivePlain(): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const vb: relationalStore.ValuesBucket = { 'active': 0 };
    try {
      await store.update(vb, new relationalStore.RdbPredicates(Constants.TABLE_IMPORT_META));
    } catch (e) {
      Logger.error(TAG, 'clearActivePlain failed: ' + (e as Error).message);
      throw new Error('clearActivePlain failed: ' + (e as Error).message);
    }
  }

  /** 指定批次置为生效；纯操作（事务由调用方管理） */
  static async setActivePlain(metaId: number): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const vb: relationalStore.ValuesBucket = { 'active': 1 };
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_IMPORT_META);
    pred.equalTo('id', metaId);
    try {
      await store.update(vb, pred);
    } catch (e) {
      Logger.error(TAG, 'setActivePlain failed: ' + (e as Error).message);
      throw new Error('setActivePlain failed: ' + (e as Error).message);
    }
  }

  static async getActive(): Promise<ImportMeta | undefined> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.querySql(
        'SELECT * FROM import_meta WHERE active = 1 LIMIT 1', []);
      let meta: ImportMeta | undefined = undefined;
      if (rs.goToNextRow()) {
        meta = MetaDao.rowToMeta(rs);
      }
      return meta;
    } catch (e) {
      Logger.error(TAG, 'getActive failed: ' + (e as Error).message);
      throw new Error('getActive failed: ' + (e as Error).message);
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

  static async getById(id: number): Promise<ImportMeta | undefined> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.querySql(
        'SELECT * FROM import_meta WHERE id = ?', [id]);
      let meta: ImportMeta | undefined = undefined;
      if (rs.goToNextRow()) {
        meta = MetaDao.rowToMeta(rs);
      }
      return meta;
    } catch (e) {
      Logger.error(TAG, 'getById failed: ' + (e as Error).message);
      throw new Error('getById failed: ' + (e as Error).message);
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

  static rowToMeta(rs: relationalStore.ResultSet): ImportMeta {
    try {
      const meta: ImportMeta = new ImportMeta();
      meta.id = rs.getLong(rs.getColumnIndex('id'));
      meta.fileName = rs.getString(rs.getColumnIndex('file_name'));
      meta.fileFormat = rs.getString(rs.getColumnIndex('file_format'));
      meta.fileEncoding = rs.getString(rs.getColumnIndex('file_encoding'));
      const mappingRaw: string = rs.getString(rs.getColumnIndex('column_mapping'));
      try {
        meta.columnMapping = JSON.parse(mappingRaw) as Record<string, string>;
      } catch (e) {
        meta.columnMapping = new ColumnMapping().toRecord();
      }
      const columnsRaw: string = rs.getString(rs.getColumnIndex('all_columns'));
      try {
        meta.allColumns = JSON.parse(columnsRaw) as string[];
      } catch (e) {
        meta.allColumns = [];
      }
      meta.calledValueFormat = rs.getString(rs.getColumnIndex('called_value_format'));
      meta.connectedValueFormat = rs.getString(rs.getColumnIndex('connected_value_format'));
      meta.intentionValueFormat = rs.getString(rs.getColumnIndex('intention_value_format'));
      meta.active = rs.getLong(rs.getColumnIndex('active')) === 1;
      meta.importedAt = rs.getLong(rs.getColumnIndex('imported_at'));
      return meta;
    } catch (e) {
      Logger.error(TAG, 'rowToMeta failed: ' + (e as Error).message);
      throw new Error('rowToMeta failed: ' + (e as Error).message);
    }
  }
}
