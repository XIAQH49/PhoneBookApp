/**
 * 空态视图（未导入/当前责任人无数据时的提示）。
 * 注意：
 *  1. 用 layoutWeight(1) 占据剩余空间而不是 height(100%)，避免挤出底部按钮行（v0.5.1 修复）；
 *  2. 不再自带操作按钮——操作统一由页面底部按钮栏（导入名单/内置名单/导出结果）承载，避免重复按钮。
 */
@Component
export struct EmptyView {
  tip: ResourceStr = '';

  build() {
    Column() {
      Text('📋').fontSize(48)
      Text(this.tip).fontSize(14).fontColor('#666666').margin({ top: 8 })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .layoutWeight(1)
  }
}
