/**
 * 状态胶囊（docs/14 第 3 节）：高 28vp 全圆。
 * 通用形态：active=真 → 成功浅底+成功字（✓ 已打/✓ 打通/✓ 有意向）；
 * active=假 → 警示浅底+警示字（● 未打/○ 未打通/○ 无意向）。
 * 点击触发 onToggle（卡片右上角状态胶囊点击 = 标记/撤销，快捷勾选交互保留）。
 */
@Component
export struct StatusPill {
  @Prop active: boolean = false;
  labelOn: ResourceStr = $r('app.string.status_pill_called');
  labelOff: ResourceStr = $r('app.string.status_pill_uncalled');
  onToggle: () => void = () => {
  };

  build() {
    Text(this.active ? this.labelOn : this.labelOff)
      .fontSize($r('app.float.font_caption'))
      .fontWeight(FontWeight.Medium)
      .fontColor(this.active ? $r('app.color.success') : $r('app.color.warning'))
      .backgroundColor(this.active ? $r('app.color.success_soft') : $r('app.color.warning_soft'))
      .height($r('app.float.pill_height'))
      .padding({ left: 10, right: 10 })
      .borderRadius($r('app.float.radius_pill'))
      .textAlign(TextAlign.Center)
      .onClick(() => {
        this.onToggle();
      })
  }
}
