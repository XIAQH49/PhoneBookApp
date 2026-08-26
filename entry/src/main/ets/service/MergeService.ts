/**
 * FR-2 / R-1 重复导入合并算法与"是否已打"值映射（设计规格 4.2 / 3.3 节）。
 *
 * 纯逻辑文件（.ts）：不依赖任何 ArkTS Kit，可用 Node 直接运行验证。
 *
 * 合并规则：
 *  1. 行匹配键：工号非空 → "E:{工号}"；否则 "H:{hash(姓名+手机原文)}"
 *  2. 已打状态取"或"：本地或新文件任一为已打，合并后即为已打
 *  3. 其他字段以新文件为准；新文件缺失的本地行标记移除（in_file=0）
 */

/** 新文件中的一行（已含清洗结果与行键） */
export interface MergeRowData {
  rowKey: string;
  rowNo: number;
  assignee: string;
  name: string;
  empNo: string;
  phoneRaw: string;
  phoneNumbers: string[];
  rawData: Record<string, string>;
  calledFromFile: boolean;
}

/** 本地已有行的最小快照（供合并决策） */
export interface LocalRowSnapshot {
  id: number;
  rowKey: string;
  called: boolean;
}

/** 一条更新指令 */
export interface MergeUpdate {
  localId: number;
  data: MergeRowData;
  calledMerged: boolean;
}

/** 合并计划（由 ImportService 在单事务内执行） */
export interface MergePlan {
  inserts: MergeRowData[];
  updates: MergeUpdate[];
  removedLocalIds: number[];
}

export class MergeService {
  /** 行匹配键：优先工号，缺失时姓名+手机原文哈希 */
  static buildRowKey(empNo: string, name: string, phoneRaw: string): string {
    const e: string = empNo.trim();
    if (e !== '') {
      return 'E:' + e;
    }
    return 'H:' + MergeService.hashStr(name.trim() + '|' + phoneRaw.trim());
  }

  /** 简单字符串哈希（FNV-1a 变体），仅作本地匹配键，非加密用途 */
  static hashStr(s: string): string {
    let h: number = 2166136261;
    for (let i: number = 0; i < s.length; i++) {
      h = h ^ s.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return (h >>> 0).toString(16);
  }

  /** 字节哈希（FNV-1a，内置文件变更检测用，非加密用途） */
  static hashBytes(bytes: Uint8Array): string {
    let h: number = 2166136261;
    for (let i: number = 0; i < bytes.length; i++) {
      h = h ^ bytes[i];
      h = Math.imul(h, 16777619);
    }
    return (h >>> 0).toString(16);
  }

  /**
   * 计算合并计划（v0.5.3 修复丢行 bug）：
   * - 新文件内同键的多条行**全部保留**（同工号/同姓名+手机的多任务行不再被去重丢弃）；
   * - 本地同键行按队列顺序与新文件同键行一一匹配（多余本地行标记移除）；
   * - 状态取"或"不变。
   * @param newRows 新文件解析出的全部行
   * @param localRows 本地当前生效数据集的行快照
   */
  static computePlan(newRows: MergeRowData[], localRows: LocalRowSnapshot[]): MergePlan {
    // 同键本地行可能有多条：按队列存储，与新文件同键行按序一一匹配
    const localQueues: Map<string, LocalRowSnapshot[]> = new Map<string, LocalRowSnapshot[]>();
    for (const l of localRows) {
      const q: LocalRowSnapshot[] | undefined = localQueues.get(l.rowKey);
      if (q !== undefined) {
        q.push(l);
      } else {
        const arr: LocalRowSnapshot[] = [l];
        localQueues.set(l.rowKey, arr);
      }
    }
    const plan: MergePlan = { inserts: [], updates: [], removedLocalIds: [] };
    for (const n of newRows) {
      const q: LocalRowSnapshot[] | undefined = localQueues.get(n.rowKey);
      if (q !== undefined && q.length > 0) {
        const local: LocalRowSnapshot = q.shift() as LocalRowSnapshot;
        const update: MergeUpdate = {
          localId: local.id,
          data: n,
          calledMerged: local.called || n.calledFromFile
        };
        plan.updates.push(update);
      } else {
        plan.inserts.push(n);
      }
    }
    // 剩余本地行：新文件中已消失
    localQueues.forEach((value: LocalRowSnapshot[]) => {
      for (const l of value) {
        plan.removedLocalIds.push(l.id);
      }
    });
    return plan;
  }
}

/**
 * "是否已打"列值判定与导出格式映射（FR-2 判定表 / R-5）。
 */
export class CalledValue {
  private static readonly TRUE_VALUES: string[] =
    ['是', '已打', '已拨打', '√', '✓', '1', 'true', 'TRUE', 'Y', 'YES', '完成'];
  private static readonly FALSE_VALUES: string[] =
    ['否', '未打', '未拨打', '0', 'false', 'FALSE', 'N', 'NO'];

  /** 导入判定：无法识别的值归为未打（原值仍保留在 raw_data 中） */
  static toBoolean(raw: string): boolean {
    const v: string = raw.trim();
    if (v === '') {
      return false;
    }
    if (CalledValue.TRUE_VALUES.indexOf(v) >= 0) {
      return true;
    }
    if (CalledValue.FALSE_VALUES.indexOf(v) >= 0) {
      return false;
    }
    return false;
  }

  /** 导出格式探测：yes_no（是/空）| one_blank（1/空）；无法判定默认 yes_no */
  static detectFormat(values: string[]): string {
    for (const v of values) {
      const t: string = v.trim();
      if (t === '是' || t === '否') {
        return 'yes_no';
      }
      if (t === '1' || t === '√' || t === '✓') {
        return 'one_blank';
      }
    }
    return 'yes_no';
  }

  /** 导出值写入：已打→格式值，未打→空 */
  static toExportValue(called: boolean, format: string): string {
    if (!called) {
      return '';
    }
    return format === 'one_blank' ? '1' : '是';
  }
}
