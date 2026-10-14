import { describe, it, expect } from '@ohos/hypium';
import { AgendaEvent } from '../main/ets/model/AgendaEvent';
import {
  MAX_EVENTS_PER_DAY,
  WeekBucketResult,
  WeekColumn,
  bucketWeek,
  buildWeekColumns,
  dayFromLocalIso,
  dayEndBound,
  dayStartBound,
  mondayOfLocalDay,
  weekDaysFromMonday,
} from '../main/ets/service/WeekView';

function mkEvent(id: string, startIso: string, status: string): AgendaEvent {
  const e: AgendaEvent = {
    id: id,
    title: 'T' + id,
    start_at: startIso,
    kind: 'class',
    status: status,
    source: 'timetable',
  };
  return e;
}

/** 期望值由独立日历算法（python datetime.weekday()）算出，不是照实现回填的。 */
export default function weekViewTest(): void {
  describe('WeekView.dayFromLocalIso', (): void => {
    it('accepts a valid local day', 0, (): void => {
      const d: Date | undefined = dayFromLocalIso('2026-10-10');
      expect(d !== undefined).assertTrue();
      if (d !== undefined) {
        expect(d.getFullYear()).assertEqual(2026);
        expect(d.getMonth()).assertEqual(9);
        expect(d.getDate()).assertEqual(10);
      }
    });

    it('rejects impossible dates the Date constructor would silently carry', 0, (): void => {
      expect(dayFromLocalIso('2026-02-30') === undefined).assertTrue();
      expect(dayFromLocalIso('2026-13-01') === undefined).assertTrue();
      expect(dayFromLocalIso('2026-00-10') === undefined).assertTrue();
    });

    it('rejects malformed strings', 0, (): void => {
      expect(dayFromLocalIso('') === undefined).assertTrue();
      expect(dayFromLocalIso('2026-10-10T08:00') === undefined).assertTrue();
      expect(dayFromLocalIso('2026-10-1') === undefined).assertTrue();
    });
  });

  describe('WeekView.mondayOfLocalDay', (): void => {
    it('saturday maps to the monday six days back', 0, (): void => {
      expect(mondayOfLocalDay('2026-10-10')).assertEqual('2026-10-05');
    });

    it('monday maps to itself and sunday maps to the previous monday', 0, (): void => {
      expect(mondayOfLocalDay('2026-10-05')).assertEqual('2026-10-05');
      expect(mondayOfLocalDay('2026-10-11')).assertEqual('2026-10-05');
    });

    it('crosses the year without string arithmetic', 0, (): void => {
      expect(mondayOfLocalDay('2027-01-01')).assertEqual('2026-12-28');
      expect(mondayOfLocalDay('2026-12-31')).assertEqual('2026-12-28');
      expect(mondayOfLocalDay('2026-01-01')).assertEqual('2025-12-29');
    });

    it('crosses the month and handles a leap february', 0, (): void => {
      expect(mondayOfLocalDay('2026-11-01')).assertEqual('2026-10-26');
      expect(mondayOfLocalDay('2028-03-01')).assertEqual('2028-02-28');
    });

    it('returns empty string on bad input instead of throwing', 0, (): void => {
      expect(mondayOfLocalDay('')).assertEqual('');
      expect(mondayOfLocalDay('garbage')).assertEqual('');
    });
  });

  describe('WeekView.weekDaysFromMonday', (): void => {
    it('lays out seven ascending days', 0, (): void => {
      const days: string[] = weekDaysFromMonday('2026-10-05');
      expect(days.length).assertEqual(7);
      expect(days[0]).assertEqual('2026-10-05');
      expect(days[6]).assertEqual('2026-10-11');
    });

    it('a year-crossing week really contains both years', 0, (): void => {
      const days: string[] = weekDaysFromMonday('2026-12-28');
      expect(days[3]).assertEqual('2026-12-31');
      expect(days[4]).assertEqual('2027-01-01');
      expect(days[6]).assertEqual('2027-01-03');
    });

    it('a leap week contains february 29', 0, (): void => {
      const days: string[] = weekDaysFromMonday('2028-02-28');
      expect(days[1]).assertEqual('2028-02-29');
      expect(days[2]).assertEqual('2028-03-01');
    });

    it('bad monday yields no days', 0, (): void => {
      expect(weekDaysFromMonday('2026-02-30').length).assertEqual(0);
    });
  });

  describe('WeekView.bucketWeek', (): void => {
    const mon: string = '2026-10-05';
    const today: string = '2026-10-10';

    it('always returns seven columns even with no events', 0, (): void => {
      const r: WeekBucketResult = bucketWeek([], mon, today);
      expect(r.columns.length).assertEqual(7);
      expect(r.droppedCount).assertEqual(0);
      expect(r.invalidCount).assertEqual(0);
    });

    it('empty columns for a bad week anchor', 0, (): void => {
      const r: WeekBucketResult = bucketWeek([mkEvent('1', '2026-10-10T08:00:00', 'confirmed')], 'nope', today);
      expect(r.columns.length).assertEqual(0);
    });

    it('splits confirmed and pending into separate buckets', 0, (): void => {
      const evs: AgendaEvent[] = [
        mkEvent('a', '2026-10-10T08:00:00', 'confirmed'),
        mkEvent('b', '2026-10-12T10:00:00', 'pending'),
        mkEvent('c', '2026-10-10T10:00:00', 'pending'),
      ];
      const r: WeekBucketResult = bucketWeek(evs, mon, today);
      const sat: WeekColumn = r.columns[5];
      expect(sat.events.length).assertEqual(1);
      expect(sat.pending.length).assertEqual(1);
      expect(sat.pending[0].id).assertEqual('c');
      expect(r.droppedCount).assertEqual(1);
    });

    it('sorts each bucket by start time ascending', 0, (): void => {
      const evs: AgendaEvent[] = [
        mkEvent('late', '2026-10-10T18:50:00', 'confirmed'),
        mkEvent('early', '2026-10-10T08:00:00', 'confirmed'),
        mkEvent('mid', '2026-10-10T13:25:00', 'confirmed'),
      ];
      const r: WeekBucketResult = bucketWeek(evs, mon, today);
      const ids: string[] = [];
      const list: AgendaEvent[] = r.columns[5].events;
      for (let i: number = 0; i < list.length; i++) {
        ids.push(list[i].id);
      }
      expect(ids.join(',')).assertEqual('early,mid,late');
    });

    it('counts unparseable start_at separately instead of dropping silently', 0, (): void => {
      const evs: AgendaEvent[] = [
        mkEvent('bad', '', 'confirmed'),
        mkEvent('worse', 'not-a-date', 'pending'),
        mkEvent('ok', '2026-10-09T09:00:00', 'confirmed'),
      ];
      const r: WeekBucketResult = bucketWeek(evs, mon, today);
      expect(r.invalidCount).assertEqual(2);
      expect(r.droppedCount).assertEqual(0);
      expect(r.columns[4].events.length).assertEqual(1);
    });

    it('marks today and past days, never today as past', 0, (): void => {
      const r: WeekBucketResult = bucketWeek([], mon, today);
      expect(r.columns[0].isPast).assertTrue();
      expect(r.columns[5].isToday).assertTrue();
      expect(r.columns[5].isPast).assertFalse();
      expect(r.columns[6].isPast).assertFalse();
      expect(r.columns[6].dateIso).assertEqual('2026-10-11');
    });

    it('overflow counts beyond the display cap but never truncates the data', 0, (): void => {
      const evs: AgendaEvent[] = [];
      for (let i: number = 0; i < MAX_EVENTS_PER_DAY + 3; i++) {
        const hh: string = i < 10 ? '0' + String(i) : String(i);
        evs.push(mkEvent('e' + String(i), '2026-10-10T' + hh + ':00:00', 'confirmed'));
      }
      const r: WeekBucketResult = bucketWeek(evs, mon, today);
      expect(r.columns[5].events.length).assertEqual(MAX_EVENTS_PER_DAY + 3);
      expect(r.columns[5].overflowCount).assertEqual(3);
    });

    it('the week before a leap day keeps february 29 inside the window', 0, (): void => {
      const evs: AgendaEvent[] = [
        mkEvent('leap', '2028-02-29T12:00:00', 'confirmed'),
        mkEvent('out', '2028-03-06T12:00:00', 'confirmed'),
      ];
      const r: WeekBucketResult = bucketWeek(evs, '2028-02-28', '2028-02-29');
      expect(r.columns[1].events.length).assertEqual(1);
      expect(r.columns[1].isToday).assertTrue();
      expect(r.droppedCount).assertEqual(1);
    });
  });

  describe('WeekView.buildWeekColumns', (): void => {
    it('an explicit anchor day drives the week window', 0, (): void => {
      const r: WeekBucketResult = buildWeekColumns([mkEvent('x', '2026-10-10T08:00:00', 'confirmed')], '2026-10-10');
      expect(r.columns.length).assertEqual(7);
      expect(r.columns[5].events.length).assertEqual(1);
    });

    it('an empty anchor falls back to the device local day and still yields a full week', 0, (): void => {
      const r: WeekBucketResult = buildWeekColumns([], '');
      expect(r.columns.length).assertEqual(7);
      expect(r.columns[0].dayIndex).assertEqual(0);
      let todayFound: number = 0;
      for (let i: number = 0; i < r.columns.length; i++) {
        if (r.columns[i].isToday) {
          todayFound = todayFound + 1;
        }
      }
      expect(todayFound).assertEqual(1);
    });

    it('dayStartBound pads a bare date to the local day start', 0, (): void => {
      expect(dayStartBound('2026-10-05')).assertEqual('2026-10-05T00:00:00');
    });

    it('dayEndBound pads a bare date to the last instant of that day', 0, (): void => {
      // 后端把裸日期 to 当 00:00:00（实测丢过周日整天两条），右界必须补到日末。
      expect(dayEndBound('2026-10-11')).assertEqual('2026-10-11T23:59:59');
    });

    it('both bounds are idempotent on values that already carry a time', 0, (): void => {
      expect(dayStartBound('2026-10-05T08:30:00')).assertEqual('2026-10-05T08:30:00');
      expect(dayEndBound('2026-10-11T23:59:59')).assertEqual('2026-10-11T23:59:59');
    });

    it('bounds pass garbage through instead of guessing', 0, (): void => {
      expect(dayStartBound('')).assertEqual('');
      expect(dayEndBound('not-a-date')).assertEqual('not-a-date');
    });
  });
}
