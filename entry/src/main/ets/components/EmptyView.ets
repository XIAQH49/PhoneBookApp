/**
 * 空态视图（未导入名单时引导导入）。
 * 注意：用 layoutWeight(1) 占据剩余空间而不是 height(100%)，
 * 避免把页面底部的操作按钮行挤出可视区（v0.5.1 bug 修复）。
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
    .layoutWeight(1)
  }
}
