/**
 * 今日时间线合并 + 「现在」标记（纯函数；任务书 WP-H3-DAY-LIST，裁定 36.4）。
 *
 * 约束（任务书 §必做 + §复用）：
 * - 今日 = 已确认 events + anchors + plan_items 合成，按 start_at 升序。
 * - 去重：同 `template_id` 或「title+开始分钟」相同的，只留一条。
 *   优先级：event > plan > anchor；anchor-anchor 同 template_id 时非 flex 优先。
 * - 「现在」：用平板本地钟；开始 ≤ now < 结束 的那一行标 isNow=true。
 *   无 end_at 时，开设分钟所在的那半小时（start ≤ now < start+30min）算「现在」。
 *   没有匹配则不标，不要假装下一节。
 * - 不抛、不猜；解析失败回退空 / 不标记。
 */
import { AgendaEvent, Anchor, PlanItem, kindLabelOf } from '../model/AgendaEvent';
import { padTwo } from '../utils/TimeFormat';

export type TimelineSource = 'event' | 'plan' | 'anchor';

export interface TimelineRow {
  id: string;
  source: TimelineSource;
  title: string;
  start_at: string;
  end_at?: string;
  kind: string;
  template_id?: string;
  flex?: boolean;
  isNow: boolean;
}

export interface TimelineInput {
  todayEvents: AgendaEvent[];
  anchors: Anchor[];
  planItems: PlanItem[];
  tomorrowEvents: AgendaEvent[];
}

export interface TimelineOutput {
  today: TimelineRow[];
  tomorrow: TimelineRow[];
}

function eventToRow(e: AgendaEvent): TimelineRow {
  return {
    'id': e.id,
    'source': 'event',
    'title': e.title,
    'start_at': e.start_at,
    'end_at': e.end_at,
    'kind': e.kind,
    'isNow': false,
  };
}

function planToRow(p: PlanItem): TimelineRow {
  return {
    'id': 'plan-' + p.id,
    'source': 'plan',
    'title': p.title,
    'start_at': p.start_at,
    'end_at': p.end_at,
    'kind': p.kind,
    'isNow': false,
  };
}

function anchorToRow(a: Anchor): TimelineRow {
  return {
    'id': 'anchor-' + a.id,
    'source': 'anchor',
    'title': a.title,
    'start_at': a.start_at,
    'end_at': a.end_at,
    'kind': 'anchor',
    'template_id': a.template_id,
    'flex': a.flex,
    'isNow': false,
  };
}

function priority(r: TimelineRow): number {
  if (r.source === 'event') {
    return 0;
  }
  if (r.source === 'plan') {
    return 1;
  }
  return 2;
}

/** 把 ISO 映成本地「HH:MM」，用作去重键的一部分。失败返回 ''（不抛）。 */
function startMinute(iso: string): string {
  if (iso.length === 0) {
    return '';
  }
  const d: Date = new Date(iso);
  if (isNaN(d.getTime())) {
    return '';
  }
  return padTwo(d.getHours()) + ':' + padTwo(d.getMinutes());
}

function rowDedupKeys(r: TimelineRow): string[] {
  const keys: string[] = [];
  const minute: string = startMinute(r.start_at);
  if (minute.length > 0 && r.title.length > 0) {
    keys.push('tm:' + r.title + '|' + minute);
  }
  if (r.template_id !== undefined && r.template_id.length > 0) {
    keys.push('tpl:' + r.template_id);
  }
  return keys;
}

function rowsMatch(a: TimelineRow, b: TimelineRow): boolean {
  const ka: string[] = rowDedupKeys(a);
  const kb: string[] = rowDedupKeys(b);
  for (let i: number = 0; i < ka.length; i++) {
    for (let j: number = 0; j < kb.length; j++) {
      if (ka[i] === kb[j]) {
        return true;
      }
    }
  }
  return false;
}

/**
 * 合并今日：events(已确认) + anchors + plan_items。
 * 去重后按 start_at 升序。
 */
