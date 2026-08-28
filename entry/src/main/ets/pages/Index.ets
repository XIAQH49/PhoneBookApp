import { common } from '@kit.AbilityKit';
import { mediaquery } from '@kit.ArkUI';
import { MainViewModel } from '../viewmodel/MainViewModel';
import { CallRecord, CountResult } from '../model/CallRecord';
import { Constants } from '../common/Constants';
import { ContextUtil } from '../common/ContextUtil';
import { ImportService } from '../service/ImportService';
import type { ImportResult, ProgressInfo } from '../service/ImportService';
import { BuiltinListService } from '../service/BuiltinListService';
import type { BuiltinExportResult } from '../service/BuiltinListService';
import { ExportService } from '../service/ExportService';
import type { ExportResult } from '../service/ExportService';
import { CallService } from '../service/CallService';
import { ConfigDao } from '../database/ConfigDao';
import { DbHelper } from '../database/DbHelper';
import { CallListDao } from '../database/CallListDao';
import { ThemeSpec } from '../common/ThemeSpec';
import { StatCard } from '../components/StatCard';
import { FilterChips } from '../components/FilterChips';
import { EmptyView } from '../components/EmptyView';
import { PersonCard } from '../components/PersonCard';
import { BottomActionBar } from '../components/BottomActionBar';
import { IconButton } from '../components/IconButton';
import { NumberSheet } from '../components/NumberSheet';
import { CallConfirmDialog } from '../components/CallConfirmDialog';
import { ContactDetail } from './ContactDetail';
import { Settings } from './Settings';
import { AssigneePicker } from './AssigneePicker';
import { Logger } from '../common/Logger';

const TAG: string = 'Index';
const FILTER_ALL: number = -1;
const FILTER_UNCALLED: number = 0;
const FILTER_CALLED: number = 1;

/**
 * 主列表页（FR-3 / FR-4 / FR-6；v0.7 UI 大重构，docs/14 4.1）：
 * 毛玻璃顶栏（大标题+责任人胶囊+圆形设置钮）+ 统计大卡 + 搜索胶囊 + 筛选胶囊 +
 * PersonCard 双列网格（Grid 2 列，<600vp 单列降级）+ 悬浮胶囊操作栏（4 动作）。
 *
 * M2-2：router → Navigation 迁移。本页为导航宿主：子页（ContactDetail/Settings/
 * AssigneePicker）均为 NavDestination，经 NavPathStack.pushPathByName 压栈；
 * 子页 pop 携带结果触发 onPop 回调 → onSubPageReturn 重载数据。
 */
@Entry
@Component
struct Index {
  private pathStack: NavPathStack = new NavPathStack();
  vm: MainViewModel = new MainViewModel();
  @State assigneeName: string = '';
  @State statTotal: number = 0;
  @State statCalled: number = 0;
  @State allTotal: number = 0;
  @State allCalled: number = 0;
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
  @State isWide: boolean = false;
  private sheetRecord: CallRecord = new CallRecord();
  private confirmName: string = '';
  private confirmNumber: string = '';
  private pendingMark: CallRecord | undefined = undefined;
  private searchTimer: number = -1;
  private confirmController: CustomDialogController | undefined = undefined;
  private initRetry: number = 0;
  private builtinChecked: boolean = false;

  aboutToAppear(): void {
    // 响应式断点（docs/14 4.1 勘误后：<360vp 单列，≥360vp 双列）
    try {
      const listener: mediaquery.MediaQueryListener = this.getUIContext().getMediaQuery()
        .matchMediaSync('(min-width: ' + ThemeSpec.BREAKPOINT_WIDE_VP + 'vp)');
      this.isWide = listener.matches;
      listener.on('change', (m: mediaquery.MediaQueryResult) => {
        this.isWide = m.matches;
      });
    } catch (e) {
      this.isWide = true;
    }
    this.initPage();
  }

