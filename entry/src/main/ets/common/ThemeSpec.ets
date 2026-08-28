/**
 * 设计令牌（数值型，docs/14 第 2 节 + 第 8 节沉浸光感）：
 * 颜色/圆角/间距/字号等走资源引用（$r('app.color.*') / $r('app.float.*')），
 * 阴影、断点、毛玻璃、语义材质（MaterialTokens/卡片视觉 spec/设备档位）等资源无法表达的
 * 参数集中于此，改一处全局生效。
 */

/** 设备性能档位（docs/14 8.3） */
export enum MaterialLevel {
  HIGH = 0,
  MIDDLE = 1,
  LOW = 2
}

/** 语义材质角色（docs/14 8.1）：业务只请求语义，不传滤镜参数 */
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

/** 交互状态（docs/14 8.2；本项目只需按压） */
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

/** 语义 → 参数令牌（docs/14 8.1 MaterialTokens） */
export interface MaterialTokens {
  backgroundColor: Resource;
  borderColor: Resource;
  borderWidth: number;
  shadowRadius: number;
  shadowOffsetY: number;
  shadowAlpha: number;
  lightOpacity: number;
}

/** 状态 → 视觉 spec（docs/14 8.2 resolveCardVisualSpec） */
export interface CardVisualSpec {
  offsetY: number;
  scale: number;
  shadowAlpha: number;
  lightOpacity: number;
}

export class ThemeSpec {
  // ---- 阴影（2.3 光感阴影：主色调低透明度）----
  static readonly SHADOW_CARD_RADIUS: number = 24;
  static readonly SHADOW_CARD_COLOR: string = 'rgba(0,125,255,0.06)';
  static readonly SHADOW_CARD_OFFSET_Y: number = 6;
  static readonly SHADOW_RAISED_RADIUS: number = 40;
  static readonly SHADOW_RAISED_COLOR: string = 'rgba(0,125,255,0.12)';
  static readonly SHADOW_RAISED_OFFSET_Y: number = 12;

  // ---- 响应式（v0.1.2 用户拍板：名单卡片固定单列，不做双列适配）----

  // ---- 毛玻璃（顶栏/底部操作栏，5.5）----
  static readonly BAR_BLUR: BlurStyle = BlurStyle.Thick;

  // ---- 沉浸光感（docs/14 第 8 节）----
  /**
   * 档位覆盖开关：'' = 自动；'high' / 'middle' / 'low' 强制指定。
   * 首版自动档 = middle（docs/14 8.5：真机看效果后再调档）。
   */
  static readonly MATERIAL_LEVEL_OVERRIDE: string = '';

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

  /** 语义材质 → 参数令牌（docs/14 8.1，按设备档位缩放） */
  static resolveMaterial(role: MaterialRole, level: MaterialLevel): MaterialTokens {
    const lp: MaterialLevelParams = ThemeSpec.levelParams(level);
    let t: MaterialTokens;
    if (role === MaterialRole.PRIMARY_ACTION) {
      t = {
        backgroundColor: $r('app.color.primary'), borderColor: $r('app.color.primary'), borderWidth: 0,
        shadowRadius: ThemeSpec.SHADOW_RAISED_RADIUS, shadowOffsetY: ThemeSpec.SHADOW_RAISED_OFFSET_Y,
        shadowAlpha: 0.12, lightOpacity: 0.08
      };
    } else if (role === MaterialRole.FLOATING_TOOL) {
      t = {
        backgroundColor: $r('app.color.bar_bg'), borderColor: $r('app.color.divider'), borderWidth: lp.borderWidth,
        shadowRadius: ThemeSpec.SHADOW_RAISED_RADIUS, shadowOffsetY: ThemeSpec.SHADOW_RAISED_OFFSET_Y,
        shadowAlpha: 0.12, lightOpacity: 0.08
      };
    } else if (role === MaterialRole.FEATURED_SURFACE) {
      t = {
        backgroundColor: $r('app.color.card'), borderColor: $r('app.color.primary_soft'), borderWidth: lp.borderWidth,
        shadowRadius: ThemeSpec.SHADOW_CARD_RADIUS, shadowOffsetY: ThemeSpec.SHADOW_CARD_OFFSET_Y,
        shadowAlpha: 0.12, lightOpacity: 0.05
      };
    } else if (role === MaterialRole.SELECTION) {
      t = {
        backgroundColor: $r('app.color.primary_soft'), borderColor: $r('app.color.primary'), borderWidth: lp.borderWidth,
        shadowRadius: 0, shadowOffsetY: 0,
        shadowAlpha: 0, lightOpacity: 0.05
      };
    } else {
      t = {
        backgroundColor: $r('app.color.card'), borderColor: $r('app.color.divider'), borderWidth: lp.borderWidth,
        shadowRadius: ThemeSpec.SHADOW_CARD_RADIUS, shadowOffsetY: ThemeSpec.SHADOW_CARD_OFFSET_Y,
        shadowAlpha: 0.06, lightOpacity: 0.02
      };
    }
    t.shadowAlpha = t.shadowAlpha * lp.shadowLevel / 3;
    t.lightOpacity = t.lightOpacity * lp.filterStrength;
    return t;
  }

  /** 状态 → 视觉 spec（docs/14 8.2 表，按设备档位缩放） */
  static resolveCardVisualSpec(state: CardInteractionState, level: MaterialLevel,
    emphasis: boolean): CardVisualSpec {
    const lp: MaterialLevelParams = ThemeSpec.levelParams(level);
    let offsetY: number = 0;
    let scale: number = 1.0;
    let shadowAlpha: number = 0.06;
    let lightOpacity: number = 0.02;
    if (emphasis && state === CardInteractionState.IDLE) {
      // 重点 EMPHASIS 默认态：微上移 + 微放大 + 阴影加深 + 边缘高光
      offsetY = -2;
      scale = 1.01;
      shadowAlpha = 0.12;
      lightOpacity = 0.05;
    } else if (state === CardInteractionState.PRESSED) {
      // 按压：微下移 + 微缩小 + 阴影再加深 + 高光增强（光随指动）
      offsetY = 2;
      scale = 0.985;
      shadowAlpha = 0.16;
      lightOpacity = 0.10;
    }
    const m: number = lp.motionScale;
    offsetY = offsetY * m;
    scale = 1 + (scale - 1) * m;
    shadowAlpha = shadowAlpha * lp.shadowLevel / 3;
    lightOpacity = lightOpacity * lp.filterStrength;
    const spec: CardVisualSpec = {
      offsetY: offsetY, scale: scale, shadowAlpha: shadowAlpha, lightOpacity: lightOpacity
    };
    return spec;
  }

  /** 主色调光感阴影颜色（alpha 动态） */
  static shadowColor(alpha: number): string {
    return 'rgba(0,125,255,' + alpha + ')';
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
