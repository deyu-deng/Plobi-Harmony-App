import { describe, it, expect } from '@ohos/hypium';
import {
  tMinusFifteen,
  pickRemindersForEvents,
  MAX_REMINDERS_PER_PACKAGE,
} from '../main/ets/utils/ReminderCalculator';
import { AgendaEvent } from '../main/ets/model/AgendaEvent';

export default function reminderCalculatorTest(): void {
  describe('ReminderCalculator', (): void => {
    it('tMinusFifteen returns undefined for empty', 0, (): void => {
      expect(tMinusFifteen('', 0)).assertEqual(undefined);
    });

    it('tMinusFifteen returns undefined for garbage', 0, (): void => {
      expect(tMinusFifteen('not-a-date', 0)).assertEqual(undefined);
    });

    it('tMinusFifteen sets trigger to start - 15min', 0, (): void => {
      // 2026-09-14T10:00:00 = epoch 1778887200 (UTC). 本地时间依赖运行时；
      // 用绝对值校准：triggerEpochSeconds 应比 Date.parse(start)/1000 少 900。
      const start: string = '2026-09-14T10:00:00';
      const startEpoch: number = Math.floor(Date.parse(start) / 1000);
      const r = tMinusFifteen(start, startEpoch - 1000);
      expect(r !== undefined).assertTrue();
      if (r !== undefined) {
        expect(r.triggerEpochSeconds).assertEqual(startEpoch - 900);
        expect(r.alreadyPast).assertFalse();
      }
    });

    it('tMinusFifteen flags alreadyPast', 0, (): void => {
      const start: string = '2026-09-14T10:00:00';
      const startEpoch: number = Math.floor(Date.parse(start) / 1000);
      const r = tMinusFifteen(start, startEpoch + 1000);
      expect(r !== undefined).assertTrue();
      if (r !== undefined) {
        expect(r.alreadyPast).assertTrue();
      }
    });

    it('pickRemindersForEvents returns only confirmed', 0, (): void => {
      const events: AgendaEvent[] = mkEvents([
        { id: '1', status: 'confirmed', start_at: future(3600) },
        { id: '2', status: 'pending', start_at: future(7200) },
      ]);
      const now: number = Math.floor(Date.now() / 1000);
      const out = pickRemindersForEvents(events, now);
      expect(out.picked.length).assertEqual(1);
      expect(out.picked[0].id).assertEqual('1');
      expect(out.droppedCount).assertEqual(0);
    });

    it('pickRemindersForEvents skips past', 0, (): void => {
      const events: AgendaEvent[] = mkEvents([
        { id: '1', status: 'confirmed', start_at: future(-3600) },
        { id: '2', status: 'confirmed', start_at: future(3600) },
      ]);
      const now: number = Math.floor(Date.now() / 1000);
      const out = pickRemindersForEvents(events, now);
      expect(out.picked.length).assertEqual(1);
      expect(out.picked[0].id).assertEqual('2');
    });

    it('pickRemindersForEvents caps at 30', 0, (): void => {
      const arr: Partial<AgendaEvent>[] = [];
      for (let i: number = 0; i < 50; i++) {
        arr.push({ id: 'e' + String(i), status: 'confirmed', start_at: future(1800 + i * 60) });
      }
      const events: AgendaEvent[] = mkEvents(arr);
      const now: number = Math.floor(Date.now() / 1000);
      const out = pickRemindersForEvents(events, now);
      expect(out.picked.length).assertEqual(MAX_REMINDERS_PER_PACKAGE);
      expect(out.droppedCount).assertEqual(50 - MAX_REMINDERS_PER_PACKAGE);
      // 已确认优先更早的：picked[0] 应是最早的
      expect(out.picked[0].id).assertEqual('e0');
    });

    it('skips events closer than 15 minutes: their T-15 trigger is already past', 0, (): void => {
      // 这一条是 2026-10-10 单测第一次真被执行时抓出来的：上面四条当时全红，
      // 根因不是代码错，是夹具把事件排在了 T-15 死区里（触发点已在过去 ⇒ 正确地不排提醒）。
      const events: AgendaEvent[] = mkEvents([
        { id: 'soon', status: 'confirmed', start_at: future(60) },
        { id: 'far', status: 'confirmed', start_at: future(3600) },
      ]);
      const now: number = Math.floor(Date.now() / 1000);
      const out = pickRemindersForEvents(events, now);
      expect(out.picked.length).assertEqual(1);
      expect(out.picked[0].id).assertEqual('far');
    });

    it('droppedCount counts truncation only, not the ineligible', 0, (): void => {
      // 语义出处：ReminderCalculator.ets:80-87 —— 资格内的才进 eligible，
      // droppedCount = eligible.length − MAX，过去的/未确认的都不算进去。
      const arr: Partial<AgendaEvent>[] = [];
      for (let i: number = 0; i < MAX_REMINDERS_PER_PACKAGE; i++) {
        arr.push({ id: 'ok' + String(i), status: 'confirmed', start_at: future(1800 + i * 60) });
      }
      arr.push({ id: 'past', status: 'confirmed', start_at: future(-3600) });
      arr.push({ id: 'soon', status: 'confirmed', start_at: future(60) });
      arr.push({ id: 'pend', status: 'pending', start_at: future(3600) });
      const out = pickRemindersForEvents(mkEvents(arr), Math.floor(Date.now() / 1000));
      expect(out.picked.length).assertEqual(MAX_REMINDERS_PER_PACKAGE);
      expect(out.droppedCount).assertEqual(0);
    });

    it('pickRemindersForEvents sorts by time', 0, (): void => {
      const events: AgendaEvent[] = mkEvents([
        { id: 'late', status: 'confirmed', start_at: future(7200) },
        { id: 'early', status: 'confirmed', start_at: future(1800) },
      ]);
      const now: number = Math.floor(Date.now() / 1000);
      const out = pickRemindersForEvents(events, now);
      expect(out.picked[0].id).assertEqual('early');
      expect(out.picked[1].id).assertEqual('late');
    });
  });
}

function future(offsetSeconds: number): string {
  return new Date(Date.now() + offsetSeconds * 1000).toISOString();
}

function mkEvents(parts: ReadonlyArray<Partial<AgendaEvent>>): AgendaEvent[] {
  const out: AgendaEvent[] = [];
  for (let i: number = 0; i < parts.length; i++) {
    const p: Partial<AgendaEvent> = parts[i];
    const ev: AgendaEvent = {
      id: p.id ?? ('auto-' + String(i)),
      title: p.title ?? 'untitled',
      start_at: p.start_at ?? future(60),
      end_at: p.end_at,
      kind: p.kind ?? 'task',
      status: p.status ?? 'confirmed',
      source: p.source ?? 'manual',
    };
    out.push(ev);
  }
  return out;
}
