import { AgendaEvent } from '../model/AgendaEvent';
import { localDateIso, localDateOfIso } from '../utils/LocalDate';

/**
 * 周视图的数据装配（WP-APP-CALENDAR T1）。纯函数、不碰 kit 与网络，可在本地单测里跑。
 *
 * 口径来自用户 10-09 拍的 D1/D2：
 *   D2 = 一周 = 本周、周一起（ISO 周，含今天之前那几天）；
 *   D1 = 冲突要显示，但**冲突与避让只许来自桌面的单日快照**（specs/handset-app.md §3.1），
 *        所以本文件**不算冲突、不判区间相交**，只负责把事件按天分桶。
 *
 * 三条纪律：不抛、不猜；解析失败的条目单独计数而不是静默丢掉；窗口外的条目也单独计数（数据层不藏丢数据）。
 */

export const DAYS_PER_WEEK: number = 7;

/** 一列里"显示得下"的条数上限；只用于算 overflowCount，**不截断数据**（渲染层自己决定怎么折）。 */
export const MAX_EVENTS_PER_DAY: number = 12;

const DAY_ISO_RE: RegExp = new RegExp('^[0-9]{4}-[0-9]{2}-[0-9]{2}$');

export interface WeekColumn {
  dateIso: string;
  dayIndex: number;      // 0 = 周一 … 6 = 周日
  events: AgendaEvent[]; // 非 pending（已确认一类）
  pending: AgendaEvent[];
  overflowCount: number; // max(0, events + pending − MAX_EVENTS_PER_DAY)
  isToday: boolean;
  isPast: boolean;       // 严格早于今日（今天本身不算过去）
}

export interface WeekBucketResult {
  columns: WeekColumn[];
  droppedCount: number;  // 落在本周窗口之外的条数
  invalidCount: number;  // start_at 缺失或解析不出本地日历日的条数
}

/**
 * 'YYYY-MM-DD' → 该日本地零点的 Date；非法返回 undefined。
 *
 * **不许直接 `new Date('2026-10-10')`**：按规范 date-only 形式按 UTC 解析，
 * 负时区会得到前一天。本仓的 `localDateIso` 用的是本地字段，这里必须同口径。
 * 顺带拒绝 `2026-02-30` 这类会被 Date 悄悄进位的假日期。
 */
export function dayFromLocalIso(dayIso: string): Date | undefined {
  if (!DAY_ISO_RE.test(dayIso)) {
    return undefined;
  }
  const y: number = Number(dayIso.substring(0, 4));
  const m: number = Number(dayIso.substring(5, 7));
  const d: number = Number(dayIso.substring(8, 10));
  if (m < 1 || m > 12 || d < 1 || d > 31) {
    return undefined;
  }
  const cand: Date = new Date(y, m - 1, d);
  if (isNaN(cand.getTime())) {
    return undefined;
  }
  if (cand.getFullYear() !== y || cand.getMonth() !== m - 1 || cand.getDate() !== d) {
    return undefined;
  }
  return cand;
}

/**
 * 给定本地日历日，返回它所在周的周一（ISO：周一为一周第一天；周日回退 6 天）。
 * 跨年与跨月靠 Date 构造器的日期进位，不做字符串加减。
 * 输入非法 → 空串（不抛）。
 */
export function mondayOfLocalDay(dayIso: string): string {
  const d: Date | undefined = dayFromLocalIso(dayIso);
  if (d === undefined) {
    return '';
  }
  const dow: number = d.getDay();          // 0=周日 1=周一 … 6=周六
  const back: number = dow === 0 ? 6 : dow - 1;
  return localDateIso(new Date(d.getFullYear(), d.getMonth(), d.getDate() - back));
}

/** 从周一开始铺 7 个本地日历日（升序）。周一非法 → 空数组。 */
export function weekDaysFromMonday(mondayIso: string): string[] {
  const m: Date | undefined = dayFromLocalIso(mondayIso);
  const out: string[] = [];
  if (m === undefined) {
    return out;
  }
  for (let i: number = 0; i < DAYS_PER_WEEK; i++) {
    out.push(localDateIso(new Date(m.getFullYear(), m.getMonth(), m.getDate() + i)));
  }
  return out;
}

function emptyColumn(dateIso: string, dayIndex: number, todayIso: string): WeekColumn {
  const col: WeekColumn = {
    dateIso: dateIso,
    dayIndex: dayIndex,
    events: [],
    pending: [],
    overflowCount: 0,
    isToday: dateIso === todayIso,
    isPast: todayIso.length > 0 && dateIso < todayIso,
  };
  return col;
}

