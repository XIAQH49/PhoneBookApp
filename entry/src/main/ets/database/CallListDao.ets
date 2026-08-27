import { relationalStore } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from './DbHelper';
import { CallRecord, CountResult } from '../model/CallRecord';
import { MergeRowData } from '../service/MergeService';
import { Logger } from '../common/Logger';

/** 合并用的本地行快照（含三状态，供 MergeService.computePlan 决策） */
export interface KeyRow {
  id: number;
  rowKey: string;
  called: boolean;
  /** M3：本机是否打通 */
  connected: boolean;
  /** M3：本机是否有意向 */
  intention: boolean;
}

const TAG: string = 'CallListDao';

/**
 * call_list 表读写（设计规格 3.1 / 4.2 节）。
 * 纯操作不带事务；复合事务由服务层通过 DbHelper.runInTransaction 编排。
 *
 * M2-1：SDK 调用点统一 try/catch 包装（W-3 警告清零）；失败向上抛出带上下文的
 * Error，由服务边界（ImportService/ExportService 等）统一捕获，运行期语义不变。
 */
export class CallListDao {
  /** 纯插入单行（事务由调用方管理），返回 rowId */
  static async insertPlain(record: CallRecord): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    try {
      return await store.insert(Constants.TABLE_CALL_LIST, CallListDao.toBucket(record));
    } catch (e) {
      Logger.error(TAG, 'insertPlain failed: ' + (e as Error).message);
      throw new Error('insertPlain failed: ' + (e as Error).message);
    }
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
    try {
      await store.update(vb, pred);
    } catch (e) {
      Logger.error(TAG, 'updateFromFile failed: ' + (e as Error).message);
      throw new Error('updateFromFile failed: ' + (e as Error).message);
    }
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
    try {
      await store.update(vb, pred);
    } catch (e) {
      Logger.error(TAG, 'markRemoved failed: ' + (e as Error).message);
      throw new Error('markRemoved failed: ' + (e as Error).message);
    }
  }

  /** 已打缓存列同步（与 call_status 双写，设计 3.2 节）；纯操作 */
  static async setCalledCache(rowId: number, value: number): Promise<void> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const vb: relationalStore.ValuesBucket = { 'called': value, 'updated_at': Date.now() };
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_LIST);
    pred.equalTo('id', rowId);
    try {
      await store.update(vb, pred);
    } catch (e) {
      Logger.error(TAG, 'setCalledCache failed: ' + (e as Error).message);
      throw new Error('setCalledCache failed: ' + (e as Error).message);
    }
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
      const like: string = '%' + kw + '%';
      pred.and().beginWrap()
        .like('name', like)
        .or().like('emp_no', like)
        .or().like('phone_raw', like)
        .endWrap();
    }
    pred.orderByAsc('row_no').limitAs(limit).offsetAs(offset);
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.query(pred);
      const list: CallRecord[] = [];
      while (rs.goToNextRow()) {
        list.push(CallListDao.rowToRecord(rs));
      }
      return list;
    } catch (e) {
      Logger.error(TAG, 'queryPage failed: ' + (e as Error).message);
      throw new Error('queryPage failed: ' + (e as Error).message);
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

  /** 进度统计（FR-4）：总数与已打数 */
  static async countByStatus(assignee: string): Promise<CountResult> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.querySql(
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
      return result;
    } catch (e) {
      Logger.error(TAG, 'countByStatus failed: ' + (e as Error).message);
      throw new Error('countByStatus failed: ' + (e as Error).message);
    } finally {
      if (rs !== undefined) {
        try {
          rs.close();
        } catch (e) {
          // 关闭失败忽略：不影响统计结果
        }
      }
    }
  }

  /** 全量进度统计（全部责任人，FR-4 总计行） */
  static async countAllByStatus(): Promise<CountResult> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.querySql(
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
      return result;
    } catch (e) {
      Logger.error(TAG, 'countAllByStatus failed: ' + (e as Error).message);
      throw new Error('countAllByStatus failed: ' + (e as Error).message);
    } finally {
      if (rs !== undefined) {
        try {
          rs.close();
        } catch (e) {
          // 关闭失败忽略：不影响统计结果
        }
      }
    }
  }

  /** 责任人去重列表（FR-3） */
  static async getAssigneeList(): Promise<string[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.querySql(
        'SELECT DISTINCT assignee FROM call_list WHERE in_file = 1 ORDER BY assignee ASC', []);
      const list: string[] = [];
      while (rs.goToNextRow()) {
        list.push(rs.getString(rs.getColumnIndex('assignee')));
      }
      return list;
    } catch (e) {
      Logger.error(TAG, 'getAssigneeList failed: ' + (e as Error).message);
      throw new Error('getAssigneeList failed: ' + (e as Error).message);
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

  /** 合并决策键快照（含三状态）。
   *  按 id 升序保证同键多行时队列匹配顺序稳定（v0.5.3 加固）；
   *  M3：LEFT JOIN call_status 一次取回 connected/intention（UNIQUE(row_id,status_key) 保证至多一行）。
   *  v0.5.4：不过滤 in_file——"文件中已移除"（in_file=0）的行在新文件中重现时按同键匹配复活
   *  （updateFromFile 置回 in_file=1，本机状态取"或"保留），避免重插丢失本机标记。 */
  static async getActiveKeyRows(): Promise<KeyRow[]> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.querySql(
        'SELECT l.id AS id, l.row_key AS row_key, l.called AS called, ' +
        "COALESCE(MAX(CASE WHEN s.status_key = 'connected' THEN s.value END), 0) AS connected, " +
        "COALESCE(MAX(CASE WHEN s.status_key = 'intention' THEN s.value END), 0) AS intention " +
        'FROM call_list l ' +
        "LEFT JOIN call_status s ON s.row_id = l.id AND s.status_key IN ('connected', 'intention') " +
        'GROUP BY l.id, l.row_key, l.called ORDER BY l.id ASC', []);
      const list: KeyRow[] = [];
      while (rs.goToNextRow()) {
        const item: KeyRow = {
          id: rs.getLong(rs.getColumnIndex('id')),
          rowKey: rs.getString(rs.getColumnIndex('row_key')),
          called: rs.getLong(rs.getColumnIndex('called')) === 1,
          connected: rs.getLong(rs.getColumnIndex('connected')) === 1,
          intention: rs.getLong(rs.getColumnIndex('intention')) === 1
        };
        list.push(item);
      }
      return list;
    } catch (e) {
      Logger.error(TAG, 'getActiveKeyRows failed: ' + (e as Error).message);
      throw new Error('getActiveKeyRows failed: ' + (e as Error).message);
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

  static async getById(id: number): Promise<CallRecord | undefined> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    const pred: relationalStore.RdbPredicates =
      new relationalStore.RdbPredicates(Constants.TABLE_CALL_LIST);
    pred.equalTo('id', id);
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.query(pred);
      let record: CallRecord | undefined = undefined;
      if (rs.goToNextRow()) {
        record = CallListDao.rowToRecord(rs);
      }
      return record;
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
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.query(pred);
      const list: CallRecord[] = [];
      while (rs.goToNextRow()) {
        list.push(CallListDao.rowToRecord(rs));
      }
      return list;
    } catch (e) {
      Logger.error(TAG, 'queryExportRows failed: ' + (e as Error).message);
      throw new Error('queryExportRows failed: ' + (e as Error).message);
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

  /** 全部生效行数量（设置页数据信息展示） */
  static async countAllActive(): Promise<number> {
    const store: relationalStore.RdbStore = DbHelper.getStore();
    let rs: relationalStore.ResultSet | undefined = undefined;
    try {
      rs = await store.querySql(
        'SELECT COUNT(*) AS cnt FROM call_list WHERE in_file = 1', []);
      let cnt: number = 0;
      if (rs.goToNextRow()) {
        cnt = rs.getLong(rs.getColumnIndex('cnt'));
      }
      return cnt;
    } catch (e) {
      Logger.error(TAG, 'countAllActive failed: ' + (e as Error).message);
      throw new Error('countAllActive failed: ' + (e as Error).message);
    } finally {
      if (rs !== undefined) {
        try {
          rs.close();
        } catch (e) {
          // 关闭失败忽略：不影响统计结果
        }
      }
    }
  }

  static rowToRecord(rs: relationalStore.ResultSet): CallRecord {
    try {
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
    } catch (e) {
      Logger.error(TAG, 'rowToRecord failed: ' + (e as Error).message);
      throw new Error('rowToRecord failed: ' + (e as Error).message);
    }
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
