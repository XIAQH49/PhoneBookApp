import { CallListDao } from '../database/CallListDao';
import { MetaDao } from '../database/MetaDao';
import { ConfigDao } from '../database/ConfigDao';
import { ImportMeta } from '../model/ImportMeta';
import { Constants } from '../common/Constants';
import { DataResetService } from '../database/DataResetService';
import { MotionSpec } from '../common/MotionSpec';
import { ThemeSpec } from '../common/ThemeSpec';
import { IconButton } from '../components/IconButton';

/**
 * 设置页（FR-5 / R-4；v0.7 UI 重构，docs/14 4.3）：分组卡片列表——
 * 拨号分组卡（开关）/ 导出范围分组卡（单选）/ 数据信息卡 / 危险操作卡。
 * 各设置项持久化行为与旧版一致。
 *
 * M2-2：router → Navigation 迁移。本页为 NavDestination；
 * 返回统一 pop(带结果) 并拦截系统返回，保证宿主 Index 的 onPop 回调触发。
 */
@Component
export struct Settings {
  @State confirmBefore: boolean = true;
  @State exportScope: string = Constants.EXPORT_SCOPE_MINE;
  @State stripCountry: boolean = false;
  @State dataInfo: string = '';
  @State appearCard: number = 0;
  private stack: NavPathStack | undefined = undefined;

  /** NavDestination 就绪回调：记录栈引用 */
  private handleReady(ctx: NavDestinationContext): void {
    this.stack = ctx.pathStack;
  }

  /** 返回上一页：pop 携带结果，触发宿主 onPop 回调 */
  private popBack(): void {
    const result: Record<string, boolean> = { 'back': true };
    if (this.stack !== undefined) {
      this.stack.pop(result);
    }
  }

  async aboutToAppear(): Promise<void> {
    const c: string = await ConfigDao.get(Constants.CONFIG_CONFIRM_BEFORE_CALL);
    this.confirmBefore = c !== '0';
    const s: string = await ConfigDao.get(Constants.CONFIG_EXPORT_SCOPE);
    this.exportScope = s === '' ? Constants.EXPORT_SCOPE_MINE : s;
    const sc: string = await ConfigDao.get(Constants.CONFIG_CALL_STRIP_COUNTRY);
    this.stripCountry = sc === '1';
    await this.reloadDataInfo();
    this.playCards();
  }

  /** 分组卡错峰淡入（docs/14 5.2：index*40ms delay） */
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

  @Builder
  switchRow(label: ResourceStr, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange((v: boolean) => {
          onChange(v);
        })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  @Builder
  radioRow(value: string, label: ResourceStr, checked: boolean, onChange: () => void) {
    Row() {
      Radio({ value: value, group: 'export_scope' })
        .checked(checked)
        .onChange((v: boolean) => {
          if (v) {
            onChange();
          }
        })
      Text(label)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
        .margin({ left: 10 })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
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
          Text($r('app.string.settings_title'))
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

        Scroll() {
          Column() {
            // ---- 拨号分组卡 ----
            Column() {
              this.switchRow($r('app.string.confirm_before_call'), this.confirmBefore, (v: boolean): void => {
                this.confirmBefore = v;
                ConfigDao.set(Constants.CONFIG_CONFIRM_BEFORE_CALL, v ? '1' : '0');
              })
              Divider().color($r('app.color.divider'))
              this.switchRow($r('app.string.strip_country_call'), this.stripCountry, (v: boolean): void => {
                this.stripCountry = v;
                ConfigDao.set(Constants.CONFIG_CALL_STRIP_COUNTRY, v ? '1' : '0');
              })
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
            .opacity(this.appearCard >= 1 ? 1 : 0)
            .translate({ y: this.appearCard >= 1 ? 0 : MotionSpec.ENTRANCE_TRANSLATE })

            // ---- 导出范围分组卡 ----
            Column() {
              Text($r('app.string.export_scope'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_hint'))
                .width('100%')
                .margin({ bottom: 4 })
                .textAlign(TextAlign.Start)
              this.radioRow(Constants.EXPORT_SCOPE_MINE, $r('app.string.export_scope_mine'), this.exportScope === Constants.EXPORT_SCOPE_MINE, (): void => {
                this.exportScope = Constants.EXPORT_SCOPE_MINE;
                ConfigDao.set(Constants.CONFIG_EXPORT_SCOPE, Constants.EXPORT_SCOPE_MINE);
              })
              this.radioRow(Constants.EXPORT_SCOPE_ALL, $r('app.string.export_scope_all'), this.exportScope === Constants.EXPORT_SCOPE_ALL, (): void => {
                this.exportScope = Constants.EXPORT_SCOPE_ALL;
                ConfigDao.set(Constants.CONFIG_EXPORT_SCOPE, Constants.EXPORT_SCOPE_ALL);
              })
            }
            .padding({ left: $r('app.float.space_card_inner'), right: $r('app.float.space_card_inner'), top: 12, bottom: 12 })
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

            // ---- 数据信息卡 ----
            Row() {
              Text($r('app.string.section_data'))
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_hint'))
              Blank()
              Text(this.dataInfo)
                .fontSize($r('app.float.font_caption'))
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
                .margin({ left: 12 })
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .padding($r('app.float.space_card_inner'))
            .borderRadius($r('app.float.radius_card'))
            .backgroundColor($r('app.color.card'))
            .margin({ top: $r('app.float.space_group') })
            .opacity(this.appearCard >= 3 ? 1 : 0)
            .translate({ y: this.appearCard >= 3 ? 0 : MotionSpec.ENTRANCE_TRANSLATE })

            // ---- 危险操作卡 ----
            Button() {
              Row() {
                Text('⚠').fontSize(16)
                Text($r('app.string.clear_all_data'))
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .margin({ left: 6 })
              }
            }
            .width('100%')
            .height(48)
            .fontColor($r('app.color.danger'))
            .backgroundColor($r('app.color.danger_soft'))
            .borderRadius($r('app.float.radius_card'))
            .border({ width: 1, color: $r('app.color.danger') })
            .margin({ top: $r('app.float.space_group') })
            .onClick(() => {
              this.onClearAll();
            })
          }
          .width('100%')
          .padding({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), bottom: $r('app.float.space_group') })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
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
  }

  /** 一键清除全部名单（带确认） */
  async onClearAll(): Promise<void> {
    let index: number = -1;
    try {
      const res = await this.getUIContext().getPromptAction().showDialog({
        title: '清除全部名单？',
        message: '将删除所有导入数据与拨打状态，此操作不可恢复',
        buttons: [
          { text: '取消', color: '#666666' },
          { text: '清除', color: '#E84026' }
        ]
      });
      index = res.index;
    } catch (e) {
      index = -1;
    }
    if (index !== 1) {
      return;
    }
    try {
      await DataResetService.clearAllData();
      await this.reloadDataInfo();
      this.uiToast('名单已清除');
    } catch (e) {
      this.uiToast('清除失败：' + (e as Error).message);
    }
  }

  async reloadDataInfo(): Promise<void> {
    const total: number = await CallListDao.countAllActive();
    const meta: ImportMeta | undefined = await MetaDao.getActive();
    let info: string = '数据 ' + total + ' 条';
    if (meta !== undefined) {
      info += '，最近导入：' + meta.fileName;
    }
    this.dataInfo = info;
  }

  private uiToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (e) {
      // 提示失败忽略
    }
  }
}
