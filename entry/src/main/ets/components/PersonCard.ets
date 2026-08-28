import { MotionSpec } from '../common/MotionSpec';
import { ThemeSpec } from '../common/ThemeSpec';
import { StatusPill } from './StatusPill';

/**
 * 名单双列卡（docs/14 第 3/5.3 节）：
 * 上=姓名（headline）+ 状态胶囊（右上，点击=标记/撤销）；中=手机号；下=工号 + 圆形小拨号钮（右下 40vp）。
 * 卡片整体点击 → 详情；按压 scale 0.96 + brightness 0.9；入场淡入+上移+弹性错峰。
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
  @State pressed: boolean = false;
  @State appear: boolean = false;

  aboutToAppear(): void {
    const delay: number = (this.staggerIndex % 12) * MotionSpec.STAGGER;
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: MotionSpec.entrance() }, () => {
        this.appear = true;
      });
    }, delay);
  }

  build() {
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
    .constraintSize({ minHeight: 128 })
    .padding($r('app.float.space_card_inner'))
    .borderRadius($r('app.float.radius_item'))
    .backgroundColor($r('app.color.card'))
    .shadow({
      radius: ThemeSpec.SHADOW_CARD_RADIUS,
      color: ThemeSpec.SHADOW_CARD_COLOR,
      offsetX: 0,
      offsetY: ThemeSpec.SHADOW_CARD_OFFSET_Y
    })
    .opacity(this.appear ? 1 : 0)
    .translate({ y: this.appear ? 0 : MotionSpec.ENTRANCE_TRANSLATE })
    .scale({
      x: this.pressed ? MotionSpec.PRESS_SCALE_CARD : 1,
      y: this.pressed ? MotionSpec.PRESS_SCALE_CARD : 1
    })
    .brightness(this.pressed ? MotionSpec.PRESS_BRIGHTNESS_CARD : 1)
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ curve: MotionSpec.press() }, () => {
          this.pressed = true;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ curve: MotionSpec.press() }, () => {
          this.pressed = false;
        });
      }
    })
    .onClick(() => {
      this.onOpen();
    })
  }
}
