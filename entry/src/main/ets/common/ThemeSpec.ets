/**
 * 设计令牌（数值型，docs/14 第 2 节）：
 * 颜色/圆角/间距/字号等走资源引用（$r('app.color.*') / $r('app.float.*')），
 * 阴影、断点、毛玻璃等资源无法表达的参数集中于此，改一处全局生效。
 */
export class ThemeSpec {
  // ---- 阴影（2.3 光感阴影：主色调低透明度）----
  static readonly SHADOW_CARD_RADIUS: number = 24;
  static readonly SHADOW_CARD_COLOR: string = 'rgba(0,125,255,0.06)';
  static readonly SHADOW_CARD_OFFSET_Y: number = 6;
  static readonly SHADOW_RAISED_RADIUS: number = 40;
  static readonly SHADOW_RAISED_COLOR: string = 'rgba(0,125,255,0.12)';
  static readonly SHADOW_RAISED_OFFSET_Y: number = 12;

  // ---- 响应式断点（4.1：<600vp 单列；≥600vp 双列）----
  static readonly BREAKPOINT_WIDE_VP: number = 600;

  // ---- 毛玻璃（顶栏/底部操作栏，5.5）----
  static readonly BAR_BLUR: BlurStyle = BlurStyle.Thick;

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
