import { common } from '@kit.AbilityKit';
import { CallListDao } from '../database/CallListDao';
import { MetaDao } from '../database/MetaDao';
import { StatusDao } from '../database/StatusDao';
import { CallRecord } from '../model/CallRecord';
import { ImportMeta } from '../model/ImportMeta';
import { Constants } from '../common/Constants';
import { ConfigDao } from '../database/ConfigDao';
import { ContextUtil } from '../common/ContextUtil';
import { WindowInsets } from '../common/WindowInsets';
import { CallService } from '../service/CallService';
import { MotionSpec } from '../common/MotionSpec';
import { ThemeSpec, MaterialRole } from '../common/ThemeSpec';
import { StatusPill } from '../components/StatusPill';
import { IconButton } from '../components/IconButton';
import { SemanticMaterialSurface } from '../components/SemanticMaterialSurface';
import { NumberSheet } from '../components/NumberSheet';
import { CallConfirmDialog } from '../components/CallConfirmDialog';

/**
 * 条目详情页（FR-4 详情 / FR-5；docs/15 3.2）：
 * 头部卡（姓名+状态胶囊+号码+拨打主按钮）+ 外呼状态卡（已打/打通/意向三行独立 Switch，语义色）+
 * 客户信息卡（其余列键值行）。
 * 5.6 转场：入场 opacity 0→1 / translateX 24→0 / scale 0.985→1（springMotion(0.42,0.86)）+ 卡片错峰 35ms。
 *
 * M2-2：router → Navigation 迁移。本页为 NavDestination；返回统一 pop(带结果) 并拦截系统返回。
 */
@Component
export struct ContactDetail {
  @State record: CallRecord = new CallRecord();
  @State columns: string[] = [];
  @State calledCol: string = '';
  @State connectedCol: string = '';
  @State intentionCol: string = '';
  @State nameCol: string = '';
  @State phoneCol: string = '';
  @State connected: boolean = false;
  @State intention: boolean = false;
  @State loaded: boolean = false;
  @State showNumberSheet: boolean = false;
  @State sheetNumbers: string[] = [];
  @State sheetName: string = '';
  @State appear: number = 0;
  @State immersive: boolean = false;
  @State insetTop: number = 0;
  private confirmName: string = '';
  private confirmNumber: string = '';
  private confirmController: CustomDialogController | undefined = undefined;
  private stack: NavPathStack | undefined = undefined;

  /** NavDestination 就绪回调：记录栈引用并从导航参数读取条目 id */
  private handleReady(ctx: NavDestinationContext): void {
    this.stack = ctx.pathStack;
    const param = ctx.pathInfo.param as Record<string, number>;
    const id: number = param === undefined ? 0 : (param['id'] ?? 0);
    this.loadRecord(id);
  }

  /** 返回上一页：pop 携带结果，触发宿主 onPop 回调 */
  private popBack(): void {
    const result: Record<string, boolean> = { 'back': true };
    if (this.stack !== undefined) {
      this.stack.pop(result);
    }
  }

  async loadRecord(id: number): Promise<void> {
    const ctx: common.UIAbilityContext | undefined = ContextUtil.getAbilityContext(this.getUIContext());
    if (ctx !== undefined) {
      const ok: boolean = await WindowInsets.load(ctx, this.getUIContext());
      this.immersive = ok;
      this.insetTop = WindowInsets.top();
    }
    const rec: CallRecord | undefined = await CallListDao.getById(id);
    if (rec === undefined) {
      this.loaded = false;
      return;
    }
    this.record = rec;
    const meta: ImportMeta | undefined = await MetaDao.getActive();
    this.columns = meta !== undefined ? meta.allColumns : [];
    this.calledCol = meta !== undefined ? (meta.columnMapping['called'] ?? '') : '';
    this.connectedCol = meta !== undefined ? (meta.columnMapping['connected'] ?? '') : '';
    this.intentionCol = meta !== undefined ? (meta.columnMapping['intention'] ?? '') : '';
    this.nameCol = meta !== undefined ? (meta.columnMapping['name'] ?? '') : '';
    this.phoneCol = meta !== undefined ? (meta.columnMapping['phone'] ?? '') : '';
    // M3：读取打通/意向状态（缺省 false）
    this.connected = await StatusDao.getValue(rec.id, Constants.STATUS_KEY_CONNECTED);
    this.intention = await StatusDao.getValue(rec.id, Constants.STATUS_KEY_INTENTION);
    this.loaded = true;
    this.playEntrance();
  }

