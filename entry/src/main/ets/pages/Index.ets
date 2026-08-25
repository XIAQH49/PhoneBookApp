import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { MainViewModel } from '../viewmodel/MainViewModel';
import { CallRecord, CountResult } from '../model/CallRecord';
import { Constants } from '../common/Constants';
import { ContextUtil } from '../common/ContextUtil';
import { ImportService } from '../service/ImportService';
import type { ImportResult, ProgressInfo } from '../service/ImportService';
import { BuiltinListService } from '../service/BuiltinListService';
import { ExportService } from '../service/ExportService';
import type { ExportResult } from '../service/ExportService';
import { CallService } from '../service/CallService';
import { ConfigDao } from '../database/ConfigDao';
import { DbHelper } from '../database/DbHelper';
import { CallListDao } from '../database/CallListDao';
import { StatBar } from '../components/StatBar';
import { FilterChips } from '../components/FilterChips';
import { EmptyView } from '../components/EmptyView';
import { NumberSheet } from '../components/NumberSheet';
import { CallConfirmDialog } from '../components/CallConfirmDialog';

const FILTER_ALL: number = -1;
const FILTER_UNCALLED: number = 0;
const FILTER_CALLED: number = 1;

/**
 * 主列表页（FR-3 / FR-4 / FR-6）：统计、搜索、筛选、分页列表、
 * 一键标记已打、导入/导出入口、唤起拨号。
 */
@Entry
@Component
struct Index {
  vm: MainViewModel = new MainViewModel();
  @State assigneeName: string = '';
  @State statTotal: number = 0;
  @State statCalled: number = 0;
  @State hasData: boolean = false;
  @State showSwitchHint: boolean = false;
  @State searchText: string = '';
  @State filterIdx: number = 0;
  @State importing: boolean = false;
  @State importStage: string = '';
  @State exporting: boolean = false;
  @State showNumberSheet: boolean = false;
  @State sheetNumbers: string[] = [];
  @State sheetName: string = '';
  private sheetRecord: CallRecord = new CallRecord();
  private confirmName: string = '';
  private confirmNumber: string = '';
  private pendingMark: CallRecord | undefined = undefined;
  private needReload: boolean = false;
  private searchTimer: number = -1;
  private confirmController: CustomDialogController | undefined = undefined;
  private initRetry: number = 0;
  private builtinChecked: boolean = false;

  aboutToAppear(): void {
    this.initPage();
  }

  onPageShow(): void {
    if (this.needReload) {
      this.needReload = false;
      this.vm.reloadAssignee().then(() => {
        this.syncAll();
      });
    } else if (DbHelper.isReady()) {
      // 实时刷新兜底：冷启动时异步数据到达/返回前台后，静默刷新统计与列表状态
      this.vm.refreshStats().then((r: CountResult): void => {
        this.statTotal = r.total;
        this.statCalled = r.called;
        this.hasData = this.vm.totalCount() > 0;
      });
      if (this.vm.totalCount() === 0) {
        this.vm.refreshList().then(() => {
          this.syncAll();
        });
      }
    }
    if (this.pendingMark !== undefined) {
      this.showMarkPrompt();
    }
  }

  async initPage(): Promise<void> {
    try {
      // 等待数据库就绪（冷启动 EntryAbility 异步初始化可能尚未完成，避免瞬时失败）
      await DbHelper.ready();
      await this.vm.init();
      await this.syncAll();
      // v0.5：内置名单变化检测（每次启动仅一次，内容哈希变化才导入，已打状态保留）
      if (!this.builtinChecked) {
        this.builtinChecked = true;
        this.checkBuiltin();
      }
    } catch (e) {
      this.initRetry++;
      if (this.initRetry <= 3) {
        // 延迟重试，覆盖冷启动竞态
        setTimeout(() => {
          this.initPage();
        }, 500);
      }
    }
  }

  /** 内置名单自动检测/手动导入共用 */
  async checkBuiltin(manual: boolean = false): Promise<void> {
    const ctx: common.UIAbilityContext | undefined = ContextUtil.getAbilityContext(this.getUIContext());
    if (ctx === undefined) {
      if (manual) {
        this.uiToast('无法获取应用上下文');
      }
      return;
    }
    if (manual) {
      const name: string = await BuiltinListService.findBuiltin(ctx);
      if (name === '') {
        this.uiToast('未找到内置名单：请将文件命名为 名单.xlsx（或 名单.csv）放入 rawfile 目录后重新构建安装');
        return;
      }
    }
    const r: ImportResult | undefined = await BuiltinListService.importIfChanged(ctx);
    if (r === undefined) {
      if (manual) {
        this.uiToast('内置名单无变化，无需导入');
      }
      return;
    }
    if (r.success) {
      this.uiToast(manual ? '已导入内置名单' : '内置名单已更新并导入');
      await this.vm.reloadAssignee();
      await this.syncAll();
    } else {
      this.uiToast(r.message);
    }
  }

