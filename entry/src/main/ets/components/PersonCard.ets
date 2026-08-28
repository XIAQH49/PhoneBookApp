import { MotionSpec } from '../common/MotionSpec';
import { MaterialRole } from '../common/ThemeSpec';
import { StatusPill } from './StatusPill';
import { IconButton } from './IconButton';
import { SemanticMaterialSurface } from './SemanticMaterialSurface';

/**
 * 名单宽卡（docs/16 一-5 / 2.6 定稿，单列）：
 * 定高 190vp（docs/16 6.3：定高才能被 LazyForEach 预估尺寸、提前预渲染）、padding 20vp、radius 24vp；
 * 姓名 24fp/Bold + 右上 StatusPill（已打=绿/未打=橙）；号码 18fp（多号码显示"手机 ×N"）；
 * 工号 14fp + 右下圆形拨号钮 50vp（primary 底白图标，独立 onClick 不跳详情）。
 * 卡片点击进详情；语义材质 = normal-surface（不每卡发光）；入场淡入+上移+回弹错峰。
 * 展示串（号码/"手机×N"/状态文案）由父级在视图层预计算后传入（docs/16 6.3：item 只布局）。
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
          btnSize: 50,
          fontSize: 24,
          onTap: (): void => {
            this.onCall();
          }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height($r('app.float.person_card_height'))
    .padding(20)
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
