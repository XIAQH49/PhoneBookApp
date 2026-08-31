import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DbHelper } from '../database/DbHelper';
import { ThemeSpec } from '../common/ThemeSpec';
import { IntentImportService } from '../service/IntentImportService';
import type { IntentImportResult } from '../service/IntentImportService';

const DOMAIN = 0x0000;

/** 系统栏底色（与资源 app.color.bg_page 双套保持一致，docs/16 6.2：无白边/黑边） */
const BAR_BG_LIGHT: string = '#F4F6F8';
const BAR_BG_DARK: string = '#101214';

export default class EntryAbility extends UIAbility {
  private winStage: window.WindowStage | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    hilog.info(DOMAIN, 'PhoneBook', 'onCreate want: %{public}s', JSON.stringify(want));
    // 官方沉浸光感门控（API 26 uiMaterial.getMaterialInfo）：系统关闭沉浸时应用降级（页面加载前调用）
    ThemeSpec.initImmersiveGate();
    // 初始化本地数据库（幂等），页面加载前完成
    DbHelper.init(this.context).then(() => {
      hilog.info(DOMAIN, 'PhoneBook', 'Database ready');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'PhoneBook', 'Database init failed: %{public}s', err.message);
    });
    // v0.6 PC 意图直达导入：冷启动路径（payload 参数存在时接收）
    IntentImportService.handleWant(this.context, want).then((r: IntentImportResult): void => {
      if (r.message !== '') {
        hilog.info(DOMAIN, 'PhoneBook', 'intent(cold) result: ok=%{public}s msg=%{public}s total=%{public}d',
          r.success, r.message, r.total);
      }
    }).catch((e: Error) => {
      hilog.error(DOMAIN, 'PhoneBook', 'intent(cold) failed: %{public}s', e.message);
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  /**
   * 系统栏融合（docs/16 6.2，无白边/黑边）：
   * 仅设置状态栏（底色=页面同色浅 #F4F6F8/深 #101214 + 图标随深浅色）；
   * 不设置导航栏属性（真机实测：设置 navigationBarColor 会强制弹出底部导航条且颜色不生效，反而产生白边）；
   * 内容层保持系统安全区避让（ArkUI 默认），绝不重叠。
   */
  private async setImmersive(stage: window.WindowStage): Promise<void> {
    try {
      const win: window.Window = stage.getMainWindowSync();
      const dark: boolean = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      const props: window.SystemBarProperties = {
        statusBarColor: dark ? BAR_BG_DARK : BAR_BG_LIGHT,
        statusBarContentColor: dark ? '#FFFFFF' : '#000000'
      };
      await win.setWindowSystemBarProperties(props);
    } catch (err) {
      hilog.error(DOMAIN, 'PhoneBook', 'set system bar failed: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.winStage = windowStage;

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      this.setImmersive(windowStage).catch((e: Error) => {
        hilog.error(DOMAIN, 'PhoneBook', 'set system bar init failed: %{public}s', e.message);
      });
    });
  }

  /**
   * v0.6 PC 意图直达导入：热启动路径。
   * 设备默认为 singleton 启动模式，App 已在前台时 aa start 回调本方法（不重建页面）。
   */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'PhoneBook', 'onNewWant: %{public}s', JSON.stringify(want));
    IntentImportService.handleWant(this.context, want).then((r: IntentImportResult): void => {
      if (r.message !== '') {
        hilog.info(DOMAIN, 'PhoneBook', 'intent(hot) result: ok=%{public}s msg=%{public}s total=%{public}d',
          r.success, r.message, r.total);
      }
    }).catch((e: Error) => {
      hilog.error(DOMAIN, 'PhoneBook', 'intent(hot) failed: %{public}s', e.message);
    });
  }

  /** 深浅色切换时同步系统栏底色与图标颜色 */
  onConfigurationUpdate(newConfig: Configuration): void {
    if (this.winStage !== undefined) {
      this.setImmersive(this.winStage).catch((e: Error) => {
        hilog.error(DOMAIN, 'PhoneBook', 'config system bar failed: %{public}s', e.message);
      });
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
