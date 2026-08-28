import { MotionSpec } from '../common/MotionSpec';

/**
 * 圆形图标按钮（docs/15 二-组件规格）：50×50vp 圆 25vp、icon 24vp；
 * 主操作 = primary_soft 底 + primary 图标；filled = primary 底 + #FFF 图标（拨号）；
 * 按压 scale 0.92，springMotion(0.32,0.82)。
 */
@Component
export struct IconButton {
  icon: string = '';
  filled: boolean = false;
  btnSize: Resource = $r('app.float.icon_btn_size');
  onTap: () => void = () => {
  };
  @State pressed: boolean = false;

  build() {
    Stack() {
      Text(this.icon)
        .fontSize(24)
        .fontColor(this.filled ? Color.White : $r('app.color.primary'))
    }
    .width(this.btnSize)
    .height(this.btnSize)
    .borderRadius($r('app.float.radius_pill'))
    .backgroundColor(this.filled ? $r('app.color.primary') : $r('app.color.primary_soft'))
    .scale({
      x: this.pressed ? MotionSpec.PRESS_SCALE_ICON : 1,
      y: this.pressed ? MotionSpec.PRESS_SCALE_ICON : 1
    })
    .brightness(this.pressed ? 0.85 : 1)
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