  async syncAll(): Promise<void> {
    this.assigneeName = this.vm.assignee;
    const r: CountResult = await this.vm.refreshStats();
    this.statTotal = r.total;
    this.statCalled = r.called;
    this.hasData = this.vm.totalCount() > 0;
    if (!this.hasData) {
      // 区分"尚未导入"与"当前责任人无数据"两种空态
      const all: number = await CallListDao.countAllActive();
      this.showSwitchHint = all > 0;
    } else {
      this.showSwitchHint = false;
    }
  }

  // ---- 筛选与搜索 ----
  onFilterChange(idx: number): void {
    this.filterIdx = idx;
    const f: number = idx === 0 ? FILTER_ALL : (idx === 1 ? FILTER_UNCALLED : FILTER_CALLED);
    this.vm.setFilter(f).then(() => {
      this.syncAll();
    });
  }

  onSearchChange(v: string): void {
    this.searchText = v;
    if (this.searchTimer >= 0) {
      clearTimeout(this.searchTimer);
    }
    this.searchTimer = setTimeout(() => {
      this.vm.setKeyword(v).then(() => {
        this.syncAll();
      });
    }, 300);
  }

  // ---- 标记 ----
  async onToggle(record: CallRecord, index: number, value: boolean): Promise<void> {
    await this.vm.toggleCalled(record, index, value);
    await this.syncAll();
  }

  // ---- 拨号（FR-5）----
  async onCall(record: CallRecord): Promise<void> {
    if (record.phoneNumbers.length === 0) {
      this.uiToast('未识别到有效号码，可长按复制原文');
      return;
    }
    if (record.phoneNumbers.length === 1) {
      await this.startCall(record, record.phoneNumbers[0]);
      return;
    }
    this.sheetRecord = record;
    this.sheetNumbers = record.phoneNumbers.slice();
    this.sheetName = record.name;
    this.showNumberSheet = true;
  }

  onNumberPicked(index: number): void {
    this.showNumberSheet = false;
    const num: string = this.sheetNumbers[index];
    this.startCall(this.sheetRecord, num);
  }

  async startCall(record: CallRecord, number: string): Promise<void> {
    const flag: string = await ConfigDao.get(Constants.CONFIG_CONFIRM_BEFORE_CALL);
    if (flag === '0') {
      await this.doCall(record, number);
      return;
    }
    this.confirmName = record.name !== '' ? record.name : '该联系人';
    this.confirmNumber = number;
    this.confirmController = new CustomDialogController({
      builder: CallConfirmDialog({
        name: this.confirmName,
        number: this.confirmNumber,
        onConfirm: (): void => {
          this.doCall(record, number);
        }
      }),
      autoCancel: true
    });
    this.confirmController.open();
  }

  async doCall(record: CallRecord, number: string): Promise<void> {
    const ctx: common.UIAbilityContext | undefined = ContextUtil.getAbilityContext(this.getUIContext());
    if (ctx === undefined) {
      this.uiToast('无法获取应用上下文');
      return;
    }
    const result = await CallService.openDialer(ctx, number);
    if (result.success) {
      // 唤起系统拨号即算已打（R-7）：返回 APP 时提示标记
      this.pendingMark = record;
    } else {
      this.uiToast(result.message);
    }
  }

  async showMarkPrompt(): Promise<void> {
    const record: CallRecord = this.pendingMark as CallRecord;
    this.pendingMark = undefined;
    let idxResult: number = -1;
    try {
      const res = await this.getUIContext().getPromptAction().showDialog({
        title: '是否已拨打？',
        message: record.name + ' · ' + record.phoneRaw,
        buttons: [
          { text: '标记已打', color: '#007DFF' },
          { text: '暂不标记', color: '#666666' }
        ]
      });
      idxResult = res.index;
    } catch (e) {
      idxResult = -1;
    }
    if (idxResult === 0) {
      const idx: number = this.vm.indexOf(record);
      if (idx >= 0) {
        this.onToggle(record, idx, true);
      }
    }
  }

