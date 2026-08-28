import { MotionSpec } from '../common/MotionSpec';

/**
 * 完成率圆环（docs/14 第 3/5.4 节）：直径 96vp、环宽 8vp；
 * 底色 divider、进度主色、中心显示百分比；
 * 首次挂载弹性生长（springMotion(0.5,0.8)），后续数值变化平滑过渡。
 */
@Component
export struct ProgressRing {
  @Prop @Watch('onPercentChange') percent: number = 0;
  @State sweep: number = 0;
  private firstAppear: boolean = true;

  aboutToAppear(): void {
    this.sweep = 0;
    this.firstAppear = true;
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: MotionSpec.ringGrow() }, () => {
        this.sweep = this.percent;
      });
      this.firstAppear = false;
    }, 120);
  }

  onPercentChange(): void {
    if (this.firstAppear) {
      return;
    }
    this.getUIContext().animateTo({ curve: MotionSpec.pillSwitch() }, () => {
      this.sweep = this.percent;
    });
  }

  build() {
    Stack() {
      Progress({ value: 100, total: 100, type: ProgressType.Ring })
        .width($r('app.float.ring_size'))
        .height($r('app.float.ring_size'))
        .color($r('app.color.divider'))
        .style({ strokeWidth: $r('app.float.ring_width') })
      Progress({ value: this.sweep, total: 100, type: ProgressType.Ring })
        .width($r('app.float.ring_size'))
        .height($r('app.float.ring_size'))
        .color($r('app.color.primary'))
        .style({ strokeWidth: $r('app.float.ring_width') })
      Column() {
        Text(this.percent + '%')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.stat_rate'))
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_hint'))
      }
    }
    .width($r('app.float.ring_size'))
    .height($r('app.float.ring_size'))
  }
}
