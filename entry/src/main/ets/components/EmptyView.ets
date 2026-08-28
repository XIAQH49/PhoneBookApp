/**
 * 空态视图（docs/15 3.1）：居中插画位（系统 icon 风格 emoji）+ 文案 + 主按钮「导入名单」。
 * 注意：底部操作栏仍显示（悬浮于空态之上），本视图底部预留 132vp 避免按钮被遮挡（docs/15 6.4）。
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
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .margin({ top: 12, left: 32, right: 32 })
      Button($r('app.string.empty_import_action'))
        .fontSize(15)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.primary'))
        .height(48)
        .padding({ left: 28, right: 28 })
        .borderRadius($r('app.float.radius_pill'))
        .margin({ top: 20 })
        .onClick(() => {
          this.onImport();
        })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ bottom: $r('app.float.grid_bottom_padding') })
  }
}
