import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0001;
const APP_TAG: string = 'PhoneBook';

/**
 * hilog 统一封装：全应用使用同一 DOMAIN，便于日志检索（hdc shell hilog | findstr PhoneBook）。
 */
export class Logger {
  static debug(tag: string, msg: string): void {
    hilog.debug(DOMAIN, APP_TAG, '[%{public}s] %{public}s', tag, msg);
  }

  static info(tag: string, msg: string): void {
    hilog.info(DOMAIN, APP_TAG, '[%{public}s] %{public}s', tag, msg);
  }

  static warn(tag: string, msg: string): void {
    hilog.warn(DOMAIN, APP_TAG, '[%{public}s] %{public}s', tag, msg);
  }

  static error(tag: string, msg: string): void {
    hilog.error(DOMAIN, APP_TAG, '[%{public}s] %{public}s', tag, msg);
  }
}
