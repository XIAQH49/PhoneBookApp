import { router } from '@kit.ArkUI';
import { CallListDao } from '../database/CallListDao';
import { MetaDao } from '../database/MetaDao';
import { ConfigDao } from '../database/ConfigDao';
import { ImportMeta } from '../model/ImportMeta';
import { Constants } from '../common/Constants';

/**
 * 设置页（FR-5 / R-4）：拨号前确认开关、导出范围、数据信息。
 */
@Entry
@Component
struct Settings {
  @State confirmBefore: boolean = true;
  @State exportScope: string = Constants.EXPORT_SCOPE_MINE;
  @State stripCountry: boolean = false;
  @State dataInfo: string = '';

  async aboutToAppear(): Promise<void> {
    const c: string = await ConfigDao.get(Constants.CONFIG_CONFIRM_BEFORE_CALL);
    this.confirmBefore = c !== '0';
    const s: string = await ConfigDao.get(Constants.CONFIG_EXPORT_SCOPE);
    this.exportScope = s === '' ? Constants.EXPORT_SCOPE_MINE : s;
    const sc: string = await ConfigDao.get(Constants.CONFIG_CALL_STRIP_COUNTRY);
    this.stripCountry = sc === '1';
    const total: number = await CallListDao.countAllActive();
    const meta: ImportMeta | undefined = await MetaDao.getActive();
    let info: string = `数据 ${total} 条`;
    if (meta !== undefined) {
      info += `，最近导入：${meta.fileName}`;
    }
    this.dataInfo = info;
  }

  build() {
    Column() {
      Row() {
        Text('← 返回')
          .fontSize(16)
          .onClick(() => {
            router.back();
          })
        Blank()
        Text($r('app.string.settings_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('    ')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Row() {
        Text($r('app.string.confirm_before_call')).fontSize(16)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.confirmBefore })
          .onChange((v: boolean) => {
            this.confirmBefore = v;
            ConfigDao.set(Constants.CONFIG_CONFIRM_BEFORE_CALL, v ? '1' : '0');
          })
      }
      .width('100%')
      .padding(16)

      Row() {
        Text($r('app.string.strip_country_call')).fontSize(16)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.stripCountry })
          .onChange((v: boolean) => {
            this.stripCountry = v;
            ConfigDao.set(Constants.CONFIG_CALL_STRIP_COUNTRY, v ? '1' : '0');
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 16 })

      Text($r('app.string.export_scope'))
        .fontSize(14)
        .fontColor('#999999')
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 4 })
        .textAlign(TextAlign.Start)

      Row() {
        Radio({ value: Constants.EXPORT_SCOPE_MINE, group: 'export_scope' })
          .checked(this.exportScope === Constants.EXPORT_SCOPE_MINE)
          .onChange((v: boolean) => {
            if (v) {
              this.exportScope = Constants.EXPORT_SCOPE_MINE;
              ConfigDao.set(Constants.CONFIG_EXPORT_SCOPE, Constants.EXPORT_SCOPE_MINE);
            }
          })
        Text($r('app.string.export_scope_mine')).fontSize(15)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })

      Row() {
        Radio({ value: Constants.EXPORT_SCOPE_ALL, group: 'export_scope' })
          .checked(this.exportScope === Constants.EXPORT_SCOPE_ALL)
          .onChange((v: boolean) => {
            if (v) {
              this.exportScope = Constants.EXPORT_SCOPE_ALL;
              ConfigDao.set(Constants.CONFIG_EXPORT_SCOPE, Constants.EXPORT_SCOPE_ALL);
            }
          })
        Text($r('app.string.export_scope_all')).fontSize(15)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 6 })

      Text(this.dataInfo)
        .fontSize(12)
        .fontColor('#999999')
        .width('100%')
        .padding({ left: 16, right: 16, top: 24 })
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .height('100%')
  }
}
