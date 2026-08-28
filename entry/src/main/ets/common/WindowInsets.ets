import { common } from '@kit.AbilityKit';
import { window, UIContext } from '@kit.ArkUI';

/**
 * 沉浸式安全区测量（docs/16 6.2）：
 * 根组件 expandSafeArea 后内容铺满全屏，顶/底安全区（状态栏/导航栏）高度
 * 经窗口 getWindowAvoidArea(TYPE_SYSTEM) 测量、UIContext.px2vp 换算。
 * 测量带重试（窗口未就绪时 300ms × 4）；全部失败返回 false——调用方**不得扩展安全区**
 * （回退系统安全区避让，保证绝不重叠），仅系统栏本色显示。
 */
export class WindowInsets {
  private static topVp: number = -1;
  private static bottomVp: number = 0;

  /** 测量成功返回 true（幂等，成功后缓存） */
  static async load(ctx: common.UIAbilityContext, uiCtx: UIContext): Promise<boolean> {
    if (WindowInsets.topVp >= 0) {
      return WindowInsets.topVp > 0;
    }
    let topH: number = 0;
    let bottomH: number = 0;
    for (let attempt: number = 0; attempt < 4; attempt++) {
      try {
        const win: window.Window = await window.getLastWindow(ctx);
        const area: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        topH = area.topRect === undefined ? 0 : area.topRect.height;
        bottomH = area.bottomRect === undefined ? 0 : area.bottomRect.height;
        if (topH > 0) {
          WindowInsets.topVp = Math.ceil(uiCtx.px2vp(topH));
          WindowInsets.bottomVp = Math.ceil(uiCtx.px2vp(bottomH));
          return true;
        }
      } catch (e) {
        // 窗口尚未就绪，重试
      }
      await new Promise<void>((resolve: () => void) => {
        setTimeout(resolve, 300);
      });
    }
    WindowInsets.topVp = 0;
    WindowInsets.bottomVp = 0;
    return false;
  }

  /** 是否测量成功（成功才应 expandSafeArea） */
  static ok(): boolean {
    return WindowInsets.topVp > 0;
  }

  /** 顶部安全区高度（vp） */
  static top(): number {
    return Math.max(WindowInsets.topVp, 0);
  }

  /** 底部安全区高度（vp） */
  static bottom(): number {
    return Math.max(WindowInsets.bottomVp, 0);
  }
}
