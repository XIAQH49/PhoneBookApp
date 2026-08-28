/**
 * 空态视图（docs/14 4.1）：居中插画位（系统 icon 风格 emoji）+ 文案 + 主按钮「导入名单」。
 * 注意：底部操作栏仍显示（悬浮于空态之上），本视图底部预留操作栏高度避免按钮被遮挡。
 */
@Component
export struct EmptyView {
  tip: ResourceStr = '';
  onImport: () => void = () => {
  };

  build() {
    Column() {
      Text('📋').fontSize(48)
      Text(this.tip)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .margin({ top: 8, left: 32, right: 32 })
      Button($r('app.string.empty_import_action'))
        .fontSize(15)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.primary'))
        .height(44)
        .padding({ left: 28, right: 28 })
        .borderRadius($r('app.float.radius_pill'))
        .margin({ top: 16 })
        .onClick(() => {
          this.onImport();
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ bottom: 96 })
  }
}
