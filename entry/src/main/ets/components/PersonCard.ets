import { MotionSpec } from '../common/MotionSpec';
import { MaterialRole } from '../common/ThemeSpec';
import { StatusPill } from './StatusPill';
import { SemanticMaterialSurface } from './SemanticMaterialSurface';

/**
 * 名单卡片（v0.7 视觉反馈 #1/#8 修订版）：
 * **固定单列**、紧凑高度（min 132vp，不再双列 190vp——双列下姓名被截断）；
 * 姓名 24fp/Bold（单列全宽显示）+ 右上 StatusPill；号码 18fp；工号 14fp + **无背景拨号图标**（纯 📞 primary）。
 * 卡片空白点击进详情、拨号只拨号（独立 onClick）。
 * 语义材质 = normal-surface（不每卡发光）；入场淡入+上移+回弹错峰。
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
        .margin({ top: 8 })

      Row() {
        Text(this.empNo !== '' ? '工号 ' + this.empNo : '')
          .fontSize(14)
          .fontColor($r('app.color.text_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        // 无背景拨号图标（视觉反馈 #8）
        Text('📞')
          .fontSize(24)
          .fontColor($r('app.color.primary'))
          .padding({ left: 12, top: 4, bottom: 4 })
          .onClick(() => {
            this.onCall();
          })
      }
      .width('100%')
      .margin({ top: 6 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .constraintSize({ minHeight: $r('app.float.person_card_height') })
    .padding(16)
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
