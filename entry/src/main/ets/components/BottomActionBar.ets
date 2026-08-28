import { MotionSpec } from '../common/MotionSpec';
import {
  ThemeSpec, MaterialRole, MaterialLevel, MaterialTokens
} from '../common/ThemeSpec';

/**
 * 底部悬浮毛玻璃工具台（docs/15 二/3.1/5.5）：
 * 高 76vp、paddingH 12、paddingV 8、圆角 28vp；left/right 20vp、底部 safeArea+16vp；
 * 宽 min(720vp, 容器宽−48vp)，不占满全宽；rgba(surface,0.82)+COMPONENT_ULTRA_THICK 毛玻璃
 * + border rgba(255,255,255,0.55) + shadowRadius 28/alpha 0.12/offsetY 8（floating-tool 语义）。
 * 4 个 icon 28vp + label 12fp 按钮（导入名单/内置名单/导出原始文件/导出结果）；
 * 按压 scale 0.94 + offsetY 1vp + 按压项 primary_soft 光斑，释放 responsiveSpringMotion(0.18,0.82,0.06)。
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

  private tokens(): MaterialTokens {
    return ThemeSpec.resolveMaterial(MaterialRole.FLOATING_TOOL, ThemeSpec.materialLevel());
  }

  @Builder
  action(index: number, icon: string, label: ResourceStr, enabled: boolean, handler: () => void) {
    Column() {
      Text(icon)
        .fontSize(28)
        .fontColor($r('app.color.primary'))
      Text(label)
        .fontSize($r('app.float.font_overline'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 2 })
        .maxLines(1)
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height('100%')
    .borderRadius($r('app.float.radius_btn'))
    .backgroundColor(this.pressedIdx === index ? $r('app.color.primary_soft') : Color.Transparent)
    .scale({
      x: this.pressedIdx === index ? MotionSpec.PRESS_SCALE_BTN : 1,
      y: this.pressedIdx === index ? MotionSpec.PRESS_SCALE_BTN : 1
    })
    .translate({ y: this.pressedIdx === index ? MotionSpec.PRESS_OFFSET_Y : 0 })
    .opacity(enabled ? 1 : 0.5)
    .onTouch((e: TouchEvent) => {
      if (!enabled) {
        return;
      }
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ curve: MotionSpec.barRelease() }, () => {
          this.pressedIdx = index;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ curve: MotionSpec.barRelease() }, () => {
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
    .width('calc(100% - 48vp)')
    .constraintSize({ maxWidth: ThemeSpec.BAR_MAX_WIDTH_VP })
    .height($r('app.float.action_bar_height'))
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .borderRadius($r('app.float.radius_bar'))
    .backgroundColor(this.tokens().backgroundColor)
    .backgroundBlurStyle(ThemeSpec.BAR_BLUR)
    .border({
      width: this.tokens().borderWidth,
      color: this.tokens().borderColor
    })
    .shadow({
      radius: this.tokens().shadowRadius,
      color: ThemeSpec.shadowColor(this.tokens().shadowAlpha),
      offsetX: 0,
      offsetY: this.tokens().shadowOffsetY
    })
  }
}
