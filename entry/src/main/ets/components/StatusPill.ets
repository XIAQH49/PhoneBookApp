import { MotionSpec } from '../common/MotionSpec';

/**
 * 状态胶囊（docs/15 二-组件规格）：高 34vp、paddingH 14vp、全圆；
 * 未打底 #FFF4E2 字 #E89000（pill_uncalled_*）；已打底 #EAF9F1 字 #159B5A（pill_called_*）。
 * 点击切换无弹窗；动画 scaleX 1→1.06→1、opacity 0.85→1，springMotion(0.30,0.80)。
 */
@Component
export struct StatusPill {
  @Prop active: boolean = false;
  labelOn: ResourceStr = $r('app.string.status_pill_called');
  labelOff: ResourceStr = $r('app.string.status_pill_uncalled');
  onToggle: () => void = () => {
  };
  @State switching: boolean = false;

  build() {
    Text(this.active ? this.labelOn : this.labelOff)
      .fontSize($r('app.float.font_caption'))
      .fontWeight(FontWeight.Medium)
      .fontColor(this.active ? $r('app.color.pill_called_fg') : $r('app.color.pill_uncalled_fg'))
      .backgroundColor(this.active ? $r('app.color.pill_called_bg') : $r('app.color.pill_uncalled_bg'))
      .height($r('app.float.pill_height'))
      .padding({ left: 14, right: 14 })
      .borderRadius($r('app.float.radius_pill'))
      .textAlign(TextAlign.Center)
      .scale({ x: this.switching ? MotionSpec.PILL_SELECT_SCALE : 1, y: 1 })
      .opacity(this.switching ? 0.85 : 1)
      .onClick(() => {
        this.getUIContext().animateTo({ curve: MotionSpec.pillSwitch() }, () => {
          this.switching = true;
        });
        setTimeout(() => {
          this.getUIContext().animateTo({ curve: MotionSpec.pillSwitch() }, () => {
            this.switching = false;
          });
        }, 120);
        this.onToggle();
      })
  }
}
