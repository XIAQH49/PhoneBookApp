/**
 * 多号码选择半模态（FR-5）：单格多号码时先选号再拨打；支持复制号码。
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
        .margin({ bottom: 12 })
      ForEach(this.numbers, (num: string, i: number) => {
        Row() {
          Text(num).fontSize(16).layoutWeight(1)
          Button($r('app.string.copy_number'))
            .fontSize(13)
            .backgroundColor('#F1F3F5')
            .fontColor('#182431')
            .onClick(() => {
              this.onCopy(i);
            })
          Button($r('app.string.call'))
            .fontSize(14)
            .margin({ left: 8 })
            .onClick(() => {
              this.onPick(i);
            })
        }
        .width('100%')
        .padding(10)
        .borderRadius(8)
        .backgroundColor('#F1F3F5')
        .margin({ bottom: 8 })
      }, (num: string, i: number) => `${num}_${i}`)
    }
    .padding(16)
    .width('100%')
  }
}