function sortByStartAsc(list: AgendaEvent[]): void {
  list.sort((a: AgendaEvent, b: AgendaEvent): number => {
    return a.start_at.localeCompare(b.start_at);
  });
}

/**
 * 把一批事件按「本周（周一起）」分桶。
 *
 * 输入是**全量**的：后端 `GET /api/handset/agenda/pending` 没有区间参数
 * （Code `plobi/agenda/router.py:91-93`，`list_pending()` 直接返回全部 pending），
 * 所以窗口过滤必须由调用方在本地做——这不是"App 自己算冲突"，§3.1 禁的是后者。
 *
 * - mondayIso 非法 → 空列结果（不抛）。
 * - 事件 `start_at` 解析不出本地日历日 → 进 invalidCount，不塞进任何列。
 * - 事件落在 7 天窗口之外 → 进 droppedCount。
 * - 列内按 start_at 升序；`status === 'pending'` 归 pending 桶，其余归 events 桶。
 */
export function bucketWeek(events: AgendaEvent[], mondayIso: string, todayIso: string): WeekBucketResult {
  const days: string[] = weekDaysFromMonday(mondayIso);
  const result: WeekBucketResult = { columns: [], droppedCount: 0, invalidCount: 0 };
  if (days.length !== DAYS_PER_WEEK) {
    return result;
  }
  const indexByDay: Map<string, number> = new Map<string, number>();
  for (let i: number = 0; i < days.length; i++) {
    result.columns.push(emptyColumn(days[i], i, todayIso));
    indexByDay.set(days[i], i);
  }
  for (let j: number = 0; j < events.length; j++) {
    const e: AgendaEvent = events[j];
    const day: string | undefined = localDateOfIso(e.start_at);
    if (day === undefined) {
      result.invalidCount = result.invalidCount + 1;
      continue;
    }
    const idx: number | undefined = indexByDay.get(day);
    if (idx === undefined) {
      result.droppedCount = result.droppedCount + 1;
      continue;
    }
    const col: WeekColumn = result.columns[idx];
    if (e.status === 'pending') {
      col.pending.push(e);
    } else {
      col.events.push(e);
    }
  }
  for (let k: number = 0; k < result.columns.length; k++) {
    const col: WeekColumn = result.columns[k];
    sortByStartAsc(col.events);
    sortByStartAsc(col.pending);
    const total: number = col.events.length + col.pending.length;
    col.overflowCount = total > MAX_EVENTS_PER_DAY ? total - MAX_EVENTS_PER_DAY : 0;
  }
  return result;
}

/**
 * 一步到位：今日 → 本周一 → 本周 7 列。
 * todayIso 传空串时用设备本地今日（沿用 `LocalDate.todayLocalIso` 的口径，不许在这里另算一套）。
 */
export function buildWeekColumns(events: AgendaEvent[], todayIso: string): WeekBucketResult {
  const anchor: string = todayIso.length > 0 ? todayIso : localDateIso(new Date());
  return bucketWeek(events, mondayOfLocalDay(anchor), anchor);
}

/**
 * 周列表取数的左界：`YYYY-MM-DD` → `YYYY-MM-DDT00:00:00`；带时刻的原样返回（幂等）。
 */
export function dayStartBound(dayIso: string): string {
  return DAY_ISO_RE.test(dayIso) ? dayIso + 'T00:00:00' : dayIso;
}

/**
 * 周列表取数的右界：`YYYY-MM-DD` → `YYYY-MM-DDT23:59:59`；带时刻的原样返回（幂等）。
 *
 * **为什么必须有这一条（2026-10-14 实测，不是推断）**：后端 `to` 是**闭区间的时刻端点**，
 * `normalize_dt('2026-10-11')` 把它解析成 `2026-10-11T00:00:00`（`Code/plobi/agenda/store.py:193`），
 * 于是 `to=<周日裸日期>` 会把周日整天的事件全滤掉——8 条里丢 2 条（都是周日的），
 * 而同一周 7 次 `/api/handset/agenda/day` 单日快照一条不少。
 * 症状正好打在 WP-APP-DAY-SINK 的判据反面：**周视图那一列是空的，点进那一天却有内容**。
 * 右界补成日末后两边逐条对齐（周列表 8 条 = 7 份单日快照的并集 8 条）。
 *
 * 单日快照走的是另一套口径（`?date=YYYY-MM-DD`，后端自己补日界），与本函数不混用。
 */
export function dayEndBound(dayIso: string): string {
  return DAY_ISO_RE.test(dayIso) ? dayIso + 'T23:59:59' : dayIso;
}
