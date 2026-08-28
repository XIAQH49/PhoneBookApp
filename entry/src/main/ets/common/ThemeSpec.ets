/**
 * 设计令牌（数值型，docs/15 ChatGPT 整理版 + docs/14 第 8 节沉浸光感 + 官方 uiMaterial 门控）：
 * 颜色/圆角/间距/字号等走资源引用（$r('app.color.*') / $r('app.float.*')），
 * 阴影/材质/卡片三态/设备档位等资源无法表达的参数集中于此，改一处全局生效。
 * 沉浸光感官方 API（API 26 @ohos.arkui.uiMaterial）：ImmersiveMaterial/ImmersiveOptions
 * （style 厚度/materialColor/colorInvert/applyShadow/interactive/lightEffect 光随指动）在本机 SDK
 * 仅对 systemMaterial 生态（Tabs/系统弹窗）开放，普通容器属性未公开——按官方 getMaterialInfo()
 * 应用级沉浸开关实现门控，效果参数以 docs/15 四/五节语义材质落码。
 */
import uiMaterial from '@ohos.arkui.uiMaterial';

/** 设备性能档位（docs/14 8.3；docs/15 四节三态在此基础上缩放） */
export enum MaterialLevel {
  HIGH = 0,
  MIDDLE = 1,
  LOW = 2
}

/** 语义材质角色（docs/15 第四节：业务只请求语义，不传滤镜参数） */
export enum MaterialRole {
  PRIMARY_ACTION = 0,
  FLOATING_TOOL = 1,
  FEATURED_SURFACE = 2,
  SELECTION = 3,
  NORMAL_SURFACE = 4
}

/** 层级角色（docs/14 8.2） */
export enum CardLevel {
  NORMAL = 0,
  EMPHASIS = 1,
  FLOATING = 2,
  BACKGROUND = 3
}

/** 交互状态（docs/14 8.2 / docs/15 四-卡片三态） */
export enum CardInteractionState {
  IDLE = 0,
  PRESSED = 1
}

/** 设备档位参数（docs/14 8.3 三档各自一套完整方案） */
export interface MaterialLevelParams {
  filterStrength: number;
  shadowLevel: number;
  borderWidth: number;
  motionScale: number;
}

/** 语义 → 参数令牌（docs/15 四-MaterialTokens） */
export interface MaterialTokens {
  backgroundColor: Resource;
  borderColor: ResourceColor;
  borderWidth: number;
  shadowRadius: number;
  shadowOffsetY: number;
  shadowAlpha: number;
  lightOpacity: number;
}

/** 状态 → 视觉 spec（docs/15 四-卡片三态） */
export interface CardVisualSpec {
  offsetY: number;
  scale: number;
  shadowAlpha: number;
  lightOpacity: number;
}

export class ThemeSpec {
  // ---- 毛玻璃（docs/15 校对#6：只给浮层；真机确认 backgroundBlurStyle 系统材质在本层级仅渲染遮罩色
  //      （用户反馈"变暗变灰"，药不对症）→ 改用真实背景高斯模糊 backdropBlur(radius)：模糊"背后内容"，
  //      玻璃=低alpha半透明底 + 背后高斯模糊 + 顶部反射光带 + 高光描边）----
  /** 背景高斯模糊半径（vp；官方社区甜蜜点 15~35，取 26——低于15像薄纱，高于35失去色彩辨识度） */
  static readonly BAR_BLUR_RADIUS: number = 26;
  /** 浮层描边（docs/15 四-floating-tool：border rgba(255,255,255,0.55)） */
  static readonly FLOATING_BORDER_COLOR: string = 'rgba(255,255,255,0.55)';
  /** 玻璃顶缘反射光带（白 → 透明 渐变，模拟环境光反射） */
  static readonly REFLECT_COLOR: string = 'rgba(255,255,255,0.42)';

  // ---- 布局（docs/15 七-尺寸总表）----
  static readonly CONTENT_MAX_WIDTH_VP: number = 1040;
  static readonly BAR_MAX_WIDTH_VP: number = 560;

