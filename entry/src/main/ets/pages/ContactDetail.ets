import { common } from '@kit.AbilityKit';
import { CallListDao } from '../database/CallListDao';
import { MetaDao } from '../database/MetaDao';
import { StatusDao } from '../database/StatusDao';
import { CallRecord } from '../model/CallRecord';
import { ImportMeta } from '../model/ImportMeta';
import { Constants } from '../common/Constants';
import { ConfigDao } from '../database/ConfigDao';
import { ContextUtil } from '../common/ContextUtil';
import { CallService } from '../service/CallService';
import { MotionSpec } from '../common/MotionSpec';
import { ThemeSpec } from '../common/ThemeSpec';
import { StatusPill } from '../components/StatusPill';
import { IconButton } from '../components/IconButton';
import { NumberSheet } from '../components/NumberSheet';
import { CallConfirmDialog } from '../components/CallConfirmDialog';

/**
 * 条目详情页（FR-4 详情 / FR-5；v0.7 UI 重构，docs/14 4.2）：
 * 头部卡（姓名+状态胶囊+号码+拨打主按钮）+ 状态卡（已打/打通/意向三行开关）+ 信息卡（其余列键值行）。
 *
 * M2-2：router → Navigation 迁移。本页为 NavDestination：条目 id 经
 * pushPathByName 参数传入（onReady 读取）；返回统一 pop(带结果) 并拦截系统返回，
 * 保证宿主 Index 的 onPop 回调触发。
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
  @State appearCard: number = 0;
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
    this.playCards();
  }

  /** 分区卡错峰淡入（docs/14 5.2：index*40ms delay） */
  playCards(): void {
    this.appearCard = 0;
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: MotionSpec.entrance() }, () => {
        this.appearCard = 1;
      });
    }, MotionSpec.STAGGER);
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: MotionSpec.entrance() }, () => {
        this.appearCard = 2;
      });
    }, MotionSpec.STAGGER * 2);
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: MotionSpec.entrance() }, () => {
        this.appearCard = 3;
      });
    }, MotionSpec.STAGGER * 3);
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
  statusRow(col: string, active: boolean, labelOn: ResourceStr, labelOff: ResourceStr, toggle: (v: boolean) => void) {
    Row() {
      Text('●')
        .fontSize(14)
        .fontColor($r('app.color.primary'))
      Text(col)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 10 })
      Blank()
      StatusPill({
        active: active,
        labelOn: labelOn,
        labelOff: labelOff,
        onToggle: (): void => {
          toggle(!active);
        }
      })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  @Builder
  infoRow(col: string, value: string, showDivider: boolean) {
    Column() {
      Row() {
        Text(col)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_hint'))
          .width(96)
        Text(value)
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })
      if (showDivider) {
        Divider().color($r('app.color.divider'))
      }
    }
    .width('100%')
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部栏：40vp 圆形返回 + 居中标题 + 右侧占位（保持对称）
        Row() {
          IconButton({
            icon: '←',
            onTap: (): void => {
              this.popBack();
            }
          })
          Blank()
          Text($r('app.string.detail_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Row()
            .width($r('app.float.icon_btn_size'))
            .height($r('app.float.icon_btn_size'))
        }
        .width('100%')
        .padding({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), top: 8, bottom: 8 })

        if (!this.loaded) {
          Text('未找到该条数据')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 40 })
        } else {
          Scroll() {
            Column() {
              // ---- 头部卡 ----
              Column() {
                Row() {
                  Text(this.record.name !== '' ? this.record.name : '（无姓名）')
                    .fontSize(28)
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
                  .fontSize($r('app.float.font_body'))
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .margin({ top: 8 })

                Button() {
                  Row() {
                    Text('📞').fontSize(18)
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
                .margin({ top: 16 })
                .onClick(() => {
                  this.onCall();
                })
              }
              .padding($r('app.float.space_card_inner'))
              .borderRadius($r('app.float.radius_card'))
              .backgroundColor($r('app.color.card'))
              .shadow({
                radius: ThemeSpec.SHADOW_CARD_RADIUS,
                color: ThemeSpec.SHADOW_CARD_COLOR,
                offsetX: 0,
                offsetY: ThemeSpec.SHADOW_CARD_OFFSET_Y
              })
              .opacity(this.appearCard >= 1 ? 1 : 0)
              .translate({ y: this.appearCard >= 1 ? 0 : MotionSpec.ENTRANCE_TRANSLATE })

              // ---- 状态卡 ----
              if (this.calledCol !== '' || this.connectedCol !== '' || this.intentionCol !== '') {
                Column() {
                  if (this.calledCol !== '') {
                    this.statusRow(this.calledCol, this.record.called,
                      $r('app.string.status_pill_called'), $r('app.string.status_pill_uncalled'),
                      (v: boolean): void => {
                        this.markCalled(v);
                      })
                  }
                  if (this.connectedCol !== '') {
                    this.statusRow(this.connectedCol, this.connected,
                      $r('app.string.status_connected'), $r('app.string.status_not_connected'),
                      (v: boolean): void => {
                        StatusDao.setValue(this.record.id, Constants.STATUS_KEY_CONNECTED, v).then(() => {
                          this.connected = v;
                        });
                      })
                  }
                  if (this.intentionCol !== '') {
                    this.statusRow(this.intentionCol, this.intention,
                      $r('app.string.status_intention'), $r('app.string.status_no_intention'),
                      (v: boolean): void => {
                        StatusDao.setValue(this.record.id, Constants.STATUS_KEY_INTENTION, v).then(() => {
                          this.intention = v;
                        });
                      })
                  }
                }
                .padding({ left: $r('app.float.space_card_inner'), right: $r('app.float.space_card_inner'), top: 4, bottom: 4 })
                .borderRadius($r('app.float.radius_card'))
                .backgroundColor($r('app.color.card'))
                .shadow({
                  radius: ThemeSpec.SHADOW_CARD_RADIUS,
                  color: ThemeSpec.SHADOW_CARD_COLOR,
                  offsetX: 0,
                  offsetY: ThemeSpec.SHADOW_CARD_OFFSET_Y
                })
                .margin({ top: $r('app.float.space_group') })
                .opacity(this.appearCard >= 2 ? 1 : 0)
                .translate({ y: this.appearCard >= 2 ? 0 : MotionSpec.ENTRANCE_TRANSLATE })
              }

              // ---- 信息卡 ----
              if (this.infoColumns().length > 0) {
                Column() {
                  ForEach(this.infoColumns(), (col: string, i: number) => {
                    this.infoRow(col, this.record.rawData[col] ?? '', i < this.infoColumns().length - 1)
                  }, (col: string, i: number) => i + '_' + col)
                }
                .padding({ left: $r('app.float.space_card_inner'), right: $r('app.float.space_card_inner'), top: 4, bottom: 4 })
                .borderRadius($r('app.float.radius_card'))
                .backgroundColor($r('app.color.card'))
                .shadow({
                  radius: ThemeSpec.SHADOW_CARD_RADIUS,
                  color: ThemeSpec.SHADOW_CARD_COLOR,
                  offsetX: 0,
                  offsetY: ThemeSpec.SHADOW_CARD_OFFSET_Y
                })
                .margin({ top: $r('app.float.space_group') })
                .opacity(this.appearCard >= 3 ? 1 : 0)
                .translate({ y: this.appearCard >= 3 ? 0 : MotionSpec.ENTRANCE_TRANSLATE })
              }
            }
            .width('100%')
            .padding({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), bottom: $r('app.float.space_group') })
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg'))
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
