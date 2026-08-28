import { MotionSpec } from '../common/MotionSpec';

/**
 * 状态筛选胶囊（docs/15 二/3.1：高 40vp、间距 8vp、带计数 [全部 20][未打 8][已打 12]）：
 * 选中 primary 底白字；未选中 surface_card 底 + divider 描边；
 * 选中切换 scale 1→1.03→1（responsiveSpringMotion(0.15,0.86,0.08)）。
 * 注意（真机实测坑位）：@Builder 传参在本设备上参数固化，计数一律无参 @Builder 直读 this。
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
  chipAll() {
    Text($r('app.string.chip_all_count', this.total))
      .fontSize(14)
      .fontWeight(this.selected === 0 ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.selected === 0 ? Color.White : $r('app.color.text_secondary'))
      .backgroundColor(this.selected === 0 ? $r('app.color.primary') : $r('app.color.surface_card'))
      .border({
        width: 1,
        color: this.selected === 0 ? $r('app.color.primary') : $r('app.color.divider')
      })
      .height($r('app.float.chip_height'))
      .padding({ left: 16, right: 16 })
      .borderRadius($r('app.float.radius_pill'))
      .textAlign(TextAlign.Center)
      .scale({
        x: this.pressedIdx === 0 && this.selected === 0 ? MotionSpec.CHIP_SELECT_SCALE : 1,
        y: this.pressedIdx === 0 && this.selected === 0 ? MotionSpec.CHIP_SELECT_SCALE : 1
      })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.getUIContext().animateTo({ curve: MotionSpec.chipSelect() }, () => {
            this.pressedIdx = 0;
          });
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.getUIContext().animateTo({ curve: MotionSpec.chipSelect() }, () => {
            this.pressedIdx = -1;
          });
        }
      })
      .onClick(() => {
        this.onSelect(0);
      })
  }

  @Builder
  chipUncalled() {
    Text($r('app.string.chip_uncalled_count', this.uncalled()))
      .fontSize(14)
      .fontWeight(this.selected === 1 ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.selected === 1 ? Color.White : $r('app.color.text_secondary'))
      .backgroundColor(this.selected === 1 ? $r('app.color.primary') : $r('app.color.surface_card'))
      .border({
        width: 1,
        color: this.selected === 1 ? $r('app.color.primary') : $r('app.color.divider')
      })
      .height($r('app.float.chip_height'))
      .padding({ left: 16, right: 16 })
      .borderRadius($r('app.float.radius_pill'))
      .textAlign(TextAlign.Center)
      .scale({
        x: this.pressedIdx === 1 && this.selected === 1 ? MotionSpec.CHIP_SELECT_SCALE : 1,
        y: this.pressedIdx === 1 && this.selected === 1 ? MotionSpec.CHIP_SELECT_SCALE : 1
      })
      .margin({ left: 8 })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.getUIContext().animateTo({ curve: MotionSpec.chipSelect() }, () => {
            this.pressedIdx = 1;
          });
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.getUIContext().animateTo({ curve: MotionSpec.chipSelect() }, () => {
            this.pressedIdx = -1;
          });
        }
      })
      .onClick(() => {
        this.onSelect(1);
      })
  }

  @Builder
  chipCalled() {
    Text($r('app.string.chip_called_count', this.called))
      .fontSize(14)
      .fontWeight(this.selected === 2 ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.selected === 2 ? Color.White : $r('app.color.text_secondary'))
      .backgroundColor(this.selected === 2 ? $r('app.color.primary') : $r('app.color.surface_card'))
      .border({
        width: 1,
        color: this.selected === 2 ? $r('app.color.primary') : $r('app.color.divider')
      })
      .height($r('app.float.chip_height'))
      .padding({ left: 16, right: 16 })
      .borderRadius($r('app.float.radius_pill'))
      .textAlign(TextAlign.Center)
      .scale({
        x: this.pressedIdx === 2 && this.selected === 2 ? MotionSpec.CHIP_SELECT_SCALE : 1,
        y: this.pressedIdx === 2 && this.selected === 2 ? MotionSpec.CHIP_SELECT_SCALE : 1
      })
      .margin({ left: 8 })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.getUIContext().animateTo({ curve: MotionSpec.chipSelect() }, () => {
            this.pressedIdx = 2;
          });
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.getUIContext().animateTo({ curve: MotionSpec.chipSelect() }, () => {
            this.pressedIdx = -1;
          });
        }
      })
      .onClick(() => {
        this.onSelect(2);
      })
  }

  build() {
    Row() {
      this.chipAll()
      this.chipUncalled()
      this.chipCalled()
    }
  }
}
