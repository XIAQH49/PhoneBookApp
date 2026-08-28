import { MotionSpec } from '../common/MotionSpec';

/**
 * 状态胶囊（docs/16 二：四态语义色，高 34vp、paddingH 14vp、全圆）：
 * kind=0（默认，卡上已打）：真=绿 success（已打）/ 假=橙 warning（未打）；
 * kind=1：真=蓝 primary（打通）/ 假=橙（未打通）；
 * kind=2：真=紫 #7657D9（有意向）/ 假=橙（无意向）。
 * 点击切换无弹窗；动画 scaleX 1→1.06→1、opacity 0.85→1，springMotion(0.30,0.80)。
 */
@Component
export struct StatusPill {
  @Prop active: boolean = false;
  kind: number = 0;
  labelOn: ResourceStr = $r('app.string.status_pill_called');
  labelOff: ResourceStr = $r('app.string.status_pill_uncalled');
  onToggle: () => void = () => {
  };
  @State switching: boolean = false;

  private onFg(): Resource {
    if (this.kind === 1) {
      return $r('app.color.pill_connected_fg');
    }
    if (this.kind === 2) {
      return $r('app.color.pill_intention_fg');
    }
    return $r('app.color.pill_called_fg');
  }

  private offFg(): Resource {
    return $r('app.color.pill_uncalled_fg');
  }

  private onBg(): Resource {
    if (this.kind === 1) {
      return $r('app.color.pill_connected_bg');
    }
    if (this.kind === 2) {
      return $r('app.color.pill_intention_bg');
    }
    return $r('app.color.pill_called_bg');
  }

  private offBg(): Resource {
    return $r('app.color.pill_uncalled_bg');
  }

  build() {
    Text(this.active ? this.labelOn : this.labelOff)
      .fontSize($r('app.float.font_caption'))
      .fontWeight(FontWeight.Medium)
      .fontColor(this.active ? this.onFg() : this.offFg())
      .backgroundColor(this.active ? this.onBg() : this.offBg())
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
