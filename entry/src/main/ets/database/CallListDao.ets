import { relationalStore } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from './DbHelper';
import { CallRecord, CountResult } from '../model/CallRecord';
import { MergeRowData } from '../service/MergeService';

/** 合并用的本地行快照（含已打状态，供 MergeService.computePlan 决策） */
export interface KeyRow {
  id: number;
  rowKey: string;
  called: boolean;
}

/**
 * call_list 表读写（设计规格 3.1 / 4.2 节）。
 * 纯操作不带事务；复合事务由服务层通过 DbHelper.runInTransaction 编排。
 */
export class CallListDao {
  /** 纯插入单行（事务由调用方管理），返回 rowId */
  static async insertPlain(record: CallRecord): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    return await store.insert(Constants.TABLE_CALL_LIST, CallListDao.toBucket(record));
  }

  /** 批量插入（自带事务；仅用于独立批量场景，勿在外部事务内调用） */
  static async insertBatch(records: CallRecord[]): Promise<void> {
    await DbHelper.runInTransaction(async () => {
      for (const r of records) {
        await CallListDao.insertPlain(r);
      }
    });
  }

  /** 合并更新：字段以新文件为准，called 取"或"结果；纯操作 */
  static async updateFromFile(rowId: number, data: MergeRowData, calledMerged: boolean): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const vb: relationalStore.ValuesBucket = {
      'row_no': data.rowNo,
      'row_key': data.rowKey,
      'assignee': data.assignee,
      'name': data.name,
      'emp_no': data.empNo,
      'phone_raw': data.phoneRaw,
      'phone_numbers': JSON.stringify(data.phoneNumbers),
      'called': calledMerged ? 1 : 0,
      'raw_data': JSON.stringify(data.rawData),
      'in_file': 1,
      'updated_at': Date.now()
    };
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_LIST);
    pred.equalTo('id', rowId);
    await store.update(vb, pred);
  }

  /** 标记"新文件中已消失"的行（保留数据，in_file=0）；纯操作 */
  static async markRemoved(ids: number[]): Promise<void> {
    if (ids.length === 0) {
      return;
    }
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const vb: relationalStore.ValuesBucket = { 'in_file': 0, 'updated_at': Date.now() };
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_LIST);
    pred.in('id', ids);
    await store.update(vb, pred);
  }

  /** 已打缓存列同步（与 call_status 双写，设计 3.2 节）；纯操作 */
  static async setCalledCache(rowId: number, value: number): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const vb: relationalStore.ValuesBucket = { 'called': value, 'updated_at': Date.now() };
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_LIST);
    pred.equalTo('id', rowId);
    await store.update(vb, pred);
  }

  /** 分页查询：assignee 过滤 + 状态过滤 + 关键字搜索（FR-4） */
  static async queryPage(assignee: string, calledFilter: number, keyword: string,
    offset: number, limit: number): Promise<CallRecord[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_LIST);
    pred.equalTo('assignee', assignee).and().equalTo('in_file', 1);
    if (calledFilter === 0 || calledFilter === 1) {
      pred.and().equalTo('called', calledFilter);
    }
    const kw: string = keyword.trim();
    if (kw !== '') {
      const like: string = `%${kw}%`;
      pred.and().beginWrap()
        .like('name', like)
        .or().like('emp_no', like)
        .or().like('phone_raw', like)
        .endWrap();
    }
    pred.orderByAsc('row_no').limitAs(limit).offsetAs(offset);
    const rs: relationalStore.ResultSet = await store.query(pred);
    const list: CallRecord[] = [];
    while (rs.goToNextRow()) {
      list.push(CallListDao.rowToRecord(rs));
    }
    rs.close();
    return list;
  }

  /** 进度统计（FR-4）：总数与已打数 */
  static async countByStatus(assignee: string): Promise<CountResult> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT called, COUNT(*) AS cnt FROM call_list WHERE assignee = ? AND in_file = 1 GROUP BY called',
      [assignee]);
    const result: CountResult = { total: 0, called: 0 };
    while (rs.goToNextRow()) {
      const called: number = rs.getLong(rs.getColumnIndex('called'));
      const cnt: number = rs.getLong(rs.getColumnIndex('cnt'));
      if (called === 1) {
        result.called = cnt;
      }
      result.total += cnt;
    }
    rs.close();
    return result;
  }

  /** 全量进度统计（全部责任人，FR-4 总计行） */
  static async countAllByStatus(): Promise<CountResult> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT called, COUNT(*) AS cnt FROM call_list WHERE in_file = 1 GROUP BY called', []);
    const result: CountResult = { total: 0, called: 0 };
    while (rs.goToNextRow()) {
      const called: number = rs.getLong(rs.getColumnIndex('called'));
      const cnt: number = rs.getLong(rs.getColumnIndex('cnt'));
      if (called === 1) {
        result.called = cnt;
      }
      result.total += cnt;
    }
    rs.close();
    return result;
  }

  /** 责任人去重列表（FR-3） */
  static async getAssigneeList(): Promise<string[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT DISTINCT assignee FROM call_list WHERE in_file = 1 ORDER BY assignee ASC', []);
    const list: string[] = [];
    while (rs.goToNextRow()) {
      list.push(rs.getString(rs.getColumnIndex('assignee')));
    }
    rs.close();
    return list;
  }

  /** 当前生效数据集的键快照（合并决策输入，含已打状态） */
  static async getActiveKeyRows(): Promise<KeyRow[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT id, row_key, called FROM call_list WHERE in_file = 1', []);
    const list: KeyRow[] = [];
    while (rs.goToNextRow()) {
      const item: KeyRow = {
        id: rs.getLong(rs.getColumnIndex('id')),
        rowKey: rs.getString(rs.getColumnIndex('row_key')),
        called: rs.getLong(rs.getColumnIndex('called')) === 1
      };
      list.push(item);
    }
    rs.close();
    return list;
  }

  static async getById(id: number): Promise<CallRecord | undefined> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_LIST);
    pred.equalTo('id', id);
    const rs: relationalStore.ResultSet = await store.query(pred);
    let record: CallRecord | undefined = undefined;
    if (rs.goToNextRow()) {
      record = CallListDao.rowToRecord(rs);
    }
    rs.close();
    return record;
  }

  /** 导出查询（FR-7）：生效行，范围=当前责任人+未分配 或 全表，按行序排序 */
  static async queryExportRows(assignee: string, all: boolean): Promise<CallRecord[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_LIST);
    pred.equalTo('in_file', 1);
    if (!all) {
      pred.and().beginWrap()
        .equalTo('assignee', assignee)
        .or().equalTo('assignee', Constants.UNASSIGNED)
        .endWrap();
    }
    pred.orderByAsc('row_no');
    const rs: relationalStore.ResultSet = await store.query(pred);
    const list: CallRecord[] = [];
    while (rs.goToNextRow()) {
      list.push(CallListDao.rowToRecord(rs));
    }
    rs.close();
    return list;
  }

  /** 全部生效行数量（设置页数据信息展示） */
  static async countAllActive(): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const rs: relationalStore.ResultSet = await store.querySql(
      'SELECT COUNT(*) AS cnt FROM call_list WHERE in_file = 1', []);
    let cnt: number = 0;
    if (rs.goToNextRow()) {
      cnt = rs.getLong(rs.getColumnIndex('cnt'));
    }
    rs.close();
    return cnt;
  }

  static rowToRecord(rs: relationalStore.ResultSet): CallRecord {
    const record: CallRecord = new CallRecord();
    record.id = rs.getLong(rs.getColumnIndex('id'));
    record.metaId = rs.getLong(rs.getColumnIndex('meta_id'));
    record.rowNo = rs.getLong(rs.getColumnIndex('row_no'));
    record.rowKey = rs.getString(rs.getColumnIndex('row_key'));
    record.assignee = rs.getString(rs.getColumnIndex('assignee'));
    record.name = rs.getString(rs.getColumnIndex('name'));
    record.empNo = rs.getString(rs.getColumnIndex('emp_no'));
    record.phoneRaw = rs.getString(rs.getColumnIndex('phone_raw'));
    try {
      record.phoneNumbers = JSON.parse(rs.getString(rs.getColumnIndex('phone_numbers'))) as string[];
    } catch (e) {
      record.phoneNumbers = [];
    }
    record.called = rs.getLong(rs.getColumnIndex('called')) === 1;
    try {
      record.rawData = JSON.parse(rs.getString(rs.getColumnIndex('raw_data'))) as Record<string, string>;
    } catch (e) {
      record.rawData = {};
    }
    record.inFile = rs.getLong(rs.getColumnIndex('in_file')) === 1;
    record.createdAt = rs.getLong(rs.getColumnIndex('created_at'));
    record.updatedAt = rs.getLong(rs.getColumnIndex('updated_at'));
    return record;
  }

  private static toBucket(record: CallRecord): relationalStore.ValuesBucket {
    const now: number = Date.now();
    return {
      'meta_id': record.metaId,
      'row_no': record.rowNo,
      'row_key': record.rowKey,
      'assignee': record.assignee,
      'name': record.name,
      'emp_no': record.empNo,
      'phone_raw': record.phoneRaw,
      'phone_numbers': JSON.stringify(record.phoneNumbers),
      'called': record.called ? 1 : 0,
      'raw_data': JSON.stringify(record.rawData),
      'in_file': record.inFile ? 1 : 0,
      'created_at': now,
      'updated_at': now
    };
  }
}
