import { ProgressRing } from './ProgressRing';
import { ThemeSpec } from '../common/ThemeSpec';
import { SemanticMaterialSurface } from './SemanticMaterialSurface';
import { MaterialRole } from '../common/ThemeSpec';

/**
 * 统计大卡（docs/15 二/3.1/九-3：首页唯一最高等级卡）：
 * 高 280vp、featured-surface（EMPHASIS 语义材质 + 光线勾勒）；
 * 上半：左 已打 64fp 大数字 + /分母，右 ProgressRing；
 * 下半三等分 已打/未打/完成率；底部 当前责任人：张三 · 共N条 + 全部责任人小计。
 */
@Component
export struct StatCard {
  @Prop total: number = 0;
  @Prop called: number = 0;
  @Prop allTotal: number = 0;
  @Prop allCalled: number = 0;
  @Prop assignee: string = '';

  private percent(): number {
    return this.total > 0 ? Math.round(this.called * 100 / this.total) : 0;
  }

  private assigneeLabel(): string {
    return this.assignee === '' ? '未分配' : this.assignee;
  }

  @Builder
  metric(value: string, label: ResourceStr) {
    Column() {
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(label)
        .fontSize($r('app.float.font_overline'))
        .fontColor($r('app.color.text_tertiary'))
        .margin({ top: 2 })
    }
    .layoutWeight(1)
  }

  @Builder
  cardBody() {
    Column() {
      Row() {
        Column() {
          Text($r('app.string.stat_called'))
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
          Row() {
            Text(ThemeSpec.formatThousands(this.called))
              .fontSize($r('app.float.font_display_xl'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary'))
            Text(' / ' + ThemeSpec.formatThousands(this.total))
              .fontSize($r('app.float.font_caption'))
              .fontColor($r('app.color.text_tertiary'))
              .margin({ left: 2, bottom: 8 })
          }
          .alignItems(VerticalAlign.Bottom)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        ProgressRing({ percent: this.percent() })
      }
      .width('100%')
      .height(156)

      Divider()
        .color($r('app.color.divider'))
        .margin({ top: 12, bottom: 12 })

      Row() {
        this.metric(ThemeSpec.formatThousands(this.called), $r('app.string.stat_called'))
        this.metric(ThemeSpec.formatThousands(this.total - this.called), $r('app.string.stat_uncalled'))
        this.metric(this.percent() + '%', $r('app.string.stat_rate'))
      }
      .width('100%')

      Text($r('app.string.stat_assignee_hint', this.assigneeLabel(), this.total))
        .fontSize($r('app.float.font_overline'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 14 })
        .width('100%')
        .textAlign(TextAlign.Center)
      Text($r('app.string.stat_all_total_hint', this.allTotal, this.allCalled))
        .fontSize($r('app.float.font_overline'))
        .fontColor($r('app.color.text_tertiary'))
        .margin({ top: 2 })
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .constraintSize({ minHeight: $r('app.float.stat_card_height') })
    .padding($r('app.float.space_card_inner'))
  }

  build() {
    SemanticMaterialSurface({
      role: MaterialRole.FEATURED_SURFACE,
      emphasis: true,
      interactive: false,
      radius: $r('app.float.radius_feature')
    }) {
      this.cardBody()
    }
  }
}
