import { CallRecord, CountResult } from '../model/CallRecord';
import { CallListDao } from '../database/CallListDao';
import { StatusDao } from '../database/StatusDao';
import { ConfigDao } from '../database/ConfigDao';
import { Constants } from '../common/Constants';

/**
 * 主列表视图模型（设计规格 2.2 / 7 节）：
 * LazyForEach 数据源（IDataSource）+ 分页加载 + 统计 + 标记。
 */
export class MainViewModel implements IDataSource {
  private records: CallRecord[] = [];
  private listeners: DataChangeListener[] = [];
  assignee: string = Constants.UNASSIGNED;
  calledFilter: number = -1; // -1 全部 / 0 未打 / 1 已打
  keyword: string = '';
  statTotal: number = 0;
  statCalled: number = 0;
  private hasMore: boolean = true;
  private offset: number = 0;
  private dataVersion: number = 0;

  /**
   * LazyForEach 键版本号：refreshList 全量替换数据时递增。
   * 真机实测（SGT-AL10）：onDataReloaded 对键相同的条目复用既有视图、不重建，
   * 导致返回子页后列表徽标/状态陈旧；将版本号并入条目键可强制全部重建。
   */
  version(): number {
    return this.dataVersion;
  }

  // ---- IDataSource ----
  totalCount(): number {
    return this.records.length;
  }

  getData(index: number): CallRecord {
    return this.records[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const i: number = this.listeners.indexOf(listener);
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }

  private notifyReload(): void {
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }

  private notifyAdd(index: number): void {
    for (const l of this.listeners) {
      l.onDataAdd(index);
    }
  }

  private notifyDelete(index: number): void {
    for (const l of this.listeners) {
      l.onDataDelete(index);
    }
  }

  private notifyChange(index: number): void {
    for (const l of this.listeners) {
      l.onDataChange(index);
    }
  }

  // ---- 数据操作 ----
  async init(): Promise<void> {
    this.assignee = await ConfigDao.getLastAssignee();
    await this.refreshList();
  }

  /** 重载当前责任人（导入/从选择页返回时调用）：
   *  若上次责任人在新数据集中已不存在，自动回退到新数据的第一个责任人（无则未分配）并持久化 */
  async reloadAssignee(): Promise<void> {
    this.assignee = await ConfigDao.getLastAssignee();
    const list: string[] = await CallListDao.getAssigneeList();
    if (this.assignee !== Constants.UNASSIGNED && list.indexOf(this.assignee) < 0) {
      let fallback: string = Constants.UNASSIGNED;
      for (const a of list) {
        if (a !== Constants.UNASSIGNED) {
          fallback = a;
          break;
        }
      }
      this.assignee = fallback;
      await ConfigDao.setLastAssignee(fallback);
    }
    await this.refreshList();
  }

  async refreshList(): Promise<void> {
    const page: CallRecord[] = await CallListDao.queryPage(
      this.assignee, this.calledFilter, this.keyword, 0, Constants.PAGE_SIZE);
    this.records = page;
    this.offset = page.length;
    this.hasMore = page.length >= Constants.PAGE_SIZE;
    this.dataVersion++;
    this.notifyReload();
  }

  async loadMore(): Promise<void> {
    if (!this.hasMore) {
      return;
    }
    const start: number = this.records.length;
    const page: CallRecord[] = await CallListDao.queryPage(
      this.assignee, this.calledFilter, this.keyword, this.offset, Constants.PAGE_SIZE);
    if (page.length === 0) {
      this.hasMore = false;
      return;
    }
    for (const r of page) {
      this.records.push(r);
    }
    this.offset += page.length;
    this.hasMore = page.length >= Constants.PAGE_SIZE;
    this.notifyAdd(start);
  }

  async setFilter(filter: number): Promise<void> {
    this.calledFilter = filter;
    await this.refreshList();
  }

  async setKeyword(keyword: string): Promise<void> {
    this.keyword = keyword;
    await this.refreshList();
  }

  async setAssignee(assignee: string): Promise<void> {
    this.assignee = assignee;
    await ConfigDao.setLastAssignee(assignee);
    await this.refreshList();
  }

  async refreshStats(): Promise<CountResult> {
    const r: CountResult = await CallListDao.countByStatus(this.assignee);
    this.statTotal = r.total;
    this.statCalled = r.called;
    return r;
  }

  /** 标记/撤销已打（FR-6）：双写事务 + 列表增量更新 */
  async toggleCalled(record: CallRecord, index: number, value: boolean): Promise<void> {
    await StatusDao.setCalled(record.id, value);
    record.called = value;
    await this.refreshStats();
    if ((this.calledFilter === 0 && value) || (this.calledFilter === 1 && !value)) {
      this.records.splice(index, 1);
      this.notifyDelete(index);
    } else {
      this.notifyChange(index);
    }
  }

  indexOf(record: CallRecord): number {
    return this.records.indexOf(record);
  }
}
