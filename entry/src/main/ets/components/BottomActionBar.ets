import { MotionSpec } from '../common/MotionSpec';
import {
  ThemeSpec, MaterialRole, MaterialTokens
} from '../common/ThemeSpec';

/**
 * 底部悬浮毛玻璃工具台（docs/15 二/3.1/5.5）：
 * 高 76vp、paddingH 12、paddingV 8、圆角 28vp；left/right 20vp、底部 safeArea+16vp；
 * 宽 min(720vp, 容器宽−48vp)，不占满全宽；rgba(surface,0.82)+COMPONENT_ULTRA_THICK 毛玻璃
 * + border rgba(255,255,255,0.55) + shadowRadius 28/alpha 0.12/offsetY 8（floating-tool 语义）。
 * 4 个 icon 28vp + label 12fp 按钮（导入名单/内置名单/导出原始文件/导出结果）；
 * 按压 scale 0.94 + offsetY 1vp + 按压项 primary_soft 光斑，释放 responsiveSpringMotion(0.18,0.82,0.06)。
 * 注意（真机实测坑位）：@Builder 传参在本设备上参数固化，按钮状态一律无参 @Builder 直读 this。
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
  actionImport() {
    Column() {
      Text('＋')
        .fontSize(28)
        .fontColor($r('app.color.primary'))
      Text(this.importing ? this.importStage : $r('app.string.menu_import'))
        .fontSize($r('app.float.font_overline'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 2 })
        .maxLines(1)
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height('100%')
    .scale({
      x: this.pressedIdx === 0 ? MotionSpec.PRESS_SCALE_BTN : 1,
      y: this.pressedIdx === 0 ? MotionSpec.PRESS_SCALE_BTN : 1
    })
    .translate({ y: this.pressedIdx === 0 ? MotionSpec.PRESS_OFFSET_Y : 0 })
    .opacity(this.importing ? 0.5 : 1)
    .onTouch((e: TouchEvent) => {
      if (this.importing) {
        return;
      }
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ curve: MotionSpec.barRelease() }, () => {
          this.pressedIdx = 0;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ curve: MotionSpec.barRelease() }, () => {
          this.pressedIdx = -1;
        });
      }
    })
    .onClick(() => {
      if (!this.importing) {
        this.onImport();
      }
    })
  }

  @Builder
  actionBuiltin() {
    Column() {
      Text('📦')
        .fontSize(28)
        .fontColor($r('app.color.primary'))
      Text($r('app.string.menu_builtin'))
        .fontSize($r('app.float.font_overline'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 2 })
        .maxLines(1)
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height('100%')
    .scale({
      x: this.pressedIdx === 1 ? MotionSpec.PRESS_SCALE_BTN : 1,
      y: this.pressedIdx === 1 ? MotionSpec.PRESS_SCALE_BTN : 1
    })
    .translate({ y: this.pressedIdx === 1 ? MotionSpec.PRESS_OFFSET_Y : 0 })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ curve: MotionSpec.barRelease() }, () => {
          this.pressedIdx = 1;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ curve: MotionSpec.barRelease() }, () => {
          this.pressedIdx = -1;
        });
      }
    })
    .onClick(() => {
      this.onBuiltin();
    })
  }

  @Builder
  actionExportBuiltin() {
    Column() {
      Text('📄')
        .fontSize(28)
        .fontColor($r('app.color.primary'))
      Text($r('app.string.menu_export_builtin'))
        .fontSize($r('app.float.font_overline'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 2 })
        .maxLines(1)
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height('100%')
    .scale({
      x: this.pressedIdx === 2 ? MotionSpec.PRESS_SCALE_BTN : 1,
      y: this.pressedIdx === 2 ? MotionSpec.PRESS_SCALE_BTN : 1
    })
    .translate({ y: this.pressedIdx === 2 ? MotionSpec.PRESS_OFFSET_Y : 0 })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ curve: MotionSpec.barRelease() }, () => {
          this.pressedIdx = 2;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ curve: MotionSpec.barRelease() }, () => {
          this.pressedIdx = -1;
        });
      }
    })
    .onClick(() => {
      this.onExportBuiltin();
    })
  }

  @Builder
  actionExport() {
    Column() {
      Text('⬆')
        .fontSize(28)
        .fontColor($r('app.color.primary'))
      Text(this.exporting ? '导出中…' : $r('app.string.menu_export'))
        .fontSize($r('app.float.font_overline'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 2 })
        .maxLines(1)
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height('100%')
    .scale({
      x: this.pressedIdx === 3 ? MotionSpec.PRESS_SCALE_BTN : 1,
      y: this.pressedIdx === 3 ? MotionSpec.PRESS_SCALE_BTN : 1
    })
    .translate({ y: this.pressedIdx === 3 ? MotionSpec.PRESS_OFFSET_Y : 0 })
    .opacity(this.exporting ? 0.5 : 1)
    .onTouch((e: TouchEvent) => {
      if (this.exporting) {
        return;
      }
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ curve: MotionSpec.barRelease() }, () => {
          this.pressedIdx = 3;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ curve: MotionSpec.barRelease() }, () => {
          this.pressedIdx = -1;
        });
      }
    })
    .onClick(() => {
      if (!this.exporting) {
        this.onExport();
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Row() {
        this.actionImport()
        this.actionBuiltin()
        this.actionExportBuiltin()
        this.actionExport()
      }
      .width('calc(100% - 48vp)')
      .constraintSize({ maxWidth: ThemeSpec.BAR_MAX_WIDTH_VP })
      .height($r('app.float.action_bar_height'))
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .borderRadius($r('app.float.radius_bar'))
      .backgroundColor(ThemeSpec.immersiveEnabled ? this.tokens().backgroundColor : $r('app.color.surface_card'))
      .backdropBlur(ThemeSpec.immersiveEnabled ? ThemeSpec.BAR_BLUR_RADIUS : 0)
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

      // 玻璃顶缘反射带（环境光反射：白 0.42 → 0，与玻璃同圆角）
      Stack()
        .width('calc(100% - 48vp)')
        .constraintSize({ maxWidth: ThemeSpec.BAR_MAX_WIDTH_VP })
        .height(12)
        .borderRadius($r('app.float.radius_bar'))
        .linearGradient({
          angle: 270,
          colors: [[ThemeSpec.REFLECT_COLOR, 0.0], ['rgba(255,255,255,0)', 1.0]]
        })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
  }
}
