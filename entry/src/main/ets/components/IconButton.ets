import { MotionSpec } from '../common/MotionSpec';

/**
 * 圆形图标按钮（docs/16 定稿顶栏：搜索/更多/设置三圆钮，运动健康样式）：
 * 50×50vp 全圆、表面半透明底（bar_bg）+ divider 描边 + primary 图标；
 * filled=true 变体（拨号钮）：primary 底 + #FFF 图标；按压 scale 0.92（springMotion(0.32,0.82)）。
 */
@Component
export struct IconButton {
  icon: string = '';
  filled: boolean = false;
  btnSize: number = 50;
  fontSize: number = 24;
  onTap: () => void = () => {
  };
  @State pressed: boolean = false;

  build() {
    Stack() {
      Text(this.icon)
        .fontSize(this.fontSize)
        .fontColor(this.filled ? Color.White : $r('app.color.primary'))
    }
    .width(this.btnSize)
    .height(this.btnSize)
    .borderRadius($r('app.float.radius_pill'))
    .backgroundColor(this.filled ? $r('app.color.primary') : $r('app.color.bar_bg'))
    .border({ width: this.filled ? 0 : 1, color: $r('app.color.divider') })
    .scale({
      x: this.pressed ? MotionSpec.PRESS_SCALE_ICON : 1,
      y: this.pressed ? MotionSpec.PRESS_SCALE_ICON : 1
    })
    .brightness(this.pressed ? 0.9 : 1)
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