  // ---- 沉浸光感（docs/15 四 + docs/14 8.3 + 官方 uiMaterial 门控）----
  /**
   * 档位覆盖开关：'' = 自动；'high' / 'middle' / 'low' 强制指定。
   * v0.7 视觉反馈 #5：沉浸光感拉满 → 固定 high（滤镜/阴影/位移/缩放全开）。
   */
  static readonly MATERIAL_LEVEL_OVERRIDE: string = 'high';

  /** 系统沉浸材质是否启用（官方 getMaterialInfo() 读取；失败默认启用） */
  static immersiveEnabled: boolean = true;

  /**
   * 官方沉浸光感门控（API 26 @ohos.arkui.uiMaterial.getMaterialInfo）：
   * 系统配置 MaterialState.DISABLE 时关闭应用级沉浸光感（毛玻璃/光效降级为纯色+基础阴影），
   * 与官方 FAQ「systemMaterial 是否生效」开关一致；读取异常回退启用（fail-safe）。
   * 由 EntryAbility.onCreate 在页面加载前调用一次。
   */
  static initImmersiveGate(): void {
    try {
      const info: uiMaterial.MaterialInfo = uiMaterial.getMaterialInfo();
      ThemeSpec.immersiveEnabled = info !== undefined && info.state !== uiMaterial.MaterialState.DISABLE;
    } catch (e) {
      ThemeSpec.immersiveEnabled = true;
    }
  }

  /** 光感系数：门控关闭时（系统禁用沉浸）→ 0 */
  static lightFactor(): number {
    return ThemeSpec.immersiveEnabled ? 1 : 0;
  }

  /** 三档完整方案参数（docs/14 8.3） */
  static levelParams(level: MaterialLevel): MaterialLevelParams {
    if (level === MaterialLevel.HIGH) {
      const p: MaterialLevelParams = {
        filterStrength: 1.0, shadowLevel: 3, borderWidth: 1, motionScale: 1.0
      };
      return p;
    }
    if (level === MaterialLevel.MIDDLE) {
      const p: MaterialLevelParams = {
        filterStrength: 0.55, shadowLevel: 2, borderWidth: 1, motionScale: 0.65
      };
      return p;
    }
    const p: MaterialLevelParams = {
      filterStrength: 0, shadowLevel: 1, borderWidth: 2, motionScale: 0
    };
    return p;
  }

  /**
   * 设备档位检测（docs/14 8.3）：
   * 原生 OH_ArkUI_NativeModule_GetGlobalMaterialLevel（native_material.h，API 26）
   * 在本机 SDK 中无 ArkTS 直通接口（已查证 @ohos.arkui.uiMaterial 仅有 MaterialType/State 配置），
   * 首版按 8.5 默认 middle（真机看效果后调档）；low 档方案完整保留（边框/底色/基础阴影表达层级）。
   */
  static materialLevel(): MaterialLevel {
    const o: string = ThemeSpec.MATERIAL_LEVEL_OVERRIDE;
    if (o === 'high') {
      return MaterialLevel.HIGH;
    }
    if (o === 'low') {
      return MaterialLevel.LOW;
    }
    return MaterialLevel.MIDDLE;
  }

