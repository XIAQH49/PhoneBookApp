import { MotionSpec } from '../common/MotionSpec';

/**
 * 状态筛选胶囊（docs/14 第 3 节改造）：高 36vp 全圆；
 * 未选中=卡片白底 + 分割线描边；选中=主色填充白字；切换带动效（interpolatingSpring）。
 */
@Component
export struct FilterChips {
  @Prop selected: number = 0;
  onSelect: (index: number) => void = (index: number) => {
  };
  @State pressedIdx: number = -1;

  @Builder
  chip(index: number, label: ResourceStr) {
    Text(label)
      .fontSize(14)
      .fontColor(this.selected === index ? Color.White : $r('app.color.text_secondary'))
      .backgroundColor(this.selected === index ? $r('app.color.primary') : $r('app.color.card'))
      .border({
        width: 1,
        color: this.selected === index ? $r('app.color.primary') : $r('app.color.divider')
      })
      .height($r('app.float.chip_height'))
      .padding({ left: 16, right: 16 })
      .borderRadius($r('app.float.radius_pill'))
      .textAlign(TextAlign.Center)
      .margin({ left: index > 0 ? 8 : 0 })
      .scale({
        x: this.pressedIdx === index ? MotionSpec.PRESS_SCALE_BTN : 1,
        y: this.pressedIdx === index ? MotionSpec.PRESS_SCALE_BTN : 1
      })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.getUIContext().animateTo({ curve: MotionSpec.press() }, () => {
            this.pressedIdx = index;
          });
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.getUIContext().animateTo({ curve: MotionSpec.press() }, () => {
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
      this.chip(0, $r('app.string.filter_all'))
      this.chip(1, $r('app.string.filter_uncalled'))
      this.chip(2, $r('app.string.filter_called'))
    }
  }
}
