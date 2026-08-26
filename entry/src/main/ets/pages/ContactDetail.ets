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
import { NumberSheet } from '../components/NumberSheet';
import { CallConfirmDialog } from '../components/CallConfirmDialog';

/**
 * 条目详情页（FR-4 详情 / FR-5）：只读展示全部原始列 + 已打切换 + 拨打。
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
  @State loaded: boolean = false;
  @State showNumberSheet: boolean = false;
  @State sheetNumbers: string[] = [];
  @State sheetName: string = '';
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
    this.loaded = true;
  }

  async markCalled(): Promise<void> {
    await StatusDao.setCalled(this.record.id, true);
    this.record.called = true;
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
      await this.markCalled();
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
  detailRow(col: string) {
    Row() {
      Text(col)
        .fontSize(14)
        .fontColor('#999999')
        .width(120)
      if (col === this.calledCol) {
        Checkbox()
          .select(this.record.called)
          .onChange((v: boolean) => {
            StatusDao.setCalled(this.record.id, v).then(() => {
              this.record.called = v;
            });
          })
        Text(this.record.called ? '已打' : '未打').fontSize(14)
      } else {
        Text(this.record.rawData[col] ?? '')
          .fontSize(14)
          .layoutWeight(1)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('← 返回')
            .fontSize(16)
            .onClick(() => {
              this.popBack();
            })
          Blank()
          Text('详情')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
          Blank()
          Text('    ')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        if (!this.loaded) {
          Text('未找到该条数据').fontSize(14).margin({ top: 40 })
        } else {
          Scroll() {
            Column() {
              ForEach(this.columns, (col: string) => {
                this.detailRow(col)
              }, (col: string, i: number) => i + '_' + col)
            }
          }
          .layoutWeight(1)
          .width('100%')

          Button($r('app.string.call'))
            .width('80%')
            .margin({ bottom: 16 })
            .onClick(() => {
              this.onCall();
            })
        }
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
