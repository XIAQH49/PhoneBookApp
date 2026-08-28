import { common } from '@kit.AbilityKit';
import { window, UIContext } from '@kit.ArkUI';

/**
 * 沉浸式安全区（v0.7 反馈 #6 补强）：
 * 根容器 expandSafeArea 后页面背景铺满全屏，顶/底安全区（状态栏/导航栏）高度
 * 经窗口 getWindowAvoidArea(TYPE_SYSTEM) 测量、UIContext.px2vp 换算并缓存（vp），供各页头栏/底栏补偿。
 */
export class WindowInsets {
  private static topVp: number = 0;
  private static bottomVp: number = 0;
  private static loaded: boolean = false;

  /** 首次调用加载并缓存（幂等）；失败回退 0（沿用安全区避让） */
  static async load(ctx: common.UIAbilityContext, uiCtx: UIContext): Promise<void> {
    if (WindowInsets.loaded) {
      return;
    }
    try {
      const win: window.Window = await window.getLastWindow(ctx);
      const area: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const topH: number = area.topRect === undefined ? 0 : area.topRect.height;
      const bottomH: number = area.bottomRect === undefined ? 0 : area.bottomRect.height;
      WindowInsets.topVp = Math.ceil(uiCtx.px2vp(topH));
      WindowInsets.bottomVp = Math.ceil(uiCtx.px2vp(bottomH));
    } catch (e) {
      WindowInsets.topVp = 0;
      WindowInsets.bottomVp = 0;
    }
    WindowInsets.loaded = true;
  }

  static top(): number {
    return WindowInsets.topVp;
  }

  static bottom(): number {
    return WindowInsets.bottomVp;
  }
}