  /** 语义材质 → 参数令牌（docs/15 四；按设备档位缩放；效果开至最大档——增强值见各角色注释） */
  static resolveMaterial(role: MaterialRole, level: MaterialLevel): MaterialTokens {
    const lp: MaterialLevelParams = ThemeSpec.levelParams(level);
    let t: MaterialTokens;
    if (role === MaterialRole.PRIMARY_ACTION) {
      // primary 底 #FFF 字；shadowRadius 16/alpha 0.20/offsetY 6（最大档增强）
      t = {
        backgroundColor: $r('app.color.primary'), borderColor: $r('app.color.primary'), borderWidth: 0,
        shadowRadius: 16, shadowOffsetY: 6, shadowAlpha: 0.20, lightOpacity: 0
      };
    } else if (role === MaterialRole.FLOATING_TOOL) {
      // rgba(surface,0.30) + backdropBlur(26) + border rgba(255,255,255,0.55)
      // + shadowRadius 32/alpha 0.18/offsetY 10（最大档增强）
      t = {
        backgroundColor: $r('app.color.bar_bg'), borderColor: ThemeSpec.FLOATING_BORDER_COLOR,
        borderWidth: lp.borderWidth, shadowRadius: 32, shadowOffsetY: 10, shadowAlpha: 0.18, lightOpacity: 0.06
      };
    } else if (role === MaterialRole.FEATURED_SURFACE) {
      // surface_card + shadowRadius 28/alpha 0.14/offsetY 8（最大档增强）
      t = {
        backgroundColor: $r('app.color.surface_card'), borderColor: $r('app.color.selection_border'),
        borderWidth: 0, shadowRadius: 28, shadowOffsetY: 8, shadowAlpha: 0.14, lightOpacity: 0.10
      };
    } else if (role === MaterialRole.SELECTION) {
      // primary_soft 底 + border primary@12%
      t = {
        backgroundColor: $r('app.color.primary_soft'), borderColor: $r('app.color.selection_border'),
        borderWidth: lp.borderWidth, shadowRadius: 0, shadowOffsetY: 0, shadowAlpha: 0, lightOpacity: 0.06
      };
    } else {
      // normal-surface：surface_card + shadowRadius 20/alpha 0.08/offsetY 6（最大档增强）
      t = {
        backgroundColor: $r('app.color.surface_card'), borderColor: $r('app.color.divider'),
        borderWidth: lp.borderWidth, shadowRadius: 20, shadowOffsetY: 6, shadowAlpha: 0.08, lightOpacity: 0.03
      };
    }
    t.shadowAlpha = t.shadowAlpha * lp.shadowLevel / 3;
    t.lightOpacity = t.lightOpacity * lp.filterStrength * ThemeSpec.lightFactor();
    return t;
  }

  /**
   * 状态 → 视觉 spec（docs/15 四-卡片三态，按设备档位缩放；最大档增强值）：
   * Default scale 1.0/offsetY 0/shadowAlpha 0.08/lightOpacity 0.03；
   * Pressed scale 0.985/offsetY 1/shadowAlpha 0.025/lightOpacity 0.10（光随指动增强）；
   * Featured/Selected scale 1.0/offsetY −3/shadowAlpha 0.14/lightOpacity 0.14（光线勾勒增强）。
   */
  static resolveCardVisualSpec(state: CardInteractionState, level: MaterialLevel,
    emphasis: boolean): CardVisualSpec {
    const lp: MaterialLevelParams = ThemeSpec.levelParams(level);
    let offsetY: number = 0;
    let scale: number = 1.0;
    let shadowAlpha: number = 0.08;
    let lightOpacity: number = 0.03;
    if (emphasis && state === CardInteractionState.IDLE) {
      // Featured/Selected：微上移 + 阴影加深 + 边缘高光（光线勾勒）
      offsetY = -3;
      scale = 1.0;
      shadowAlpha = 0.14;
      lightOpacity = 0.14;
    } else if (state === CardInteractionState.PRESSED) {
      // 按压：微下移 + 微缩小 + 阴影变浅（卡片贴向屏幕）+ 边缘高光增强（光随指动）
      offsetY = 1;
      scale = 0.985;
      shadowAlpha = 0.025;
      lightOpacity = 0.10;
    }
    const m: number = lp.motionScale;
    offsetY = offsetY * m;
    scale = 1 + (scale - 1) * m;
    shadowAlpha = shadowAlpha * lp.shadowLevel / 3;
    lightOpacity = lightOpacity * lp.filterStrength * ThemeSpec.lightFactor();
    const spec: CardVisualSpec = {
      offsetY: offsetY, scale: scale, shadowAlpha: shadowAlpha, lightOpacity: lightOpacity
    };
    return spec;
  }

  /** 主色调光感阴影颜色（alpha 动态） */
  static shadowColor(alpha: number): string {
    return 'rgba(10,132,255,' + alpha + ')';
  }

  /** 边缘高光颜色（光线勾勒，alpha 动态） */
  static glowColor(alpha: number): string {
    return 'rgba(255,255,255,' + alpha + ')';
  }

  /** 千人分位（统计大数字 1,438） */
  static formatThousands(n: number): string {
    const s: string = Math.floor(n).toString();
    let out: string = '';
    let count: number = 0;
    for (let i: number = s.length - 1; i >= 0; i--) {
      out = s.charAt(i) + out;
      count++;
      if (count % 3 === 0 && i > 0) {
        out = ',' + out;
      }
    }
    return out;
  }
}
