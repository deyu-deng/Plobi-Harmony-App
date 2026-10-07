import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AgendaEvent } from '../model/AgendaEvent';
import {
  ScheduledReminder,
  TMinusResult,
  pickRemindersForEvents,
  tMinusFifteen,
} from '../utils/ReminderCalculator';

export { ScheduledReminder };

const APP_PACKAGE_TAG: string = 'plobi';

/**
 * 请求通知/后台代理提醒权限。
 * 注意：reminderAgentManager 必须先有通知权限才能发。
 */
export async function ensureNotificationEnabled(): Promise<boolean> {
  try {
    await notificationManager.requestEnableNotification();
    return true;
  } catch (e) {
    const err: BusinessError = e as BusinessError;
    console.warn('[reminder] requestEnableNotification failed', err.code, err.message);
    return false;
  }
}

function buildReminderReq(event: AgendaEvent, triggerSeconds: number): reminderAgentManager.ReminderRequestTimer {
  const req: reminderAgentManager.ReminderRequestTimer = {
    reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
    triggerTimeInSeconds: triggerSeconds,
    title: 'Plobi · ' + event.title,
    content: '15 分钟后开始',
    expiredContent: '已过期',
    notificationId: hashEventId(event.id),
    slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
  };
  return req;
}

/**
 * 把事件 ID 压成 32-bit 正整数作为通知 ID（notificationId 必须是 number）。
 */
function hashEventId(id: string): number {
  let h: number = 2166136261;
  for (let i: number = 0; i < id.length; i++) {
    h = (h ^ id.charCodeAt(i)) >>> 0;
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h | 1;
}

/**
 * 取消本 App 之前排过的全部代理提醒。
 * reminderAgentManager 没有「按包名取消」接口 —— 我们跟踪已排 reminderId 列表，逐个 cancel。
 */
export async function clearScheduledReminders(scheduled: ReadonlyArray<ScheduledReminder>): Promise<void> {
  for (let i: number = 0; i < scheduled.length; i++) {
    try {
      await reminderAgentManager.cancelReminder(scheduled[i].reminderId);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      if (err.code !== 1700003 && err.code !== 1700004) {
        console.warn('[reminder] cancel failed', scheduled[i].reminderId, err.code, err.message);
      }
    }
  }
}

export interface RescheduleOutcome {
  scheduled: ScheduledReminder[];
  droppedCount: number;
  truncated: boolean;
  reason?: string;
}

/**
 * 重排：根据传入的「今日+明日、已确认、有 start_at」事件，重新取消+排满。
 * 上限 30 条/包（系统限制 1700002）；超额按时间正序优先，剩下的不排。
 */
export async function rescheduleReminders(
  events: ReadonlyArray<AgendaEvent>,
  previous: ReadonlyArray<ScheduledReminder>,
  nowEpochSeconds: number,
): Promise<RescheduleOutcome> {
  await clearScheduledReminders(previous);
  const picked = pickRemindersForEvents(events, nowEpochSeconds);
  const scheduled: ScheduledReminder[] = [];
  let truncated: boolean = picked.droppedCount > 0;
  let reason: string | undefined = undefined;
  if (picked.droppedCount > 0) {
    reason = '今日提醒已满 ' + String(picked.droppedCount) + ' 条';
  }
  for (let i: number = 0; i < picked.picked.length; i++) {
    const e: AgendaEvent = picked.picked[i];
    const calc: TMinusResult | undefined = tMinusFifteen(e.start_at, nowEpochSeconds);
    if (calc === undefined || calc.alreadyPast) {
      continue;
    }
    const req: reminderAgentManager.ReminderRequestTimer = buildReminderReq(e, calc.triggerEpochSeconds);
    try {
      const id: number = await reminderAgentManager.publishReminder(req);
      scheduled.push({ eventId: e.id, reminderId: id });
    } catch (e2) {
      const err: BusinessError = e2 as BusinessError;
      if (err.code === 1700002) {
        truncated = true;
        reason = '今日提醒已满 30 条';
        break;
      }
      console.warn('[reminder] publish failed', e.id, err.code, err.message);
    }
  }
  return { scheduled: scheduled, droppedCount: picked.droppedCount, truncated: truncated, reason: reason };
}