  /** 5.6 页面转场 + 分区卡错峰（35ms） */
  playEntrance(): void {
    this.appear = 0;
    this.getUIContext().animateTo({ curve: MotionSpec.pageTransition() }, () => {
      this.appear = 1;
    });
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: MotionSpec.entrance() }, () => {
        this.appear = 2;
      });
    }, MotionSpec.STAGGER);
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: MotionSpec.entrance() }, () => {
        this.appear = 3;
      });
    }, MotionSpec.STAGGER * 2);
  }

  async markCalled(v: boolean): Promise<void> {
    await StatusDao.setCalled(this.record.id, v);
    this.record.called = v;
  }

  /** 信息卡列：排除 姓名/手机/已打/打通/意向 五类映射列，其余按原列序只读展示 */
  infoColumns(): string[] {
    const cols: string[] = [];
    for (const c of this.columns) {
      if (c === this.calledCol || c === this.connectedCol || c === this.intentionCol ||
        c === this.nameCol || c === this.phoneCol) {
        continue;
      }
      cols.push(c);
    }
    return cols;
  }

  /** 电话展示文本（头部卡） */
  phoneText(): string {
    return this.record.phoneNumbers.length > 1 ? '手机 ×' + this.record.phoneNumbers.length : this.record.phoneRaw;
  }

  private titleText(): string {
    return this.record.name !== '' ? this.record.name : '详情';
  }

  // ---- 拨号（与主列表一致：确认框可关闭；唤起即标记，R-7 拨出即算）----
  async onCall(): Promise<void> {
    if (this.record.phoneNumbers.length === 0) {
      this.uiToast('未识别到有效号码，可长按复制原文');
      return;
    }
    if (this.record.phoneNumbers.length === 1) {
      await this.startCall(this.record.phoneNumbers[0]);
      return;
    }
    this.sheetNumbers = this.record.phoneNumbers.slice();
    this.sheetName = this.record.name;
    this.showNumberSheet = true;
  }

  onNumberPicked(index: number): void {
    this.showNumberSheet = false;
    this.startCall(this.sheetNumbers[index]);
  }

  async startCall(number: string): Promise<void> {
    const flag: string = await ConfigDao.get(Constants.CONFIG_CONFIRM_BEFORE_CALL);
    if (flag === '0') {
      await this.doCall(number);
      return;
    }
    this.confirmName = this.record.name !== '' ? this.record.name : '该联系人';
    this.confirmNumber = number;
    this.confirmController = new CustomDialogController({
      builder: CallConfirmDialog({
        name: this.confirmName,
        number: this.confirmNumber,
        onConfirm: (): void => {
          this.doCall(number);
        }
      }),
      autoCancel: true
    });
    this.confirmController.open();
  }

  async doCall(number: string): Promise<void> {
    const ctx: common.UIAbilityContext | undefined = ContextUtil.getAbilityContext(this.getUIContext());
    if (ctx === undefined) {
      this.uiToast('无法获取应用上下文');
      return;
    }
    const result = await CallService.openDialer(ctx, number);
    if (result.success) {
      // 唤起系统拨号即算已打（R-7）：拨出即标记（不再依赖页面生命周期回调）
      await this.markCalled(true);
    } else {
      this.uiToast(result.message);
    }
  }

  private uiToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (e) {
      // 提示失败忽略
    }
  }

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
  sectionLabel(label: ResourceStr) {
    Text(label)
      .fontSize($r('app.float.font_overline'))
      .fontColor($r('app.color.text_tertiary'))
      .width('100%')
      .margin({ left: 4, bottom: 8, top: 4 })
      .textAlign(TextAlign.Start)
  }

  /** 状态行：58vp 高 + 1vp divider；Switch 52×32，打开态显示对应语义色（校对#3：三行独立）。
   *  注意（真机实测坑位）：@Builder 传参参数固化，状态行一律无参 @Builder 直读 this。 */
  @Builder
  calledRow() {
    Row() {
      Text(this.calledCol)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: this.record.called })
        .width(52)
        .height(32)
        .selectedColor($r('app.color.pill_called_fg'))
        .onChange((v: boolean) => {
          this.markCalled(v);
        })
    }
    .width('100%')
    .height(58)
  }

  @Builder
  connectedRow() {
    Row() {
      Text(this.connectedCol)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: this.connected })
        .width(52)
        .height(32)
        .selectedColor($r('app.color.pill_connected_fg'))
        .onChange((v: boolean) => {
          StatusDao.setValue(this.record.id, Constants.STATUS_KEY_CONNECTED, v).then(() => {
            this.connected = v;
          });
        })
    }
    .width('100%')
    .height(58)
  }

  @Builder
  intentionRow() {
    Row() {
      Text(this.intentionCol)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: this.intention })
        .width(52)
        .height(32)
        .selectedColor($r('app.color.pill_intention_fg'))
        .onChange((v: boolean) => {
          StatusDao.setValue(this.record.id, Constants.STATUS_KEY_INTENTION, v).then(() => {
            this.intention = v;
          });
        })
    }
    .width('100%')
    .height(58)
  }

  @Builder
  infoRow(col: string, value: string, showDivider: boolean) {
    Column() {
      Row() {
        Text(col)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_tertiary'))
          .width(110)
        Text(value)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      if (showDivider) {
        Divider().color($r('app.color.divider'))
      }
    }
    .width('100%')
  }

  @Builder
  headerCardBody() {
    Column() {
      Row() {
        Text(this.record.name !== '' ? this.record.name : '（无姓名）')
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        StatusPill({
          active: this.record.called,
          onToggle: (): void => {
            this.markCalled(!this.record.called);
          }
        })
          .margin({ left: 8 })
      }
      .width('100%')

      Text(this.phoneText())
        .fontSize($r('app.float.font_body_lg'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ top: 10 })

      // 主按钮（primary-action 语义：primary 底 #FFF 字 + shadow 12/0.16/4）
      Button() {
        Row() {
          Text('☎').fontSize(20)
          Text($r('app.string.call'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .margin({ left: 6 })
        }
      }
      .width('100%')
      .height(48)
      .backgroundColor($r('app.color.primary'))
      .fontColor(Color.White)
      .borderRadius($r('app.float.radius_btn'))
      .shadow({
        radius: 12,
        color: ThemeSpec.shadowColor(0.16),
        offsetX: 0,
        offsetY: 4
      })
      .margin({ top: 16 })
      .stateStyles({
        pressed: {
          .brightness(0.9)
        }
      })
      .onClick(() => {
        this.onCall();
      })
    }
    .width('100%')
    .padding($r('app.float.space_card_inner'))
  }

  @Builder
  statusCardBody() {
    Column() {
      if (this.calledCol !== '') {
        this.calledRow()
        Divider().color($r('app.color.divider'))
      }
      if (this.connectedCol !== '') {
        this.connectedRow()
        Divider().color($r('app.color.divider'))
      }
      if (this.intentionCol !== '') {
        this.intentionRow()
      }
    }
    .width('100%')
    .padding({ left: $r('app.float.space_card_inner'), right: $r('app.float.space_card_inner') })
  }

  @Builder
  infoCardBody() {
    Column() {
      ForEach(this.infoColumns(), (col: string, i: number) => {
        this.infoRow(col, this.record.rawData[col] ?? '', i < this.infoColumns().length - 1)
      }, (col: string, i: number) => i + '_' + col)
    }
    .width('100%')
    .padding({ left: $r('app.float.space_card_inner'), right: $r('app.float.space_card_inner') })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        // 背景层：expandSafeArea 铺满状态栏/导航栏（docs/16 6.2，测量成功才扩展）
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.bg_page'))
          .expandSafeArea(this.immersive ? [SafeAreaType.SYSTEM] : undefined,
            this.immersive ? [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM] : undefined)

        Column() {
          // 顶部栏：50vp 圆形返回 + 居中标题（姓名）+ 右侧占位（保持对称）
          Row() {
          IconButton({
            icon: '←',
            onTap: (): void => {
              this.popBack();
            }
          })
          Blank()
          Text(this.titleText())
            .fontSize($r('app.float.font_headline'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Blank()
          Row()
            .width($r('app.float.icon_btn_size'))
            .height($r('app.float.icon_btn_size'))
        }
        .width('100%')
        .constraintSize({ maxWidth: ThemeSpec.CONTENT_MAX_WIDTH_VP })
        .height($r('app.float.header_height'))
        .padding({ left: $r('app.float.space_page'), right: $r('app.float.space_page') })
        .margin({ top: 8 })

        if (!this.loaded) {
          Text('未找到该条数据')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 40 })
        } else {
          Scroll() {
            Column() {
              // ---- 头部卡 ----
              SemanticMaterialSurface({
                role: MaterialRole.NORMAL_SURFACE,
                emphasis: false,
                radius: $r('app.float.radius_card')
              }) {
                this.headerCardBody()
              }

              // ---- 外呼状态卡（三行独立 Switch，校对#3）----
              if (this.calledCol !== '' || this.connectedCol !== '' || this.intentionCol !== '') {
                Column() {
                  this.sectionLabel($r('app.string.detail_section_status'))
                  SemanticMaterialSurface({
                    role: MaterialRole.NORMAL_SURFACE,
                    emphasis: false,
                    radius: $r('app.float.radius_card')
                  }) {
                    this.statusCardBody()
                  }
                }
                .width('100%')
                .margin({ top: $r('app.float.space_group') })
                .opacity(this.appear >= 2 ? 1 : 0)
                .translate({ y: this.appear >= 2 ? 0 : MotionSpec.ENTRANCE_TRANSLATE })
              }

              // ---- 客户信息卡 ----
              if (this.infoColumns().length > 0) {
                Column() {
                  this.sectionLabel($r('app.string.detail_section_info'))
                  SemanticMaterialSurface({
                    role: MaterialRole.NORMAL_SURFACE,
                    emphasis: false,
                    radius: $r('app.float.radius_card')
                  }) {
                    this.infoCardBody()
                  }
                }
                .width('100%')
                .margin({ top: $r('app.float.space_group') })
                .opacity(this.appear >= 3 ? 1 : 0)
                .translate({ y: this.appear >= 3 ? 0 : MotionSpec.ENTRANCE_TRANSLATE })
              }
            }
            .width('100%')
            .constraintSize({ maxWidth: ThemeSpec.CONTENT_MAX_WIDTH_VP })
            .padding({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), bottom: $r('app.float.space_group') })
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .opacity(this.appear >= 1 ? 1 : 0)
          .translate({ x: this.appear >= 1 ? 0 : MotionSpec.PAGE_TRANSITION_TRANSLATE_X })
          .scale({ x: this.appear >= 1 ? 1 : 0.985, y: this.appear >= 1 ? 1 : 0.985 })
        }
      }
      .width('100%')
      .height('100%')
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.handleReady(ctx);
    })
    .onBackPressed((): boolean => {
      this.popBack();
      return true;
    })
    .bindSheet($$this.showNumberSheet, this.numberSheetContent(), { height: 320, showClose: true })
  }
}
