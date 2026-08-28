import { MotionSpec } from '../common/MotionSpec';
import { ThemeSpec } from '../common/ThemeSpec';

/**
 * 底部悬浮胶囊操作栏（docs/14 第 3/5.5 节）：高 64vp、左右缩进 16vp、radius_pill、
 * Thick 毛玻璃 + raised 阴影；4 个图标+文字按钮（导入名单/内置名单/导出原始文件/导出结果）。
 * 单页架构：按钮只触发动作不跳页；按压弹性 scale 0.94 + brightness 0.9。
 */
@Component
export struct BottomActionBar {
  @Prop importing: boolean = false;
  @Prop importStage: string = '';
  @Prop exporting: boolean = false;
  onImport: () => void = () => {
  };
  onBuiltin: () => void = () => {
  };
  onExportBuiltin: () => void = () => {
  };
  onExport: () => void = () => {
  };
  @State pressedIdx: number = -1;

  @Builder
  action(index: number, icon: string, label: ResourceStr, enabled: boolean, handler: () => void) {
    Column() {
      Text(icon)
        .fontSize(18)
        .fontColor($r('app.color.primary'))
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 2 })
        .maxLines(1)
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height('100%')
    .scale({
      x: this.pressedIdx === index ? MotionSpec.PRESS_SCALE_BTN : 1,
      y: this.pressedIdx === index ? MotionSpec.PRESS_SCALE_BTN : 1
    })
    .brightness(this.pressedIdx === index ? MotionSpec.PRESS_BRIGHTNESS_CARD : 1)
    .opacity(enabled ? 1 : 0.5)
    .onTouch((e: TouchEvent) => {
      if (!enabled) {
        return;
      }
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ curve: MotionSpec.press() }, () => {
          this.pressedIdx = index;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ curve: MotionSpec.press() }, () => {
          this.pressedIdx = -1;
        });
      }
    })
    .onClick(() => {
      if (enabled) {
        handler();
      }
    })
  }

  build() {
    Row() {
      this.action(0, '＋', this.importing ? this.importStage : $r('app.string.menu_import'), !this.importing, (): void => {
        this.onImport();
      })
      this.action(1, '📦', $r('app.string.menu_builtin'), true, (): void => {
        this.onBuiltin();
      })
      this.action(2, '📄', $r('app.string.menu_export_builtin'), true, (): void => {
        this.onExportBuiltin();
      })
      this.action(3, '⬆', this.exporting ? '导出中…' : $r('app.string.menu_export'), !this.exporting, (): void => {
        this.onExport();
      })
    }
    .width('calc(100% - 32vp)')
    .height($r('app.float.action_bar_height'))
    .padding({ left: 4, right: 4 })
    .borderRadius($r('app.float.radius_pill'))
    .backgroundColor($r('app.color.bar_bg'))
    .backgroundBlurStyle(ThemeSpec.BAR_BLUR)
    .shadow({
      radius: ThemeSpec.SHADOW_RAISED_RADIUS,
      color: ThemeSpec.SHADOW_RAISED_COLOR,
      offsetX: 0,
      offsetY: ThemeSpec.SHADOW_RAISED_OFFSET_Y
    })
  }
}
