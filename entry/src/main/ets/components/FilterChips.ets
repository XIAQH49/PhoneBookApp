/**
 * 状态筛选（FR-4）：全部 / 未打 / 已打。
 * selected 用 @Prop 接收父状态，随父组件重建同步更新。
 */
@Component
export struct FilterChips {
  @Prop selected: number;
  onSelect: (index: number) => void = (index: number) => {
  };

  build() {
    Row() {
      Text($r('app.string.filter_all'))
        .fontSize(14)
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .borderRadius(16)
        .backgroundColor(this.selected === 0 ? '#007DFF' : '#F1F3F5')
        .fontColor(this.selected === 0 ? Color.White : '#182431')
        .onClick(() => {
          this.onSelect(0);
        })
      Text($r('app.string.filter_uncalled'))
        .fontSize(14)
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .borderRadius(16)
        .backgroundColor(this.selected === 1 ? '#007DFF' : '#F1F3F5')
        .fontColor(this.selected === 1 ? Color.White : '#182431')
        .margin({ left: 8 })
        .onClick(() => {
          this.onSelect(1);
        })
      Text($r('app.string.filter_called'))
        .fontSize(14)
        .padding({ left: 14, right: 14, top: 6, bottom: 6 })
        .borderRadius(16)
        .backgroundColor(this.selected === 2 ? '#007DFF' : '#F1F3F5')
        .fontColor(this.selected === 2 ? Color.White : '#182431')
        .margin({ left: 8 })
        .onClick(() => {
          this.onSelect(2);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
  }
}
