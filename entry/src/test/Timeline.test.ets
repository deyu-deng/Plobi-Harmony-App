import { describe, it, expect } from '@ohos/hypium';
import {
  mergeDay, markNow, buildTimeline, kindLabel,
  TimelineRow,
} from '../main/ets/service/Timeline';
import { AgendaEvent, Anchor, PlanItem, kindLabelOf } from '../main/ets/model/AgendaEvent';

interface TestEvidence {
  'kind': string;
}

const MEAL_EVIDENCE: TestEvidence = { 'kind': 'meal' };
const PLAN_EVIDENCE: TestEvidence = { 'kind': 'evening_plan' };

function mkEvent(id: string, title: string, startAt: string, endAt?: string): AgendaEvent {
  if (endAt !== undefined) {
    return {
      'id': id, 'title': title, 'start_at': startAt, 'end_at': endAt,
      'kind': 'task', 'status': 'confirmed', 'source': 'manual',
    };
  }
  return {
    'id': id, 'title': title, 'start_at': startAt,
    'kind': 'task', 'status': 'confirmed', 'source': 'manual',
  };
}

function mkAnchor(id: string, title: string, startAt: string, endAt: string, templateId: string, flex: boolean): Anchor {
  return {
    'id': id, 'title': title, 'start_at': startAt, 'end_at': endAt,
    'template_id': templateId, 'flex': flex,
  };
}

function mkPlan(id: string, title: string, startAt: string, endAt?: string, evidence: TestEvidence = PLAN_EVIDENCE): PlanItem {
  if (endAt !== undefined) {
    return {
      'id': id, 'title': title, 'start_at': startAt, 'end_at': endAt,
      'kind': 'meal', 'evidence': evidence,
    };
  }
  return {
    'id': id, 'title': title, 'start_at': startAt,
    'kind': 'meal', 'evidence': evidence,
  };
}

function mkNowRow(startAt: string, endAt?: string, title: string = 'T'): TimelineRow {
  if (endAt !== undefined) {
    return {
      'id': title + startAt, 'source': 'event', 'title': title,
      'start_at': startAt, 'end_at': endAt, 'kind': 'task', 'isNow': false,
    };
  }
  return {
    'id': title + startAt, 'source': 'event', 'title': title,
    'start_at': startAt, 'kind': 'task', 'isNow': false,
  };
}

function mkKindRow(kind: string): TimelineRow {
  return {
    'id': 'e', 'source': 'event', 'title': 't',
    'start_at': '2026-09-16T09:00:00+08:00', 'kind': kind, 'isNow': false,
  };
}

