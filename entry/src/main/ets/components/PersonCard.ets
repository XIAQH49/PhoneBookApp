import { MotionSpec } from '../common/MotionSpec';
import { MaterialRole } from '../common/ThemeSpec';
import { StatusPill } from './StatusPill';
import { IconButton } from './IconButton';
import { SemanticMaterialSurface } from './SemanticMaterialSurface';

/**
 * 名单卡片（docs/15 二/3.1：核心组件，双列高 190vp、padding 20vp、radius 24vp）：
 * 姓名 24fp/Bold + 右上 StatusPill；号码 18fp/Medium；工号 14fp + 右下拨号 IconButton 50×50（primary 底白 icon）。
 * 卡片空白点击进详情、拨号只拨号（校对#5：独立 onClick，不用 stopPropagation）。
 * 语义材质 = normal-surface（别做清单1：不给每张卡加发光）；按压/阴影由 SemanticMaterialSurface 渲染。
 * 5.1 入场：opacity 0→1 / translateY 18→0 / scale 0.985→1，springMotion(0.42,0.84)，错峰 i*35ms（≤280ms）。
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
    const delay: number = Math.min(this.staggerIndex * MotionSpec.STAGGER, MotionSpec.STAGGER_MAX);
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
      .alignItems(VerticalAlign.Center)

      Text(this.phoneText)
        .fontSize($r('app.float.font_body_lg'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 10 })

      Row() {
        Text(this.empNo !== '' ? '工号 ' + this.empNo : '')
          .fontSize(14)
          .fontColor($r('app.color.text_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        IconButton({
          icon: '📞',
          filled: true,
          onTap: (): void => {
            this.onCall();
          }
        })
      }
      .width('100%')
      .margin({ top: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height($r('app.float.person_card_height'))
    .padding($r('app.float.space_card_inner'))
    .justifyContent(FlexAlign.SpaceBetween)
  }

  build() {
    Column() {
      SemanticMaterialSurface({
        role: MaterialRole.NORMAL_SURFACE,
        emphasis: false,
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
    .scale({ x: this.appear ? 1 : 0.985, y: this.appear ? 1 : 0.985 })
  }
}
