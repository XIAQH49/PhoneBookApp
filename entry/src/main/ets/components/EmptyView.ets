/**
 * 空态视图（未导入名单时引导导入）。
 */
@Component
export struct EmptyView {
  tip: ResourceStr = '';
  actionText: ResourceStr = '';
  onAction: () => void = () => {
  };

  build() {
    Column() {
      Text('📋').fontSize(48)
      Text(this.tip).fontSize(14).fontColor('#666666').margin({ top: 8 })
      Button(this.actionText).margin({ top: 16 }).onClick(() => {
        this.onAction();
      })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }
}