export default function timelineTest(): void {
  describe('Timeline.mergeDay', (): void => {
    it('returns empty for empty input', 0, (): void => {
      const out: TimelineRow[] = mergeDay([], [], []);
      expect(out.length).assertEqual(0);
    });

    it('keeps single event as-is', 0, (): void => {
      const events: AgendaEvent[] = [mkEvent('e1', 'Lunch', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00')];
      const out: TimelineRow[] = mergeDay(events, [], []);
      expect(out.length).assertEqual(1);
      expect(out[0].source).assertEqual('event');
      expect(out[0].title).assertEqual('Lunch');
      expect(out[0].isNow).assertFalse();
    });

    it('event wins over anchor with same title+minute', 0, (): void => {
      const events: AgendaEvent[] = [mkEvent('e1', '午餐', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00')];
      const anchors: Anchor[] = [mkAnchor('a1', '午餐', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00', 'lunch', false)];
      const out: TimelineRow[] = mergeDay(events, anchors, []);
      expect(out.length).assertEqual(1);
      expect(out[0].source).assertEqual('event');
    });

    it('plan wins over anchor with same title+minute', 0, (): void => {
      const anchors: Anchor[] = [mkAnchor('a1', '午餐', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00', 'lunch', false)];
      const plans: PlanItem[] = [mkPlan('p1', '午餐', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00')];
      const out: TimelineRow[] = mergeDay([], anchors, plans);
      expect(out.length).assertEqual(1);
      expect(out[0].source).assertEqual('plan');
    });

    it('event wins over plan with same title+minute (real agenda)', 0, (): void => {
      const events: AgendaEvent[] = [mkEvent('e1', '午餐', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00')];
      const plans: PlanItem[] = [mkPlan('p1', '午餐', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00')];
      const out: TimelineRow[] = mergeDay(events, [], plans);
      expect(out.length).assertEqual(1);
      expect(out[0].source).assertEqual('event');
    });

    it('two anchors same template_id: prefer non-flex', 0, (): void => {
      const anchors: Anchor[] = [
        mkAnchor('a1', 'flex lunch', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00', 'lunch', true),
        mkAnchor('a2', 'regular lunch', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00', 'lunch', false),
      ];
      const out: TimelineRow[] = mergeDay([], anchors, []);
      expect(out.length).assertEqual(1);
      expect(out[0].flex !== true).assertTrue();
      expect(out[0].title).assertEqual('regular lunch');
    });

    it('keeps anchors with different template_id separate', 0, (): void => {
      const anchors: Anchor[] = [
        mkAnchor('a1', 'lunch', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00', 'lunch', false),
        mkAnchor('a2', 'sleep', '2026-09-16T23:00:00+08:00', '2026-09-17T07:00:00+08:00', 'sleep', false),
      ];
      const out: TimelineRow[] = mergeDay([], anchors, []);
      expect(out.length).assertEqual(2);
    });

    it('keeps anchors with different start_minute separate', 0, (): void => {
      const anchors: Anchor[] = [
        mkAnchor('a1', 'lunch', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00', 'a', false),
        mkAnchor('a2', 'lunch', '2026-09-16T18:00:00+08:00', '2026-09-16T19:00:00+08:00', 'b', false),
      ];
      const out: TimelineRow[] = mergeDay([], anchors, []);
      expect(out.length).assertEqual(2);
    });

    it('sorts by start_at ASC across all sources', 0, (): void => {
      const events: AgendaEvent[] = [
        mkEvent('e3', 'C', '2026-09-16T15:00:00+08:00', '2026-09-16T16:00:00+08:00'),
        mkEvent('e1', 'A', '2026-09-16T09:00:00+08:00', '2026-09-16T10:00:00+08:00'),
      ];
      const anchors: Anchor[] = [
        mkAnchor('a2', 'B', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00', 'b', false),
      ];
      const out: TimelineRow[] = mergeDay(events, anchors, []);
      expect(out.length).assertEqual(3);
      expect(out[0].title).assertEqual('A');
      expect(out[1].title).assertEqual('B');
      expect(out[2].title).assertEqual('C');
    });

    it('empty title and empty template_id: kept as unique', 0, (): void => {
      const events: AgendaEvent[] = [
        mkEvent('e1', '', '2026-09-16T09:00:00+08:00', '2026-09-16T10:00:00+08:00'),
        mkEvent('e2', '', '2026-09-16T09:00:00+08:00', '2026-09-16T10:00:00+08:00'),
      ];
      const out: TimelineRow[] = mergeDay(events, [], []);
      expect(out.length).assertEqual(2);
    });

    it('malformed start_at does not break dedup', 0, (): void => {
      const events: AgendaEvent[] = [
        mkEvent('e1', 'A', 'not-a-date'),
        mkEvent('e2', 'A', '2026-09-16T09:00:00+08:00', '2026-09-16T10:00:00+08:00'),
      ];
      const out: TimelineRow[] = mergeDay(events, [], []);
      expect(out.length).assertEqual(2);
    });

    it('mixed: event + plan + anchor all colliding → event wins', 0, (): void => {
      const events: AgendaEvent[] = [mkEvent('e1', '午', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00')];
      const anchors: Anchor[] = [mkAnchor('a1', '午', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00', 'lunch', false)];
      const plans: PlanItem[] = [mkPlan('p1', '午', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00')];
      const out: TimelineRow[] = mergeDay(events, anchors, plans);
      expect(out.length).assertEqual(1);
      expect(out[0].source).assertEqual('event');
    });

    it('anchor and event with different minute → both kept', 0, (): void => {
      const events: AgendaEvent[] = [mkEvent('e1', '课', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00')];
      const anchors: Anchor[] = [mkAnchor('a1', '课', '2026-09-16T12:30:00+08:00', '2026-09-16T13:30:00+08:00', 'lunch', false)];
      const out: TimelineRow[] = mergeDay(events, anchors, []);
      expect(out.length).assertEqual(2);
    });
  });

  describe('Timeline.markNow', (): void => {
    const noon: number = Date.parse('2026-09-16T12:00:00+08:00');

    it('returns empty for empty rows', 0, (): void => {
      const out: TimelineRow[] = markNow([], noon);
      expect(out.length).assertEqual(0);
    });

    it('marks row where start ≤ now < end', 0, (): void => {
      const rows: TimelineRow[] = [mkNowRow('2026-09-16T11:00:00+08:00', '2026-09-16T13:00:00+08:00', 'lunch')];
      const out: TimelineRow[] = markNow(rows, noon);
      expect(out[0].isNow).assertTrue();
    });

    it('does NOT mark row starting in future', 0, (): void => {
      const rows: TimelineRow[] = [mkNowRow('2026-09-16T14:00:00+08:00', '2026-09-16T15:00:00+08:00', 'later')];
      const out: TimelineRow[] = markNow(rows, noon);
      expect(out[0].isNow).assertFalse();
    });

    it('does NOT mark row that ended in past', 0, (): void => {
      const rows: TimelineRow[] = [mkNowRow('2026-09-16T09:00:00+08:00', '2026-09-16T10:00:00+08:00', 'past')];
      const out: TimelineRow[] = markNow(rows, noon);
      expect(out[0].isNow).assertFalse();
    });

    it('marks row with no end_at if start within last 30 min', 0, (): void => {
      const rows: TimelineRow[] = [mkNowRow('2026-09-16T11:45:00+08:00', undefined, 'ddl-soon')];
      const out: TimelineRow[] = markNow(rows, noon);
      expect(out[0].isNow).assertTrue();
    });

    it('does NOT mark row with no end_at if start > 30 min ago', 0, (): void => {
      const rows: TimelineRow[] = [mkNowRow('2026-09-16T10:00:00+08:00', undefined, 'old')];
      const out: TimelineRow[] = markNow(rows, noon);
      expect(out[0].isNow).assertFalse();
    });

    it('does NOT mark row whose end_at equals now (boundary: now < end fails)', 0, (): void => {
      const rows: TimelineRow[] = [mkNowRow('2026-09-16T11:00:00+08:00', '2026-09-16T12:00:00+08:00', 'just-ended')];
      const out: TimelineRow[] = markNow(rows, noon);
      expect(out[0].isNow).assertFalse();
    });

    it('marks row whose start_at equals now (boundary: start ≤ now passes)', 0, (): void => {
      const rows: TimelineRow[] = [mkNowRow('2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00', 'just-starting')];
      const out: TimelineRow[] = markNow(rows, noon);
      expect(out[0].isNow).assertTrue();
    });

    it('marks ONLY first match when multiple rows overlap', 0, (): void => {
      const rows: TimelineRow[] = [
        mkNowRow('2026-09-16T11:00:00+08:00', '2026-09-16T13:00:00+08:00', 'first'),
        mkNowRow('2026-09-16T11:30:00+08:00', '2026-09-16T12:30:00+08:00', 'overlap'),
      ];
      const out: TimelineRow[] = markNow(rows, noon);
      expect(out[0].isNow).assertTrue();
      expect(out[1].isNow).assertFalse();
    });

    it('returns isNow=false for ALL when none match (no fake next)', 0, (): void => {
      const rows: TimelineRow[] = [
        mkNowRow('2026-09-16T08:00:00+08:00', '2026-09-16T09:00:00+08:00', 'morning'),
        mkNowRow('2026-09-16T20:00:00+08:00', '2026-09-16T21:00:00+08:00', 'evening'),
      ];
      const out: TimelineRow[] = markNow(rows, noon);
      expect(out[0].isNow).assertFalse();
      expect(out[1].isNow).assertFalse();
    });

    it('does not crash on malformed start_at', 0, (): void => {
      const rows: TimelineRow[] = [{
        'id': 'x', 'source': 'event', 'title': 'bad',
        'start_at': 'not-a-date', 'end_at': 'also-bad',
        'kind': 'task', 'isNow': false,
      }];
      const out: TimelineRow[] = markNow(rows, noon);
      expect(out[0].isNow).assertFalse();
    });

    it('does not crash on empty end_at', 0, (): void => {
      const rows: TimelineRow[] = [{
        'id': 'x', 'source': 'event', 'title': 'bad',
        'start_at': '2026-09-16T12:00:00+08:00', 'end_at': '',
        'kind': 'task', 'isNow': false,
      }];
      const out: TimelineRow[] = markNow(rows, noon);
      expect(out[0].isNow).assertTrue();
    });

    it('preserves other fields (immutability check)', 0, (): void => {
      const rows: TimelineRow[] = [{
        'id': 'x', 'source': 'anchor', 'title': 'lunch',
        'start_at': '2026-09-16T11:00:00+08:00', 'end_at': '2026-09-16T13:00:00+08:00',
        'kind': 'anchor', 'template_id': 'lunch', 'flex': false, 'isNow': false,
      }];
      const out: TimelineRow[] = markNow(rows, noon);
      expect(out[0].id).assertEqual('x');
      expect(out[0].source).assertEqual('anchor');
      expect(out[0].template_id).assertEqual('lunch');
      expect(out[0].flex !== true).assertTrue();
      expect(out[0].isNow).assertTrue();
    });

    it('does not mutate input array', 0, (): void => {
      const rows: TimelineRow[] = [mkNowRow('2026-09-16T11:00:00+08:00', '2026-09-16T13:00:00+08:00', 'lunch')];
      markNow(rows, noon);
      expect(rows[0].isNow).assertFalse();
    });
  });

  describe('Timeline.buildTimeline', (): void => {
    it('returns empty today and tomorrow for empty input', 0, (): void => {
      const out = buildTimeline({
        'todayEvents': [], 'anchors': [], 'planItems': [], 'tomorrowEvents': [],
      });
      expect(out.today.length).assertEqual(0);
      expect(out.tomorrow.length).assertEqual(0);
    });

    it('merges today; sorts tomorrow', 0, (): void => {
      const todayEvents: AgendaEvent[] = [mkEvent('e1', 'A', '2026-09-16T09:00:00+08:00', '2026-09-16T10:00:00+08:00')];
      const tomorrowEvents: AgendaEvent[] = [
        mkEvent('e2', 'Z', '2026-09-17T08:00:00+08:00', '2026-09-17T09:00:00+08:00'),
        mkEvent('e3', 'Y', '2026-09-17T07:00:00+08:00', '2026-09-17T08:00:00+08:00'),
      ];
      const out = buildTimeline({
        'todayEvents': todayEvents, 'anchors': [], 'planItems': [], 'tomorrowEvents': tomorrowEvents,
      });
      expect(out.today.length).assertEqual(1);
      expect(out.today[0].title).assertEqual('A');
      expect(out.tomorrow.length).assertEqual(2);
      expect(out.tomorrow[0].title).assertEqual('Y');
      expect(out.tomorrow[1].title).assertEqual('Z');
    });

    it('buildTimeline.tomorrow ignores anchors and plan_items', 0, (): void => {
      const tomorrowEvents: AgendaEvent[] = [mkEvent('e1', 'A', '2026-09-17T09:00:00+08:00', '2026-09-17T10:00:00+08:00')];
      const anchors: Anchor[] = [mkAnchor('a1', 'B', '2026-09-16T12:00:00+08:00', '2026-09-16T13:00:00+08:00', 'lunch', false)];
      const plans: PlanItem[] = [mkPlan('p1', 'C', '2026-09-16T13:00:00+08:00', '2026-09-16T14:00:00+08:00')];
      const out = buildTimeline({
        'todayEvents': [], 'anchors': anchors, 'planItems': plans, 'tomorrowEvents': tomorrowEvents,
      });
      expect(out.today.length).assertEqual(2);
      expect(out.tomorrow.length).assertEqual(1);
      expect(out.tomorrow[0].title).assertEqual('A');
    });
  });

  describe('Timeline.kindLabel', (): void => {
    it('anchor → 作息', 0, (): void => {
      const r: TimelineRow = {
        'id': 'a', 'source': 'anchor', 'title': 'lunch',
        'start_at': '2026-09-16T12:00:00+08:00', 'kind': 'anchor', 'isNow': false,
      };
      expect(kindLabel(r)).assertEqual('作息');
    });

    it('meeting → 会', 0, (): void => {
      expect(kindLabel(mkKindRow('meeting'))).assertEqual('会');
    });

    it('task → 事', 0, (): void => {
      expect(kindLabel(mkKindRow('task'))).assertEqual('事');
    });

    it('ddl → 截', 0, (): void => {
      expect(kindLabel(mkKindRow('ddl'))).assertEqual('截');
    });

    it('class → 课', 0, (): void => {
      expect(kindLabel(mkKindRow('class'))).assertEqual('课');
    });

    it('meal → 餐', 0, (): void => {
      expect(kindLabel(mkKindRow('meal'))).assertEqual('餐');
    });

    it('unknown kind → raw kind', 0, (): void => {
      expect(kindLabel(mkKindRow('foo'))).assertEqual('foo');
    });

    it('empty kind → 事', 0, (): void => {
      expect(kindLabel(mkKindRow(''))).assertEqual('事');
    });
  });

  describe('AgendaEvent.kindLabelOf', (): void => {
    it('meeting → 会', 0, (): void => {
      expect(kindLabelOf('meeting')).assertEqual('会');
    });

    it('task → 事', 0, (): void => {
      expect(kindLabelOf('task')).assertEqual('事');
    });

    it('ddl → 截', 0, (): void => {
      expect(kindLabelOf('ddl')).assertEqual('截');
    });

    it('class → 课', 0, (): void => {
      expect(kindLabelOf('class')).assertEqual('课');
    });

    it('meal → 餐', 0, (): void => {
      expect(kindLabelOf('meal')).assertEqual('餐');
    });

    it('unknown kind → raw kind', 0, (): void => {
      expect(kindLabelOf('foo')).assertEqual('foo');
    });

    it('empty kind → 事', 0, (): void => {
      expect(kindLabelOf('')).assertEqual('事');
    });
  });
}