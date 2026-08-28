import { CallListDao } from '../database/CallListDao';
import { MetaDao } from '../database/MetaDao';
import { ConfigDao } from '../database/ConfigDao';
import { ImportMeta } from '../model/ImportMeta';
import { Constants } from '../common/Constants';
import { DataResetService } from '../database/DataResetService';
import { MotionSpec } from '../common/MotionSpec';
import { ThemeSpec, MaterialRole } from '../common/ThemeSpec';
import { IconButton } from '../components/IconButton';
import { SemanticMaterialSurface } from '../components/SemanticMaterialSurface';

/**
 * 设置页（FR-5 / R-4；docs/15 3.3 + 校对#1：仅重构现有设置项，不新增开关）：
 * 拨号 分组卡（拨号前确认/拨号前去除+86）、导出 分组卡（单选）、信息 卡片、危险 卡片。
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

  /** 分组卡错峰淡入（docs/15 5.2：index*35ms delay） */
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
  sectionLabel(label: ResourceStr) {
    Text(label)
      .fontSize($r('app.float.font_overline'))
      .fontColor($r('app.color.text_tertiary'))
      .width('100%')
      .margin({ left: 4, bottom: 8 })
      .textAlign(TextAlign.Start)
  }

  @Builder
  switchRow(label: ResourceStr, isOn: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_primary'))
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .width(52)
        .height(32)
        .selectedColor($r('app.color.primary'))
        .onChange((v: boolean) => {
          onChange(v);
        })
    }
    .width('100%')
    .height(58)
  }

  @Builder
  radioRow(value: string, label: ResourceStr, checked: boolean, onChange: () => void) {
    Row() {
      Radio({ value: value, group: 'export_scope' })
        .checked(checked)
        .radioStyle({ checkedBackgroundColor: $r('app.color.primary') })
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
    .height(48)
  }

  @Builder
  dialCardBody() {
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
    .width('100%')
    .padding({ left: $r('app.float.space_card_inner'), right: $r('app.float.space_card_inner') })
  }

  @Builder
  exportCardBody() {
    Column() {
      this.radioRow(Constants.EXPORT_SCOPE_MINE, $r('app.string.export_scope_mine'), this.exportScope === Constants.EXPORT_SCOPE_MINE, (): void => {
        this.exportScope = Constants.EXPORT_SCOPE_MINE;
        ConfigDao.set(Constants.CONFIG_EXPORT_SCOPE, Constants.EXPORT_SCOPE_MINE);
      })
      Divider().color($r('app.color.divider'))
      this.radioRow(Constants.EXPORT_SCOPE_ALL, $r('app.string.export_scope_all'), this.exportScope === Constants.EXPORT_SCOPE_ALL, (): void => {
        this.exportScope = Constants.EXPORT_SCOPE_ALL;
        ConfigDao.set(Constants.CONFIG_EXPORT_SCOPE, Constants.EXPORT_SCOPE_ALL);
      })
    }
    .width('100%')
    .padding({ left: $r('app.float.space_card_inner'), right: $r('app.float.space_card_inner') })
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部栏：50vp 圆形返回 + 居中标题 + 右侧占位（保持对称）
        Row() {
          IconButton({
            icon: '←',
            onTap: (): void => {
              this.popBack();
            }
          })
          Blank()
          Text($r('app.string.settings_title'))
            .fontSize($r('app.float.font_headline'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Row()
            .width($r('app.float.icon_btn_size'))
            .height($r('app.float.icon_btn_size'))
        }
        .width('100%')
        .constraintSize({ maxWidth: ThemeSpec.CONTENT_MAX_WIDTH_VP })
        .height($r('app.float.header_height'))
        .padding({ left: $r('app.float.space_page'), right: $r('app.float.space_page') })

        Scroll() {
          Column() {
            // ---- 拨号 分组卡 ----
            Column() {
              this.sectionLabel($r('app.string.section_call'))
              SemanticMaterialSurface({
                role: MaterialRole.NORMAL_SURFACE,
                emphasis: false,
                radius: $r('app.float.radius_card')
              }) {
                this.dialCardBody()
              }
            }
            .width('100%')
            .opacity(this.appearCard >= 1 ? 1 : 0)
            .translate({ y: this.appearCard >= 1 ? 0 : MotionSpec.ENTRANCE_TRANSLATE })

            // ---- 导出 分组卡 ----
            Column() {
              this.sectionLabel($r('app.string.section_export'))
              SemanticMaterialSurface({
                role: MaterialRole.NORMAL_SURFACE,
                emphasis: false,
                radius: $r('app.float.radius_card')
              }) {
                this.exportCardBody()
              }
            }
            .width('100%')
            .margin({ top: $r('app.float.space_group') })
            .opacity(this.appearCard >= 2 ? 1 : 0)
            .translate({ y: this.appearCard >= 2 ? 0 : MotionSpec.ENTRANCE_TRANSLATE })

            // ---- 信息 卡片 ----
            Column() {
              this.sectionLabel($r('app.string.section_data'))
              SemanticMaterialSurface({
                role: MaterialRole.NORMAL_SURFACE,
                emphasis: false,
                radius: $r('app.float.radius_card')
              }) {
                Row() {
                  Text($r('app.string.section_data'))
                    .fontSize($r('app.float.font_caption'))
                    .fontColor($r('app.color.text_tertiary'))
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
              }
            }
            .width('100%')
            .margin({ top: $r('app.float.space_group') })
            .opacity(this.appearCard >= 3 ? 1 : 0)
            .translate({ y: this.appearCard >= 3 ? 0 : MotionSpec.ENTRANCE_TRANSLATE })

            // ---- 危险 卡片（danger 描边，只重构不加新项）----
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
            .height(52)
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
          .constraintSize({ maxWidth: ThemeSpec.CONTENT_MAX_WIDTH_VP })
          .padding({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), bottom: $r('app.float.space_group') })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
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
