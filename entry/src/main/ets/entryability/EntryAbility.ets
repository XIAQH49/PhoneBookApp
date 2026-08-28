import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DbHelper } from '../database/DbHelper';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private winStage: window.WindowStage | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    // 初始化本地数据库（幂等），页面加载前完成
    DbHelper.init(this.context).then(() => {
      hilog.info(DOMAIN, 'PhoneBook', 'Database ready');
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'PhoneBook', 'Database init failed: %{public}s', err.message);
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  /**
   * 沉浸式系统栏（docs/16 6.2 硬性要求，无白边/黑边）：
   * 窗口全屏布局 + 状态栏/导航栏透明 + 图标颜色随深浅色。
   * 根组件在安全区测量成功后 expandSafeArea（见 common/WindowInsets），内容按安全区 padding。
   */
  private async setImmersive(stage: window.WindowStage): Promise<void> {
    try {
      const win: window.Window = stage.getMainWindowSync();
      await win.setWindowLayoutFullScreen(true);
      const dark: boolean = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      const props: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: dark ? '#FFFFFF' : '#000000',
        navigationBarContentColor: dark ? '#FFFFFF' : '#000000'
      };
      await win.setWindowSystemBarProperties(props);
    } catch (err) {
      hilog.error(DOMAIN, 'PhoneBook', 'set immersive failed: %{public}s', JSON.stringify(err));
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
        hilog.error(DOMAIN, 'PhoneBook', 'set immersive init failed: %{public}s', e.message);
      });
    });
  }

  /** 深浅色切换时同步系统栏图标颜色 */
  onConfigurationUpdate(newConfig: Configuration): void {
    if (this.winStage !== undefined) {
      this.setImmersive(this.winStage).catch((e: Error) => {
        hilog.error(DOMAIN, 'PhoneBook', 'config immersive failed: %{public}s', e.message);
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
