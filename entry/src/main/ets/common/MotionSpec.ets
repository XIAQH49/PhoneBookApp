import { curves } from '@kit.ArkUI';

/**
 * 动效参数（docs/14 第 5 节）：
 * 曲线/时长/位移/缩放集中于此，即取即用，真机截图后微调只需改本文件。
 * 曲线均为官方 API：curves.springMotion / responsiveSpringMotion / interpolatingSpring。
 */
export class MotionSpec {
  // ---- 5.1 曲线 ----
  /** 默认入场/出现：响应式弹簧，跟手不拖泥带水 */
  static responsive(): curves.ICurve {
    return curves.responsiveSpringMotion();
  }

  /** 大卡/列表入场：稍慢、柔和弹入 */
  static entrance(): curves.ICurve {
    return curves.springMotion(0.35, 0.75);
  }

  /** 按压跟手（列表行/卡片）：手速越高回弹越快 */
  static press(): curves.ICurve {
    return curves.interpolatingSpring(1, 1, 180, 20);
  }

  /** 拨号/主按钮：快速清脆反馈 */
  static click(): curves.ICurve {
    return curves.springMotion(0.28, 0.7);
  }

  /** 状态胶囊切换：颜色/文字弹性过渡 */
  static pillSwitch(): curves.ICurve {
    return curves.springMotion(0.3, 0.7);
  }

  /** 完成率圆环弹性生长 */
  static ringGrow(): curves.ICurve {
    return curves.springMotion(0.5, 0.8);
  }

  // ---- 5.3/5.4 时长与错峰 ----
  static readonly DURATION_NUMBER_ROLL: number = 200;
  static readonly DURATION_RING_GROW: number = 1200;
  static readonly STAGGER: number = 40;

  // ---- 位移（入场：opacity 0→1、translateY 20→0）----
  static readonly ENTRANCE_TRANSLATE: number = 20;
  static readonly NUMBER_ROLL_TRANSLATE: number = 12;

  // ---- 缩放与亮度（按压反馈）----
  static readonly PRESS_SCALE_CARD: number = 0.96;
  static readonly PRESS_SCALE_BTN: number = 0.94;
  static readonly PRESS_SCALE_ICON: number = 0.9;
  static readonly PRESS_BRIGHTNESS_CARD: number = 0.9;
  static readonly PRESS_BRIGHTNESS_ICON: number = 0.85;
}
