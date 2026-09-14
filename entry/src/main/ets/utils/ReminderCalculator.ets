import { AgendaEvent } from '../model/AgendaEvent';

/**
 * 一条已排提醒：桌面事件 ID → 系统 reminder ID。
 */
export interface ScheduledReminder {
  eventId: string;
  reminderId: number;
}

/**
 * 一条 T-15 计算结果（用于测试 / 调试）。
 */
export interface TMinusResult {
  triggerEpochSeconds: number;
  alreadyPast: boolean;
}

/**
 * `pickRemindersForEvents` 的返回类型。
 */
export interface PickedReminders {
  picked: AgendaEvent[];
  droppedCount: number;
}

const T_MINUS_SECONDS: number = 15 * 60;
export const MAX_REMINDERS_PER_PACKAGE: number = 30;

/**
 * 给一条事件算「start_at − 15min」的时间戳（秒）。已过返回 past=true。
 * 输入不是合法 ISO 时返回 undefined。
 */
export function tMinusFifteen(startIso: string, nowEpochSeconds: number): TMinusResult | undefined {
  if (!startIso) {
    return undefined;
  }
  const start: number = Date.parse(startIso);
  if (isNaN(start)) {
    return undefined;
  }
  const trigger: number = Math.floor(start / 1000) - T_MINUS_SECONDS;
  return {
    'triggerEpochSeconds': trigger,
    'alreadyPast': trigger <= nowEpochSeconds,
  };
}

/**
 * 从「今日+明日、已确认、有 start_at」的事件里选最多 30 条提醒，按时间正序排。
 * 已过的事件跳过。被截断时返回 droppedCount>0。
 */
export function pickRemindersForEvents(
  events: ReadonlyArray<AgendaEvent>,
  nowEpochSeconds: number,
): PickedReminders {
  const eligible: AgendaEvent[] = [];
  for (let i: number = 0; i < events.length; i++) {
    const e: AgendaEvent = events[i];
    if (e.status !== 'confirmed') {
      continue;
    }
    if (!e.start_at) {
      continue;
    }
    const calc: TMinusResult | undefined = tMinusFifteen(e.start_at, nowEpochSeconds);
    if (calc === undefined) {
      continue;
    }
    if (calc.alreadyPast) {
      continue;
    }
    eligible.push(e);
  }
  eligible.sort((a: AgendaEvent, b: AgendaEvent): number => {
    const ta: number = Date.parse(a.start_at);
    const tb: number = Date.parse(b.start_at);
    return ta - tb;
  });
  if (eligible.length <= MAX_REMINDERS_PER_PACKAGE) {
    const out: PickedReminders = { 'picked': eligible, 'droppedCount': 0 };
    return out;
  }
  const out: PickedReminders = {
    'picked': eligible.slice(0, MAX_REMINDERS_PER_PACKAGE),
    'droppedCount': eligible.length - MAX_REMINDERS_PER_PACKAGE,
  };
  return out;
}