  onPageShow(): void {
    if (DbHelper.isReady()) {
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
        await this.askForceImport(ctx);
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

  /** 名单无变化时提供"强制重新导入"（恢复被旧版去重丢弃的重复行，不覆盖已打状态） */
  async askForceImport(ctx: common.UIAbilityContext): Promise<void> {
    let index: number = -1;
    try {
      const res = await this.getUIContext().getPromptAction().showDialog({
        title: '内置名单无变化',
        message: '可强制重新导入以恢复缺失名单（不会丢失已打状态），是否继续？',
        buttons: [
          { text: '取消', color: '#666666' },
          { text: '强制导入', color: '#007DFF' }
        ]
      });
      index = res.index;
    } catch (e) {
      index = -1;
    }
    if (index !== 1) {
      return;
    }
    const r: ImportResult | undefined = await BuiltinListService.importIfChanged(ctx, true);
    if (r !== undefined && r.success) {
      this.uiToast('强制导入完成');
      await this.vm.reloadAssignee();
      await this.syncAll();
    } else if (r !== undefined) {
      this.uiToast(r.message);
    }
  }

  async syncAll(): Promise<void> {
    this.assigneeName = this.vm.assignee;
    const r: CountResult = await this.vm.refreshStats();
    this.statTotal = r.total;
    this.statCalled = r.called;
    // 全部责任人总计（FR-4 总计行）
    const all: CountResult = await CallListDao.countAllByStatus();
    this.allTotal = all.total;
    this.allCalled = all.called;
    this.hasData = this.vm.totalCount() > 0;
    if (!this.hasData) {
      // 区分"尚未导入"与"当前责任人无数据"两种空态
      const allRows: number = await CallListDao.countAllActive();
      this.showSwitchHint = allRows > 0;
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

  /** 一键导出原始内置文件（v0.6，FR-12）：脱离内网构建流程拿回源文件 */
  async onExportBuiltin(): Promise<void> {
    const ctx: common.UIAbilityContext | undefined = ContextUtil.getAbilityContext(this.getUIContext());
    if (ctx === undefined) {
      this.uiToast('无法获取应用上下文');
      return;
    }
    const result: BuiltinExportResult = await BuiltinListService.exportBuiltin(ctx);
    this.uiToast(result.message);
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

  // ---- 导航（M2-2：NavPathStack 压栈；子页 pop 带结果触发 onPop）----
  goAssigneePicker(): void {
    const emptyParam: Record<string, Object> = {};
    try {
      this.pathStack.pushPathByName('AssigneePicker', emptyParam, (info: PopInfo) => {
        this.onSubPageReturn();
      });
    } catch (e) {
      this.uiToast('页面跳转失败');
    }
  }

  goSettings(): void {
    const emptyParam: Record<string, Object> = {};
    try {
      this.pathStack.pushPathByName('Settings', emptyParam, (info: PopInfo) => {
        this.onSubPageReturn();
      });
    } catch (e) {
      this.uiToast('页面跳转失败');
    }
  }

  goDetail(record: CallRecord): void {
    const param: Record<string, number> = { 'id': record.id };
    try {
      this.pathStack.pushPathByName('ContactDetail', param, (info: PopInfo) => {
        this.onSubPageReturn();
      });
    } catch (e) {
      this.uiToast('页面跳转失败');
    }
  }

  /**
   * 子页返回：重载责任人视图与统计（责任人在选择页可能已切换）。
   * 真机实测（SGT-AL10）：pop 过渡期间宿主 List 仍处于隐藏态，此时 LazyForEach 的
   * onDataReloaded 不触发重建（统计能更新、列表行不刷新）；延迟到过渡完成后
   * （宿主可见）再刷新即可正常重建列表。
   */
  private onSubPageReturn(): void {
    Logger.info(TAG, 'sub page popped, reloading list');
    setTimeout(() => {
      this.vm.reloadAssignee().then(() => {
        this.syncAll();
      });
    }, 400);
  }

  @Builder
  pageMap(name: string, param: Object) {
    if (name === 'ContactDetail') {
      ContactDetail()
    } else if (name === 'Settings') {
      Settings()
    } else if (name === 'AssigneePicker') {
      AssigneePicker()
    }
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

  private assigneeLabel(): string {
    return (this.assigneeName === '' ? '未分配' : this.assigneeName) + ' ▾';
  }

  private phoneText(record: CallRecord): string {
    return record.phoneNumbers.length > 1 ? '手机 ×' + record.phoneNumbers.length : record.phoneRaw;
  }

  @Builder
  personItem(record: CallRecord, index: number) {
    GridItem() {
      PersonCard({
        name: record.name,
        phoneText: this.phoneText(record),
        empNo: record.empNo,
        called: record.called,
        staggerIndex: index,
        onToggle: (): void => {
          this.onToggle(record, index, !record.called);
        },
        onCall: (): void => {
          this.onCall(record);
        },
        onOpen: (): void => {
          this.goDetail(record);
        }
      })
    }
  }

  @Builder
  gridHeader() {
    GridItem() {
      Column() {
        StatCard({
          total: this.statTotal,
          called: this.statCalled,
          allTotal: this.allTotal,
          allCalled: this.allCalled
        })

        // 搜索胶囊（全圆）
        Row() {
          Text('🔍')
            .fontSize(16)
            .margin({ left: 14 })
          TextInput({ placeholder: $r('app.string.search_hint'), text: this.searchText })
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(Color.Transparent)
            .height(44)
            .layoutWeight(1)
            .margin({ left: 8, right: 12 })
            .onChange((v: string) => {
              this.onSearchChange(v);
            })
        }
        .height(44)
        .backgroundColor($r('app.color.card'))
        .borderRadius($r('app.float.radius_pill'))
        .margin({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), top: $r('app.float.space_between'), bottom: $r('app.float.space_between') })

        Row() {
          FilterChips({
            selected: this.filterIdx,
            onSelect: (i: number): void => {
              this.onFilterChange(i);
            }
          })
        }
        .width('calc(100% - 32vp)')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), bottom: $r('app.float.space_group') })
      }
      .width('100%')
    }
    .columnStart(0)
    .columnEnd(this.isWide ? 1 : 0)
  }

  @Builder
  topBar() {
    Row() {
      Text($r('app.string.home_title'))
        .fontSize($r('app.float.font_title'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Blank()
      Text(this.assigneeLabel())
        .fontSize(14)
        .fontColor($r('app.color.primary'))
        .backgroundColor($r('app.color.primary_soft'))
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius($r('app.float.radius_pill'))
        .onClick(() => {
          this.goAssigneePicker();
        })
      IconButton({
        icon: ' ⚙',
        onTap: (): void => {
          this.goSettings();
        }
      })
        .margin({ left: 12 })
    }
    .width('100%')
    .padding({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), top: 8, bottom: 12 })
    .backgroundColor($r('app.color.bar_bg'))
    .backgroundBlurStyle(ThemeSpec.BAR_BLUR)
  }

  @Builder
  contentArea() {
    if (!this.hasData && !this.importing) {
      EmptyView({
        tip: this.showSwitchHint ? $r('app.string.assignee_empty_tip') : $r('app.string.empty_import_tip'),
        onImport: (): void => {
          this.onImport();
        }
      })
    } else {
      Grid() {
        this.gridHeader()
        LazyForEach(this.vm, (record: CallRecord, index: number) => {
          this.personItem(record, index)
        }, (record: CallRecord) => record.id.toString() + '_' + this.vm.version())
      }
      .columnsTemplate(this.isWide ? '1fr 1fr' : '1fr')
      .columnsGap($r('app.float.space_between'))
      .rowsGap($r('app.float.space_between'))
      .padding({
        left: $r('app.float.space_page'),
        right: $r('app.float.space_page'),
        top: 76,
        bottom: 96
      })
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .onReachEnd(() => {
        this.vm.loadMore();
      })
    }
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Bottom }) {
        Stack({ alignContent: Alignment.TopStart }) {
          Column() {
            this.contentArea()
          }
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.bg'))

          this.topBar()
        }
        .width('100%')
        .height('100%')

        BottomActionBar({
          importing: this.importing,
          importStage: this.importStage,
          exporting: this.exporting,
          onImport: (): void => {
            this.onImport();
          },
          onBuiltin: (): void => {
            this.checkBuiltin(true);
          },
          onExportBuiltin: (): void => {
            this.onExportBuiltin();
          },
          onExport: (): void => {
            this.onExport();
          }
        })
          .margin({ bottom: 12 })
      }
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.pageMap)
    .width('100%')
    .height('100%')
    .bindSheet($$this.showNumberSheet, this.numberSheetContent(), { height: 320, showClose: true })
  }
}
