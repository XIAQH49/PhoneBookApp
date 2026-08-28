import { MotionSpec } from '../common/MotionSpec';

/**
 * 状态筛选胶囊（docs/15 二/3.1：高 40vp、间距 8vp、带计数 [全部 20][未打 8][已打 12]）：
 * 选中 primary 底白字；未选中 surface_card 底 + divider 描边；
 * 选中切换 scale 1→1.03→1（responsiveSpringMotion(0.15,0.86,0.08)）。
 */
@Component
export struct FilterChips {
  @Prop selected: number = 0;
  @Prop total: number = 0;
  @Prop called: number = 0;
  onSelect: (index: number) => void = (index: number) => {
  };
  @State pressedIdx: number = -1;

  private uncalled(): number {
    return this.total - this.called;
  }

  @Builder
  chip(index: number, label: ResourceStr) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.selected === index ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.selected === index ? Color.White : $r('app.color.text_secondary'))
      .backgroundColor(this.selected === index ? $r('app.color.primary') : $r('app.color.surface_card'))
      .border({
        width: 1,
        color: this.selected === index ? $r('app.color.primary') : $r('app.color.divider')
      })
      .height($r('app.float.chip_height'))
      .padding({ left: 16, right: 16 })
      .borderRadius($r('app.float.radius_pill'))
      .textAlign(TextAlign.Center)
      .scale({
        x: this.pressedIdx === index && this.selected === index ? MotionSpec.CHIP_SELECT_SCALE : 1,
        y: this.pressedIdx === index && this.selected === index ? MotionSpec.CHIP_SELECT_SCALE : 1
      })
      .margin({ left: index > 0 ? 8 : 0 })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.getUIContext().animateTo({ curve: MotionSpec.chipSelect() }, () => {
            this.pressedIdx = index;
          });
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.getUIContext().animateTo({ curve: MotionSpec.chipSelect() }, () => {
            this.pressedIdx = -1;
          });
        }
      })
      .onClick(() => {
        this.onSelect(index);
      })
  }

  build() {
    Row() {
      this.chip(0, $r('app.string.chip_all_count', this.total))
      this.chip(1, $r('app.string.chip_uncalled_count', this.uncalled()))
      this.chip(2, $r('app.string.chip_called_count', this.called))
    }
  }
}