  private uiToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (e) {
      // 提示失败忽略
    }
  }

  // ---- 导入 / 导出 ----
  async onImport(): Promise<void> {
    if (this.importing) {
      return;
    }
    this.importing = true;
    this.importStage = '准备';
    const ctx: common.UIAbilityContext | undefined = ContextUtil.getAbilityContext(this.getUIContext());
    if (ctx === undefined) {
      this.importing = false;
      this.uiToast('无法获取应用上下文');
      return;
    }
    const result: ImportResult = await ImportService.pickAndImport(ctx, (p: ProgressInfo): void => {
      this.importStage = p.stage;
    });
    this.importing = false;
    this.uiToast(result.message);
    if (result.success) {
      await this.vm.reloadAssignee();
      await this.syncAll();
    }
  }

  async onExport(): Promise<void> {
    if (this.exporting) {
      return;
    }
    this.exporting = true;
    const ctx: common.UIAbilityContext | undefined = ContextUtil.getAbilityContext(this.getUIContext());
    if (ctx === undefined) {
      this.exporting = false;
      this.uiToast('无法获取应用上下文');
      return;
    }
    const scopeRaw: string = await ConfigDao.get(Constants.CONFIG_EXPORT_SCOPE);
    const scope: string = scopeRaw === '' ? Constants.EXPORT_SCOPE_MINE : scopeRaw;
    const result: ExportResult = await ExportService.exportCsv(ctx, scope);
    this.exporting = false;
    this.uiToast(result.message);
  }

  // ---- 导航 ----
  goAssigneePicker(): void {
    this.needReload = true;
    router.pushUrl({ url: 'pages/AssigneePicker' });
  }

  goSettings(): void {
    this.needReload = true;
    router.pushUrl({ url: 'pages/Settings' });
  }

  goDetail(record: CallRecord): void {
    this.needReload = true;
    const opt: router.RouterOptions = { url: 'pages/ContactDetail', params: { 'id': record.id } };
    router.pushUrl(opt);
  }

  // ---- UI ----
  @Builder
  numberSheetContent() {
    NumberSheet({
      numbers: $sheetNumbers,
      name: this.sheetName,
      onPick: (i: number): void => {
        this.onNumberPicked(i);
      },
      onCopy: (i: number): void => {
        CallService.copyToClipboard(this.sheetNumbers[i]).then(() => {
          this.uiToast('号码已复制');
        });
      }
    })
  }

  @Builder
  listItem(record: CallRecord, index: number) {
    Row() {
      Checkbox()
        .select(record.called)
        .onChange((v: boolean) => {
          this.onToggle(record, index, v);
        })
      Column() {
        Text(record.name !== '' ? record.name : '（无姓名）')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
        Text(record.empNo !== '' ? `工号 ${record.empNo}` : '')
          .fontSize(12)
          .fontColor('#999999')
        Text(record.phoneNumbers.length > 1 ? `手机 ×${record.phoneNumbers.length}` : record.phoneRaw)
          .fontSize(12)
          .fontColor('#666666')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => {
        this.goDetail(record);
      })
      Text(record.called ? '✓ 已打' : '● 未打')
        .fontSize(12)
        .fontColor(record.called ? '#007DFF' : '#E84026')
        .margin({ right: 8 })
        .onClick(() => {
          this.onToggle(record, index, !record.called);
        })
      Button('📞')
        .fontSize(18)
        .backgroundColor('#00000000')
        .onClick(() => {
          this.onCall(record);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('外呼名单')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(this.assigneeName === '' ? '未分配 ▾' : this.assigneeName + ' ▾')
          .fontSize(14)
          .fontColor('#007DFF')
          .onClick(() => {
            this.goAssigneePicker();
          })
        Text(' ⚙')
          .fontSize(16)
          .margin({ left: 12 })
          .onClick(() => {
            this.goSettings();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 4 })

      StatBar({ total: this.statTotal, called: this.statCalled })

      TextInput({ placeholder: $r('app.string.search_hint'), text: this.searchText })
        .height(40)
        .margin({ left: 16, right: 16, top: 4, bottom: 4 })
        .onChange((v: string) => {
          this.onSearchChange(v);
        })

      FilterChips({
        selected: this.filterIdx,
        onSelect: (i: number): void => {
          this.onFilterChange(i);
        }
      })

      if (this.vm.assignee === Constants.UNASSIGNED) {
        Text($r('app.string.unassigned_tip'))
          .fontSize(12)
          .fontColor('#E84026')
          .width('100%')
          .padding({ left: 16, right: 16, top: 4, bottom: 4 })
      }

      if (!this.hasData && !this.importing) {
        EmptyView({
          tip: this.showSwitchHint ? $r('app.string.assignee_empty_tip') : $r('app.string.empty_import_tip'),
          actionText: $r('app.string.menu_import'),
          onAction: (): void => {
            this.onImport();
          }
        })
      } else {
        List() {
          LazyForEach(this.vm, (record: CallRecord, index: number) => {
            this.listItem(record, index)
          }, (record: CallRecord) => record.id.toString())
        }
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: '#F1F3F5' })
        .onReachEnd(() => {
          this.vm.loadMore();
        })
      }

      Row() {
        Button(this.importing ? this.importStage : '导入名单')
          .fontSize(14)
          .layoutWeight(1)
          .enabled(!this.importing)
          .onClick(() => {
            this.onImport();
          })
        Button('内置名单')
          .fontSize(14)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            this.checkBuiltin(true);
          })
        Button(this.exporting ? '导出中…' : '导出结果')
          .fontSize(14)
          .layoutWeight(1)
          .margin({ left: 8 })
          .enabled(!this.exporting)
          .onClick(() => {
            this.onExport();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showNumberSheet, this.numberSheetContent(), { height: 320, showClose: true })
  }
}
