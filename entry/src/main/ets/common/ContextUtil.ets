import { common } from '@kit.AbilityKit';

/**
 * 页面上下文工具：替代已弃用的 getContext(this)。
 * 在 UIAbility 应用内，host context 即 UIAbilityContext。
 */
export class ContextUtil {
  static getAbilityContext(ui: UIContext): common.UIAbilityContext | undefined {
    return ui.getHostContext() as common.UIAbilityContext | undefined;
  }
}
