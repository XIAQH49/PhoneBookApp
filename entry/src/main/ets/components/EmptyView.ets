/**
 * 空态视图（docs/15 3.1；2026-08-29 修订）：
 * - 移除「导入名单」主按钮——导入已收编到底部悬浮操作栏，空态不重复入口，
 *   文案指引用户使用底部工具栏；
 * - 「当前责任人无数据」空态保留「切换责任人」入口（统计卡此时不显示，
 *   底部栏亦无此功能，并非重复）。
 * 注意：底部操作栏仍显示（悬浮于空态之上），本视图底部预留 132vp 避免被遮挡（docs/15 6.4）。
 */
@Component
export struct EmptyView {
  @Prop switchHint: boolean = false;
  tip: ResourceStr = '';
  onSwitch: () => void = () => {
  };

  build() {
    Column() {
      Text('📋').fontSize(48)
      Text(this.tip)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .margin({ top: 12, left: 32, right: 32 })
      if (this.switchHint) {
        Button($r('app.string.assignee_switch_action'))
          .fontSize(15)
          .fontColor($r('app.color.primary'))
          .backgroundColor($r('app.color.primary_soft'))
          .height(48)
          .padding({ left: 28, right: 28 })
          .borderRadius($r('app.float.radius_pill'))
          .margin({ top: 20 })
          .onClick(() => {
            this.onSwitch();
          })
      }
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .padding({ bottom: $r('app.float.grid_bottom_padding') })
  }
}
