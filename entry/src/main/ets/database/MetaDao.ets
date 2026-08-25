import { relationalStore } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from './DbHelper';
import { ImportMeta } from '../model/ImportMeta';
import { ColumnMapping } from '../model/ColumnMapping';

/**
 * import_meta 表读写（设计规格 3.1 节）。
 * 注意：insert / setActive 内部不开事务（导入编排由 DbHelper.runInTransaction 统一管理），
 * 仅当 setActive 需要原子切换 active 标记时内部自行开事务——调用方须保证不嵌套。
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
      'active': meta.active ? 1 : 0,
      'imported_at': meta.importedAt
    };
    return await store.insert(Constants.TABLE_IMPORT_META, vb);
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
    await store.update(vb, new relationalStore.RdbPredicates(Constants.TABLE_IMPORT_META));
  }

  /** 指定批次置为生效；纯操作（事务由调用方管理） */
  static async setActivePlain(metaId: number): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const vb: relationalStore.ValuesBucket = { 'active': 1 };
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_IMPORT_META);
    pred.equalTo('id', metaId);
    await store.update(vb, pred);
  }

  static async getActive(): Promise<ImportMeta | undefined> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT * FROM import_meta WHERE active = 1 LIMIT 1', []);
    let meta: ImportMeta | undefined = undefined;
    if (rs.goToNextRow()) {
      meta = MetaDao.rowToMeta(rs);
    }
    rs.close();
    return meta;
  }

  static async getById(id: number): Promise<ImportMeta | undefined> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT * FROM import_meta WHERE id = ?', [id]);
    let meta: ImportMeta | undefined = undefined;
    if (rs.goToNextRow()) {
      meta = MetaDao.rowToMeta(rs);
    }
    rs.close();
    return meta;
  }

  static rowToMeta(rs: relationalStore.ResultSet): ImportMeta {
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
    meta.active = rs.getLong(rs.getColumnIndex('active')) === 1;
    meta.importedAt = rs.getLong(rs.getColumnIndex('imported_at'));
    return meta;
  }
}
