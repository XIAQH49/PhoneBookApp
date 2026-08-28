import { ConfigDao } from '../database/ConfigDao';
import { Constants } from '../common/Constants';

/**
 * 拨号确认弹窗（FR-5 / 评审 P2-8）：支持"不再提示"，勾选后写入配置。
 * v0.7：配色/圆角走设计令牌。
 */
@CustomDialog
export struct CallConfirmDialog {
  controller: CustomDialogController;
  name: string = '';
  number: string = '';
  onConfirm: () => void = () => {
  };
  @State dontShowAgain: boolean = false;

  build() {
    Column() {
      Text($r('app.string.dial_confirm_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(this.name)
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 12 })
      Text(this.number)
        .fontSize($r('app.float.font_body'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 4 })
      Row() {
        Checkbox()
          .select(this.dontShowAgain)
          .onChange((v: boolean) => {
            this.dontShowAgain = v;
          })
        Text($r('app.string.dont_show_again'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .margin({ top: 12 })
      Row() {
        Button($r('app.string.cancel'))
          .backgroundColor($r('app.color.bg'))
          .fontColor($r('app.color.text_secondary'))
          .borderRadius($r('app.float.radius_btn'))
          .onClick(() => {
            this.controller.close();
          })
        Button($r('app.string.call'))
          .margin({ left: 12 })
          .borderRadius($r('app.float.radius_btn'))
          .onClick(() => {
            if (this.dontShowAgain) {
              ConfigDao.set(Constants.CONFIG_CONFIRM_BEFORE_CALL, '0');
            }
            this.onConfirm();
            this.controller.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ top: 16 })
    }
    .padding(20)
  }
}
