import { MotionSpec } from '../common/MotionSpec';

/**
 * 圆形图标按钮（docs/14 第 3 节）：48vp 圆形、主色浅底 + 主色图标；
 * 按压 scale 0.9 + brightness 0.85（interpolatingSpring 跟手）。
 */
@Component
export struct IconButton {
  icon: string = '';
  btnSize: Resource = $r('app.float.icon_btn_size');
  onTap: () => void = () => {
  };
  @State pressed: boolean = false;

  build() {
    Stack() {
      Text(this.icon)
        .fontSize(18)
        .fontColor($r('app.color.primary'))
    }
    .width(this.btnSize)
    .height(this.btnSize)
    .borderRadius($r('app.float.radius_pill'))
    .backgroundColor($r('app.color.primary_soft'))
    .scale({
      x: this.pressed ? MotionSpec.PRESS_SCALE_ICON : 1,
      y: this.pressed ? MotionSpec.PRESS_SCALE_ICON : 1
    })
    .brightness(this.pressed ? MotionSpec.PRESS_BRIGHTNESS_ICON : 1)
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ curve: MotionSpec.press() }, () => {
          this.pressed = true;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ curve: MotionSpec.press() }, () => {
          this.pressed = false;
        });
      }
    })
    .onClick(() => {
      this.onTap();
    })
  }
}
