import { curves } from '@kit.ArkUI';

/**
 * 动效参数（docs/15 ChatGPT 整理版 第五节 + docs/14 第 5 节）：
 * 曲线/时长/位移/缩放集中于此，即取即用，真机截图后微调只需改本文件。
 * 原则（6.7/别做清单3）：属性动画→animateTo；出现消失→transition；跟手→responsiveSpringMotion；
 * 带速度释放→interpolatingSpring；按压优先 scale，不动画 width/height。
 */
export class MotionSpec {
  // ---- 曲线 ----
  /** 默认入场/出现：响应式弹簧 */
  static responsive(): curves.ICurve {
    return curves.responsiveSpringMotion();
  }

  /** 5.1 列表入场：淡入+上移+回弹 */
  static entrance(): curves.ICurve {
    return curves.springMotion(0.42, 0.84);
  }

  /** 带速度释放（快速滑动/按压释放）：手速越高回弹越快 */
  static press(): curves.ICurve {
    return curves.interpolatingSpring(1, 1, 228, 30);
  }

  /** 卡片按压/释放（四-卡片三态） */
  static pressCard(): curves.ICurve {
    return curves.responsiveSpringMotion(0.16, 0.88, 0.06);
  }

  /** 筛选选中指示（四-光随指动） */
  static chipSelect(): curves.ICurve {
    return curves.responsiveSpringMotion(0.15, 0.86, 0.08);
  }

  /** 底部栏按压释放（5.5） */
  static barRelease(): curves.ICurve {
    return curves.responsiveSpringMotion(0.18, 0.82, 0.06);
  }

  /** 5.3 状态胶囊切换 */
  static pillSwitch(): curves.ICurve {
    return curves.springMotion(0.30, 0.80);
  }

  /** 5.4 完成率圆环弹性生长 */
  static ringGrow(): curves.ICurve {
    return curves.springMotion(0.65, 0.86);
  }

  /** 图标按钮按压 */
  static iconPress(): curves.ICurve {
    return curves.springMotion(0.32, 0.82);
  }

  /** Featured/Selected 态过渡 */
  static featured(): curves.ICurve {
    return curves.springMotion(0.38, 0.84);
  }

  /** 5.6 页面转场 */
  static pageTransition(): curves.ICurve {
    return curves.springMotion(0.42, 0.86);
  }

  /** 拨号/主按钮：快速清脆反馈 */
  static click(): curves.ICurve {
    return curves.springMotion(0.28, 0.7);
  }

  // ---- 时长与错峰 ----
  static readonly DURATION_NUMBER_ROLL: number = 200;
  static readonly STAGGER: number = 35;
  static readonly STAGGER_MAX: number = 280;

  // ---- 位移/缩放（5.1/四/五）----
  static readonly ENTRANCE_TRANSLATE: number = 18;
  static readonly PAGE_TRANSITION_TRANSLATE_X: number = 24;
  static readonly NUMBER_ROLL_TRANSLATE: number = 12;
  static readonly PRESS_SCALE_CARD: number = 0.985;
  static readonly PRESS_SCALE_BTN: number = 0.94;
  static readonly PRESS_SCALE_ICON: number = 0.92;
  static readonly PRESS_OFFSET_Y: number = 1;
  static readonly CHIP_SELECT_SCALE: number = 1.03;
  static readonly PILL_SELECT_SCALE: number = 1.05;
}
