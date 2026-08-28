import { ProgressRing } from './ProgressRing';
import { ThemeSpec } from '../common/ThemeSpec';

/**
 * 统计大卡（docs/14 第 3/4.1 节）：替代旧 StatBar，功能等价（当前责任人 总/已打/未打/完成率 + 全部责任人总计）。
 * 布局：左=大数字+分母，右=完成率圆环；底部三等栏（已打/未打/完成率）+ 全部责任人小计。
 */
@Component
export struct StatCard {
  @Prop total: number = 0;
  @Prop called: number = 0;
  @Prop allTotal: number = 0;
  @Prop allCalled: number = 0;

  private percent(): number {
    return this.total > 0 ? Math.round(this.called * 100 / this.total) : 0;
  }

  @Builder
  metric(value: string, label: ResourceStr) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(label)
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 2 })
    }
    .layoutWeight(1)
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text($r('app.string.stat_called'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
          Row() {
            Text(ThemeSpec.formatThousands(this.called))
              .fontSize($r('app.float.font_display'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary'))
            Text(' / ' + ThemeSpec.formatThousands(this.total))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_hint'))
              .margin({ left: 2, bottom: 4 })
          }
          .alignItems(VerticalAlign.Bottom)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        ProgressRing({ percent: this.percent() })
      }
      .width('100%')

      Divider()
        .color($r('app.color.divider'))
        .margin({ top: 16, bottom: 16 })

      Row() {
        this.metric(ThemeSpec.formatThousands(this.called), $r('app.string.stat_called'))
        this.metric(ThemeSpec.formatThousands(this.total - this.called), $r('app.string.stat_uncalled'))
        this.metric(this.percent() + '%', $r('app.string.stat_rate'))
      }
      .width('100%')

      Text($r('app.string.stat_all_total_hint', this.allTotal, this.allCalled))
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_hint'))
        .margin({ top: 12 })
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .padding($r('app.float.space_card_inner'))
    .borderRadius($r('app.float.radius_card'))
    .backgroundColor($r('app.color.card'))
    .shadow({
      radius: ThemeSpec.SHADOW_CARD_RADIUS,
      color: ThemeSpec.SHADOW_CARD_COLOR,
      offsetX: 0,
      offsetY: ThemeSpec.SHADOW_CARD_OFFSET_Y
    })
    .margin({ left: $r('app.float.space_page'), right: $r('app.float.space_page'), top: 4, bottom: 4 })
  }
}
