import { MotionSpec } from '../common/MotionSpec';

/**
 * 完成率圆环（docs/15 二-组件规格/5.4；2026-08-30：直径 156→132vp——64fp 大数字行
 * （数字+分母）宽度超过 Column 分配宽度，分母 "/226" 尾部被圆环遮盖（真机实测
 * 分母右缘 x670 > 圆环左缘 x632，重叠 38px）；132vp 后 Column 得余量 46px，不再重叠）：
 * 环宽 12vp；环底 ring_track、进度 primary；中心 Text(0%) 32fp/Bold + Text(完成率) 14fp；
 * animateTo(springMotion(0.65,0.86)) 同一状态变量驱动进度（0%→60% = 0°→216°），不做整圈旋转动画。
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
    this.getUIContext().animateTo({ curve: MotionSpec.ringGrow() }, () => {
      this.sweep = this.percent;
    });
  }

  build() {
    Stack() {
      Progress({ value: 100, total: 100, type: ProgressType.Ring })
        .width($r('app.float.ring_size'))
        .height($r('app.float.ring_size'))
        .color($r('app.color.ring_track'))
        .style({ strokeWidth: $r('app.float.ring_width') })
      Progress({ value: this.sweep, total: 100, type: ProgressType.Ring })
        .width($r('app.float.ring_size'))
        .height($r('app.float.ring_size'))
        .color($r('app.color.primary'))
        .style({ strokeWidth: $r('app.float.ring_width') })
      Column() {
        Text(this.percent + '%')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.stat_rate'))
          .fontSize(14)
          .fontColor($r('app.color.text_tertiary'))
      }
    }
    .width($r('app.float.ring_size'))
    .height($r('app.float.ring_size'))
  }
}