export function mergeDay(
  todayEvents: AgendaEvent[],
  anchors: Anchor[],
  planItems: PlanItem[],
): TimelineRow[] {
  const all: TimelineRow[] = [];
  for (let i: number = 0; i < todayEvents.length; i++) {
    all.push(eventToRow(todayEvents[i]));
  }
  for (let i: number = 0; i < planItems.length; i++) {
    all.push(planToRow(planItems[i]));
  }
  for (let i: number = 0; i < anchors.length; i++) {
    all.push(anchorToRow(anchors[i]));
  }

  const sorted: TimelineRow[] = all.slice();
  sorted.sort((a: TimelineRow, b: TimelineRow): number => {
    const s: number = a.start_at.localeCompare(b.start_at);
    if (s !== 0) {
      return s;
    }
    const p: number = priority(a) - priority(b);
    if (p !== 0) {
      return p;
    }
    if (a.source === 'anchor' && b.source === 'anchor') {
      const af: number = a.flex === true ? 1 : 0;
      const bf: number = b.flex === true ? 1 : 0;
      return af - bf;
    }
    return 0;
  });

  const kept: TimelineRow[] = [];
  for (let i: number = 0; i < sorted.length; i++) {
    const r: TimelineRow = sorted[i];
    let matched: boolean = false;
    for (let j: number = 0; j < kept.length; j++) {
      if (rowsMatch(kept[j], r)) {
        matched = true;
        break;
      }
    }
    if (!matched) {
      kept.push(r);
    }
  }

  kept.sort((a: TimelineRow, b: TimelineRow): number => a.start_at.localeCompare(b.start_at));
  return kept;
}

/**
 * 标记「现在」那一行。
 * - 有 end_at：start ≤ now < end。
 * - 无 end_at：start ≤ now < start + 30min（半小时窗，任务书 §必做 2）。
 * - 只标一行（多行重叠取第一）。
 * - 不修改输入；返回新数组。
 */
export function markNow(rows: TimelineRow[], nowEpochMs: number): TimelineRow[] {
  const out: TimelineRow[] = new Array(rows.length);
  let nowIdx: number = -1;
  const halfHourMs: number = 30 * 60 * 1000;
  for (let i: number = 0; i < rows.length; i++) {
    const r: TimelineRow = rows[i];
    let matched: boolean = false;
    if (nowIdx < 0) {
      const startMs: number = Date.parse(r.start_at);
      if (!isNaN(startMs)) {
        const endRaw: string | undefined = r.end_at;
        if (endRaw !== undefined && endRaw.length > 0) {
          const endMs: number = Date.parse(endRaw);
          if (!isNaN(endMs) && startMs <= nowEpochMs && nowEpochMs < endMs) {
            matched = true;
          }
        } else {
          if (startMs <= nowEpochMs && nowEpochMs < startMs + halfHourMs) {
            matched = true;
          }
        }
      }
      if (matched) {
        nowIdx = i;
      }
    }
    out[i] = {
      'id': r.id,
      'source': r.source,
      'title': r.title,
      'start_at': r.start_at,
      'end_at': r.end_at,
      'kind': r.kind,
      'template_id': r.template_id,
      'flex': r.flex,
      'isNow': matched,
    };
  }
  return out;
}

/**
 * 整页输入 → { today, tomorrow }。today 走合并 + 去重；
 * tomorrow 只放 events（/api/handset/agenda/day 不返回明日 anchors）。
 * now 标记需 Date.now()，请在外面再 `markNow(today, Date.now())`。
 */
export function buildTimeline(input: TimelineInput): TimelineOutput {
  const today: TimelineRow[] = mergeDay(input.todayEvents, input.anchors, input.planItems);
  const tomorrow: TimelineRow[] = [];
  for (let i: number = 0; i < input.tomorrowEvents.length; i++) {
    tomorrow.push(eventToRow(input.tomorrowEvents[i]));
  }
  tomorrow.sort((a: TimelineRow, b: TimelineRow): number => a.start_at.localeCompare(b.start_at));
  return { 'today': today, 'tomorrow': tomorrow };
}

/** 显示用 kind 标签（anchor → '作息'；其余委托 AgendaEvent.kindLabelOf，与卡片同源中文标签）。 */
export function kindLabel(r: TimelineRow): string {
  if (r.source === 'anchor') {
    return '作息';
  }
  return kindLabelOf(r.kind);
}