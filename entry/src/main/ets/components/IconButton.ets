import { MotionSpec } from '../common/MotionSpec';

/**
 * 图标按钮（v0.7 视觉反馈 #4/#5 统一版）：无背景纯图标（primary 色），
 * 尺寸默认 50vp；按压 scale 0.92（springMotion(0.32,0.82)）。
 * 全页面统一：顶栏 ⚙/🔍、子页 ← 均用本组件，不再使用带底色圆形按钮。
 */
@Component
export struct IconButton {
  icon: string = '';
  btnSize: number = 40;
  fontSize: number = 24;
  onTap: () => void = () => {
  };
  @State pressed: boolean = false;

  build() {
    Stack() {
      Text(this.icon)
        .fontSize(this.fontSize)
        .fontColor($r('app.color.primary'))
    }
    .width(this.btnSize)
    .height(this.btnSize)
    .scale({
      x: this.pressed ? MotionSpec.PRESS_SCALE_ICON : 1,
      y: this.pressed ? MotionSpec.PRESS_SCALE_ICON : 1
    })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ curve: MotionSpec.iconPress() }, () => {
          this.pressed = true;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ curve: MotionSpec.iconPress() }, () => {
          this.pressed = false;
        });
      }
    })
    .onClick(() => {
      this.onTap();
    })
  }
}
