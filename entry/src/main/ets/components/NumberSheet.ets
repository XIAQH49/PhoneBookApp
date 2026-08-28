import { ThemeSpec } from '../common/ThemeSpec';

/**
 * 多号码选择半模态（FR-5）：单格多号码时先选号再拨打；支持复制号码。
 * v0.7：配色/圆角走设计令牌（卡片行 + 主色拨打）。
 */
@Component
export struct NumberSheet {
  @Link numbers: string[];
  name: string = '';
  onPick: (index: number) => void = (index: number) => {
  };
  onCopy: (index: number) => void = (index: number) => {
  };

  build() {
    Column() {
      Text(this.name !== '' ? `${this.name} · 手机 ×${this.numbers.length}` : '选择号码')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 12 })
      ForEach(this.numbers, (num: string, i: number) => {
        Row() {
          Text(num)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
          Button($r('app.string.copy_number'))
            .fontSize(13)
            .backgroundColor($r('app.color.bg'))
            .fontColor($r('app.color.text_secondary'))
            .borderRadius($r('app.float.radius_btn'))
            .onClick(() => {
              this.onCopy(i);
            })
          Button($r('app.string.call'))
            .fontSize(14)
            .margin({ left: 8 })
            .borderRadius($r('app.float.radius_btn'))
            .onClick(() => {
              this.onPick(i);
            })
        }
        .width('100%')
        .padding(12)
        .borderRadius($r('app.float.radius_item'))
        .backgroundColor($r('app.color.card'))
        .shadow({
          radius: ThemeSpec.SHADOW_CARD_RADIUS,
          color: ThemeSpec.SHADOW_CARD_COLOR,
          offsetX: 0,
          offsetY: ThemeSpec.SHADOW_CARD_OFFSET_Y
        })
        .margin({ bottom: 8 })
      }, (num: string, i: number) => `${num}_${i}`)
    }
    .padding(16)
    .width('100%')
  }
}
