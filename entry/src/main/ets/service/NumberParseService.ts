/**
 * FR-9 号码解析与规范化（设计规格 4.5 节状态机 S0~S6）。
 *
 * 纯逻辑文件（.ts）：不依赖任何 ArkTS Kit，可用 Node 直接运行验证
 * （node tools/verify/verify.ts），也可被 hypium LocalUnit 引用。
 *
 * 规则摘要：
 *  S1 剥离括号注释：（）()【】[]《》及其内容（支持嵌套）；未闭合括号视为注释直至行尾（仅保留括号前内容）
 *  S2 拆分：/ ／ 、 ， , ; ； \n \r \t 为分隔符（空格不作为分隔符）
 *  S3 段清洗：去首尾空白，移除段内空格与 - －（保留 + 与数字）
 *  S4 前缀规范化：+86 / 86 / 0086 → 统一 +86；11 位 1[3-9] 手机号 → +86 前缀
 *  S5 校验：^\+?\d{7,15}$；按序去重
 *  S6 输出：有效号码数组（空数组表示全部无效，UI 走复制兜底）
 */
export class NumberParseService {
  /** 打开/关闭括号字符集（下标一一对应，支持嵌套深度） */
  private static readonly OPEN_BRACKETS: string = '（(【[《';
  private static readonly CLOSE_BRACKETS: string = '）)】]》';

  /**
   * 解析单元格文本，返回规范化号码数组（无有效号码时为空数组）。
   * @param cell 单元格原始文本（CSV 为文本；xlsx 数字型须先经 numberToString 还原）
   */
  static parse(cell: string): string[] {
    if (cell === undefined || cell === null) {
      return [];
    }
    const text: string = NumberParseService.stripBracketComments(cell);
    const rawSegs: string[] = text.split(/[\/／、，,;；\n\r\t]+/);
    const result: string[] = [];
    for (const rawSeg of rawSegs) {
      let seg: string = rawSeg.trim();
      if (seg === '') {
        continue;
      }
      seg = seg.replace(/[\s\-－]/g, '');
      const normalized: string = NumberParseService.normalize(seg);
      if (normalized !== '' && result.indexOf(normalized) < 0) {
        result.push(normalized);
      }
    }
    return result;
  }

  /**
   * xlsx 数字型单元格还原为整数文本（防科学计数法）。
   * 11 位手机号 < 2^53，float64 无损；非有限数返回空串。
   */
  static numberToString(n: number): string {
    if (!Number.isFinite(n)) {
      return '';
    }
    return Math.floor(n).toString();
  }

  /** S1：剥离括号及其中的注释内容（含嵌套）；未闭合括号时保留剩余原文 */
  private static stripBracketComments(input: string): string {
    const open: string = NumberParseService.OPEN_BRACKETS;
    const close: string = NumberParseService.CLOSE_BRACKETS;
    let out: string = '';
    let i: number = 0;
    while (i < input.length) {
      const ch: string = input.charAt(i);
      const openIdx: number = open.indexOf(ch);
      if (openIdx >= 0) {
        let j: number = i + 1;
        let depth: number = 1;
        let closed: boolean = false;
        while (j < input.length) {
          const c2: string = input.charAt(j);
          const o2: number = open.indexOf(c2);
          if (o2 >= 0) {
            depth++;
          } else if (close.indexOf(c2) >= 0) {
            depth--;
            if (depth === 0) {
              closed = true;
              break;
            }
          }
          j++;
        }
        if (closed) {
          i = j + 1;
          continue;
        }
        // 未闭合：视为注释直至行尾，仅保留括号前已扫描内容
        break;
      }
      out += ch;
      i++;
    }
    return out;
  }

  /** S4+S5：规范化单个候选段；无法识别返回空串 */
  private static normalize(seg: string): string {
    let hasPlus: boolean = false;
    let digits: string = seg;
    if (digits.startsWith('+')) {
      hasPlus = true;
      digits = digits.substring(1);
    }
    // +86 / 86 / 0086 国家码统一
    const cnMatch: RegExpMatchArray | null = digits.match(/^(0{0,2}86)(\d+)$/);
    if (cnMatch !== null && cnMatch[2] !== undefined) {
      return '+86' + cnMatch[2];
    }
    // 11 位国内手机号补 +86
    if (!hasPlus && /^1[3-9]\d{9}$/.test(digits)) {
      return '+86' + digits;
    }
    // 其余纯数字 7~15 位（座机/400/国际号码）
    if (/^\d{7,15}$/.test(digits)) {
      return (hasPlus ? '+' : '') + digits;
    }
    return '';
  }
}
