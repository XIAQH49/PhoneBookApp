import { ConfigDao } from '../database/ConfigDao';
import { Constants } from '../common/Constants';

/**
 * 拨号确认弹窗（FR-5 / 评审 P2-8）：支持"不再提示"，勾选后写入配置。
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
      Text(this.name)
        .fontSize(16)
        .margin({ top: 12 })
      Text(this.number)
        .fontSize(16)
        .fontColor('#666666')
        .margin({ top: 4 })
      Row() {
        Checkbox()
          .select(this.dontShowAgain)
          .onChange((v: boolean) => {
            this.dontShowAgain = v;
          })
        Text($r('app.string.dont_show_again')).fontSize(14)
      }
      .margin({ top: 12 })
      Row() {
        Button($r('app.string.cancel'))
          .onClick(() => {
            this.controller.close();
          })
        Button($r('app.string.call'))
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
