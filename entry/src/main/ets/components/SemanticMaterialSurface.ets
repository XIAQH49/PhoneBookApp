import {
  ThemeSpec, MaterialRole, CardInteractionState, MaterialTokens, CardVisualSpec
} from '../common/ThemeSpec';
import { MotionSpec } from '../common/MotionSpec';

/**
 * 语义材质表面（docs/15 第四节 + docs/14 8.5）：
 * 业务侧只传语义 role + emphasis + 交互回调，由本组件用 MaterialTokens + resolveCardVisualSpec
 * 统一渲染背景/描边/阴影/按压形变/边缘光线（光随指动 + 光线勾勒 + 非线性形变）。
 * 业务侧禁止硬编码滤镜参数；设备档位（high/middle/low）在 ThemeSpec 统一解析。
 */
@Component
export struct SemanticMaterialSurface {
  @Prop role: MaterialRole = MaterialRole.NORMAL_SURFACE;
  @Prop emphasis: boolean = false;
  @Prop interactive: boolean = true;
  radius: Resource = $r('app.float.radius_card');
  onTap: () => void = () => {
  };
  @BuilderParam content: () => void;
  @State pressed: boolean = false;

  private tokens(): MaterialTokens {
    return ThemeSpec.resolveMaterial(this.role, ThemeSpec.materialLevel());
  }

  private spec(): CardVisualSpec {
    return ThemeSpec.resolveCardVisualSpec(
      this.pressed ? CardInteractionState.PRESSED : CardInteractionState.IDLE,
      ThemeSpec.materialLevel(), this.emphasis);
  }

  /** 阴影：按压取按压 spec；Featured/Selected 取对应 spec；普通取角色令牌 */
  private shadowAlpha(): number {
    if (this.pressed || this.emphasis) {
      return this.spec().shadowAlpha;
    }
    return this.tokens().shadowAlpha;
  }

  /** 边缘光线：按压/Featured 取 spec；普通取角色令牌（normal=0，不每卡发光） */
  private glowAlpha(): number {
    if (this.pressed || this.emphasis) {
      return this.spec().lightOpacity;
    }
    return this.tokens().lightOpacity;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.content()
      }
      .width('100%')

      // 光线勾勒（docs/15 四）：顶部边缘渐变高光，不拦截触摸
      if (this.glowAlpha() > 0.001) {
        Stack()
          .width('100%')
          .height(2)
          .linearGradient({
            angle: 180,
            colors: [[ThemeSpec.glowColor(this.glowAlpha()), 0.0], ['rgba(255,255,255,0)', 1.0]]
          })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .backgroundColor(this.tokens().backgroundColor)
    .border({
      width: this.tokens().borderWidth,
      color: this.tokens().borderColor
    })
    .borderRadius(this.radius)
    .shadow({
      radius: this.tokens().shadowRadius,
      color: ThemeSpec.shadowColor(this.shadowAlpha()),
      offsetX: 0,
      offsetY: this.tokens().shadowOffsetY + this.spec().offsetY
    })
    .scale({ x: this.spec().scale, y: this.spec().scale })
    .translate({ y: this.spec().offsetY })
    .onTouch((e: TouchEvent) => {
      if (!this.interactive) {
        return;
      }
      if (e.type === TouchType.Down) {
        this.getUIContext().animateTo({ curve: MotionSpec.pressCard() }, () => {
          this.pressed = true;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.getUIContext().animateTo({ curve: MotionSpec.pressCard() }, () => {
          this.pressed = false;
        });
      }
    })
    .onClick(() => {
      this.onTap();
    })
  }
}
