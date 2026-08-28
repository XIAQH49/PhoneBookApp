import { common } from '@kit.AbilityKit';
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
 * 主列表页（FR-3 / FR-4 / FR-6；v0.7 第二轮视觉反馈修订）：
 * - 顶栏毛玻璃（bar_bg + COMPONENT_ULTRA_THICK，随内容滚动悬浮，反馈#7）；
 * - 左上角：状态筛选下拉菜单（全部 ▾，菜单带计数）+ 搜索按钮（点开内联搜索栏，反馈#2/#3）；
 * - 责任人/设置入口为无背景纯文本/图标（反馈#4）；
 * - PersonCard 固定单列紧凑卡（反馈#1/#8）；底栏 60vp 收窄、无按压底色、光感 high 档（反馈#5）；
 * - 沉浸式全屏（EntryAbility setWindowLayoutFullScreen，反馈#6）；底栏预留 132vp。
 *
 * M2-2：router → Navigation 迁移。本页为导航宿主；子页 pop 携带结果触发 onPop 回调。
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
  @State searchOpen: boolean = false;
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
  private searchTimer: number = -1;
  private confirmController: CustomDialogController | undefined = undefined;
  private initRetry: number = 0;
  private builtinChecked: boolean = false;

  aboutToAppear(): void {
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
    // 全部责任人总计（v0.5.1 功能保留）
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

  /** 收起搜索：清空关键字并恢复全量列表 */
  closeSearch(): void {
    this.searchOpen = false;
    if (this.searchText !== '') {
      this.searchText = '';
      this.vm.setKeyword('').then(() => {
        this.syncAll();
      });
    }
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
    return (this.assigneeName === '' ? '未分配' : this.assigneeName) + ' ⌄';
  }

  private filterLabel(): string {
    if (this.filterIdx === 1) {
      return '未打';
    }
    if (this.filterIdx === 2) {
      return '已打';
    }
    return '全部';
  }

  /** 筛选下拉菜单（反馈#2：左上角下拉，菜单带计数） */
  private filterMenu(): MenuElement[] {
    const uncalled: number = this.statTotal - this.statCalled;
    const items: MenuElement[] = [
      {
        value: (this.filterIdx === 0 ? '✓ ' : '   ') + '全部 ' + this.statTotal,
        action: (): void => {
          this.onFilterChange(0);
        }
      },
      {
        value: (this.filterIdx === 1 ? '✓ ' : '   ') + '未打 ' + uncalled,
        action: (): void => {
          this.onFilterChange(1);
        }
      },
      {
        value: (this.filterIdx === 2 ? '✓ ' : '   ') + '已打 ' + this.statCalled,
        action: (): void => {
          this.onFilterChange(2);
        }
      }
    ];
    return items;
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
          allCalled: this.allCalled,
          assignee: this.assigneeName
        })
      }
      .width('100%')
      .margin({ bottom: $r('app.float.space_group') })
    }
  }

  /** 毛玻璃顶栏（反馈#7）：标题 + 筛选下拉 + 搜索按钮 + 责任人 + 设置 */
  @Builder
  topBar() {
    Column() {
      Row() {
        Text($r('app.string.home_title'))
          .fontSize($r('app.float.font_title'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        // 左上角：筛选下拉 + 搜索按钮（反馈#2/#3）
        Text(this.filterLabel() + ' ▾')
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.primary'))
          .padding({ left: 6, top: 8, bottom: 8 })
          .margin({ left: 14 })
          .bindMenu(this.filterMenu())
        IconButton({
          icon: '🔍',
          btnSize: 36,
          fontSize: 20,
          onTap: (): void => {
            this.searchOpen = !this.searchOpen;
            if (!this.searchOpen) {
              this.closeSearch();
            }
          }
        })
          .margin({ left: 4 })
        Blank()
        Text(this.assigneeLabel())
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.primary'))
          .padding({ left: 8, top: 8, bottom: 8 })
          .onClick(() => {
            this.goAssigneePicker();
          })
        IconButton({
          icon: ' ⚙',
          onTap: (): void => {
            this.goSettings();
          }
        })
          .margin({ left: 8 })
      }
      .width('100%')
      .height($r('app.float.header_height'))
      .alignItems(VerticalAlign.Center)

      // 搜索展开（内联，反馈#3）
      if (this.searchOpen) {
        Row() {
          Text('🔍')
            .fontSize(16)
            .margin({ left: 16 })
          TextInput({ placeholder: $r('app.string.search_hint'), text: this.searchText })
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_primary'))
            .backgroundColor(Color.Transparent)
            .height($r('app.float.search_height'))
            .layoutWeight(1)
            .margin({ left: 8, right: 8 })
            .onChange((v: string) => {
              this.onSearchChange(v);
            })
          Text('✕')
            .fontSize(18)
            .fontColor($r('app.color.text_secondary'))
            .padding(8)
            .onClick(() => {
              this.closeSearch();
            })
        }
        .width('100%')
        .height($r('app.float.search_height'))
        .backgroundColor($r('app.color.surface_card'))
        .border({ width: 1, color: $r('app.color.divider') })
        .borderRadius($r('app.float.radius_search'))
        .margin({ top: 4, bottom: 12 })
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: ThemeSpec.CONTENT_MAX_WIDTH_VP })
    .padding({ left: $r('app.float.space_page'), right: $r('app.float.space_page') })
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
      .columnsTemplate('1fr')
      .rowsGap($r('app.float.space_between'))
      .cachedCount(8)
      .constraintSize({ maxWidth: ThemeSpec.CONTENT_MAX_WIDTH_VP })
      .padding({
        left: $r('app.float.space_page'),
        right: $r('app.float.space_page'),
        top: this.searchOpen ? 148 : 84,
        bottom: $r('app.float.grid_bottom_padding')
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
        Stack({ alignContent: Alignment.Top }) {
          // 背景层：扩展铺满状态栏/导航栏安全区（无重叠、无黑边），内容层保持系统安全区避让
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.bg_page'))
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

          Column() {
            this.contentArea()
          }
          .width('100%')
          .height('100%')

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
          .margin({ bottom: 16 })
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
