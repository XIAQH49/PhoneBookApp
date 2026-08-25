/**
 * 进度统计条（FR-4）：当前责任人 总/已打/未打 + 完成百分比；附全部责任人总计行。
 * 全部参数用 @Prop 接收父状态，随父组件重建同步更新。
 */
@Component
export struct StatBar {
  @Prop total: number;
  @Prop called: number;
  @Prop allTotal: number;
  @Prop allCalled: number;

  build() {
    Column() {
      Row() {
        Text(`共 ${this.total}`).fontSize(13).fontColor('#666666')
        Text(`已打 ${this.called}`).fontSize(13).fontColor('#007DFF')
        Text(`未打 ${this.total - this.called}`).fontSize(13).fontColor('#666666')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)

      Progress({
        value: this.total > 0 ? Math.round(this.called * 100 / this.total) : 0,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(4)
        .margin({ top: 6 })

      Text(this.total > 0 ? `完成 ${Math.round(this.called * 100 / this.total)}%` : '完成 0%')
        .fontSize(11)
        .fontColor('#999999')

      Text(`全部责任人：共 ${this.allTotal} 条 · 已打 ${this.allCalled} 条`)
        .fontSize(11)
        .fontColor('#999999')
        .margin({ top: 2 })
    }
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }
}
