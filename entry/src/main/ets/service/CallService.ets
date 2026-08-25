import { common, Want } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';
import { Constants } from '../common/Constants';
import { ConfigDao } from '../database/ConfigDao';

const TAG: string = 'CallService';

/** 拨号结果 */
export interface CallResult {
  success: boolean;
  message: string;
}

/**
 * 唤起系统电话/联系人应用并填入号码（FR-5，v0.3.3）。
 * 设备实测（SGT-AL10 + shell 隐式拉起验证）：
 *   系统电话软件 = com.ohos.contacts，其 MainAbility 注册
 *   ohos.want.action.viewData + scheme 'tel' + entity.system.home；
 *   用 `aa start -A ohos.want.action.viewData -U tel:13800000000 -e entity.system.home` 可成功唤起。
 * 实现：按候选顺序直接 startAbility（viewData+tel 优先，action.dial 兜底），
 * 全部失败则复制号码到剪贴板提示手动粘贴。
 * 注：不采用 queryAbilityByWant 预检——该 API 需 GET_BUNDLE_INFO 权限且已废弃，
 * 无权限时静默失败导致永远走兜底（v0.3.2 的 bug 根因）。
 */
export class CallService {
  static async openDialer(context: common.UIAbilityContext, number: string): Promise<CallResult> {
    const stripRaw: string = await ConfigDao.get(Constants.CONFIG_CALL_STRIP_COUNTRY);
    const dialNumber: string = stripRaw === '1' ? CallService.stripCountry(number) : number;
    const candidates: Want[] = [
      {
        action: 'ohos.want.action.viewData',
        uri: 'tel:' + dialNumber,
        entities: ['entity.system.home']
      },
      {
        action: 'ohos.want.action.dial',
        uri: 'tel:' + dialNumber,
        entities: ['entity.system.home']
      }
    ];
    for (const want of candidates) {
      try {
        await context.startAbility(want);
        return { success: true, message: '' };
      } catch (e) {
        Logger.error(TAG, `startAbility(${want.action}) failed: ${(e as Error).message}`);
        // 尝试下一个候选
      }
    }
    await CallService.copyToClipboard(dialNumber);
    return { success: false, message: '未找到拨号应用，号码已复制，可手动粘贴拨打' };
  }

  /** 去除 +86 前缀（兼容开关用） */
  static stripCountry(number: string): string {
    if (number.startsWith('+86')) {
      return number.substring(3);
    }
    return number;
  }

  static async copyToClipboard(text: string): Promise<void> {
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
    } catch (e) {
      Logger.error(TAG, 'copyToClipboard failed: ' + (e as Error).message);
    }
  }
}
