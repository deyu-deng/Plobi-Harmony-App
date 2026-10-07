/**
 * 一条日程事件（与桌面 `/api/handset/agenda` 与 `/api/handset/agenda/day` 返回字段对齐）。
 * 字段命名遵循 snake_case，对应后端 `to_dict()` 形状。
 */
export interface AgendaEvent {
  id: string;
  title: string;
  start_at: string;
  end_at?: string;
  kind: string;
  status: string;
  source: string;
  overlaps?: string[];
  location?: string;
  notes?: string;
}

/**
 * 事件 kind 的中文标签（全仓单点：卡片徽标与时间线同源，FR-013）。
 * 未知 kind 原样显示；空 kind 视为「事」。
 */
export function kindLabelOf(kind: string): string {
  if (kind === 'meeting') {
    return '会';
  }
  if (kind === 'task') {
    return '事';
  }
  if (kind === 'ddl') {
    return '截';
  }
  if (kind === 'class') {
    return '课';
  }
  if (kind === 'meal') {
    return '餐';
  }
  if (kind.length === 0) {
    return '事';
  }
  return kind;
}

/**
 * 作息锚点（来自 `/api/handset/agenda/day` 的 `anchors` 数组）。
 * `template_id` 形如 'sleep' / 'lunch' / 'dinner' / 'morning'（裁定 28.5 + C4 模板）。
 * `flex` = true 时表示该锚点是窗内挪过的（不是首选段）。
 */
export interface Anchor {
  id: string;
  title: string;
  start_at: string;
  end_at: string;
  template_id: string;
  flex: boolean;
}

/**
 * 计划项（来自 `/api/handset/agenda/day` 的 `plan_items` 数组；当日 daily_plan 不存在时为空数组）。
 */
export interface PlanItem {
  id: string;
  title: string;
  start_at: string;
  end_at?: string;
  kind: string;
  evidence: Object;
}

/**
 * 区间冲突（来自 `/api/handset/agenda/day` 的 `conflicts` 数组）。
 * 两边都有 end_at 且区间相交时贡献一行；DDL / 无 end_at 不参与。
 */
export interface ConflictPair {
  left_id: string;
  right_id: string;
  start_at: string;
  end_at: string;
}

/**
 * `/api/handset/agenda/day` 整体响应。
 */
export interface DayPayload {
  date: string;
  events: AgendaEvent[];
  anchors: Anchor[];
  plan_items: PlanItem[];
  conflicts: ConflictPair[];
  plan_status: string | null;
}