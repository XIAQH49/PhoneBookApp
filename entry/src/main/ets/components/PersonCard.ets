import { MotionSpec } from '../common/MotionSpec';
import { MaterialRole } from '../common/ThemeSpec';
import { StatusPill } from './StatusPill';
import { SemanticMaterialSurface } from './SemanticMaterialSurface';

/**
 * 名单卡片（docs/14 第 3/5.3/8 节，固定单列 v0.1.2）：
 * 上=姓名（headline）+ 状态胶囊（右上，点击=标记/撤销）；中=手机号；下=工号 + 圆形小拨号钮（右下 40vp）。
 * 卡片整体点击 → 详情；语义材质 = 未打 featured-surface（EMPHASIS 重点待办）/ 已打 normal-surface；
 * 按压/阴影/边缘光线由 SemanticMaterialSurface 按 MaterialTokens + resolveCardVisualSpec 渲染（8.4 光随指动）。
 * 入场淡入+上移+弹性错峰在外层容器执行（与按压形变通道分离）。
 */
@Component
export struct PersonCard {
  @Prop name: string = '';
  @Prop phoneText: string = '';
  @Prop empNo: string = '';
  @Prop called: boolean = false;
  staggerIndex: number = 0;
  onToggle: () => void = () => {
  };
  onCall: () => void = () => {
  };
  onOpen: () => void = () => {
  };
  @State appear: boolean = false;

  aboutToAppear(): void {
    const delay: number = (this.staggerIndex % 12) * MotionSpec.STAGGER;
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: MotionSpec.entrance() }, () => {
        this.appear = true;
      });
    }, delay);
  }

  @Builder
  cardBody() {
    Column() {
      Row() {
        Text(this.name !== '' ? this.name : '（无姓名）')
          .fontSize($r('app.float.font_headline'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        StatusPill({
          active: this.called,
          onToggle: (): void => {
            this.onToggle();
          }
        })
          .margin({ left: 8 })
      }
      .width('100%')

      Text(this.phoneText)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 8 })

      Row() {
        Text(this.empNo !== '' ? '工号 ' + this.empNo : '')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_hint'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Stack() {
          Text('📞')
            .fontSize(18)
            .fontColor($r('app.color.primary'))
        }
        .width($r('app.float.dial_btn_size'))
        .height($r('app.float.dial_btn_size'))
        .borderRadius($r('app.float.radius_pill'))
        .backgroundColor($r('app.color.primary_soft'))
        .onClick(() => {
          this.onCall();
        })
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .constraintSize({ minHeight: 92 })
    .padding($r('app.float.space_card_inner'))
  }

  build() {
    Column() {
      SemanticMaterialSurface({
        role: this.called ? MaterialRole.NORMAL_SURFACE : MaterialRole.FEATURED_SURFACE,
        emphasis: !this.called,
        radius: $r('app.float.radius_item'),
        onTap: (): void => {
          this.onOpen();
        }
      }) {
        this.cardBody()
      }
    }
    .width('100%')
    .opacity(this.appear ? 1 : 0)
    .translate({ y: this.appear ? 0 : MotionSpec.ENTRANCE_TRANSLATE })
  }
}
