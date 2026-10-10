import { describe, it, expect } from '@ohos/hypium';
import { parseDayPayload, parseCachedDays, serializeCachedDays } from '../main/ets/service/DayParser';
import { DayPayload, Anchor } from '../main/ets/model/AgendaEvent';

interface TestEvent {
  id: string;
  title: string;
  start_at: string;
  end_at: string | null;
  kind: string;
  status: string;
  source: string;
  location?: string;
  notes?: string;
  overlaps?: string[];
}

interface TestAnchor {
  id: string;
  title: string;
  start_at: string;
  end_at: string;
  template_id: string;
  flex: boolean;
}

interface TestPlanItem {
  id: string;
  title: string;
  start_at: string;
  end_at: string;
  kind: string;
  evidence: Object;
}

interface TestEvidence {
  'kind': string;
}

const PLAN_EVIDENCE: TestEvidence = { 'kind': 'evening_plan' };

/** T4 周缓存用例：造一个指定日期的空单日快照。 */
function emptyDayPayload(date: string): DayPayload {
  const dp: DayPayload = {
    'date': date,
    'events': [],
    'anchors': [],
    'plan_items': [],
    'conflicts': [],
    'plan_status': null,
  };
  return dp;
}

interface TestConflict {
  left_id: string;
  right_id: string;
  start_at: string;
  end_at: string;
}

interface TestDayPayload {
  date: string;
  events: TestEvent[];
  anchors: TestAnchor[];
  plan_items: TestPlanItem[];
  conflicts: TestConflict[];
  plan_status: string | null;
}

export default function dayParserTest(): void {
  describe('DayParser.parseDayPayload', (): void => {
    it('parses a well-formed payload', 0, (): void => {
      const ev: TestEvent = {
        'id': 'e1',
        'title': '高数课',
        'start_at': '2026-09-14T09:00:00',
        'end_at': '2026-09-14T10:40:00',
        'kind': 'class',
        'status': 'confirmed',
        'source': 'timetable',
      };
      const anchor1: TestAnchor = {
        'id': 'routine:lunch',
        'title': '午饭',
        'start_at': '2026-09-14T12:00:00',
        'end_at': '2026-09-14T12:40:00',
        'template_id': 'lunch',
        'flex': false,
      };
      const anchor2: TestAnchor = {
        'id': 'routine:sleep',
        'title': '觉',
        'start_at': '2026-09-14T23:30:00',
        'end_at': '2026-09-15T07:30:00',
        'template_id': 'sleep',
        'flex': false,
      };
      const planEvidence: Object = PLAN_EVIDENCE;
      const plan: TestPlanItem = {
        'id': 'p1',
        'title': '推进 Plobi',
        'start_at': '2026-09-14T14:00:00',
        'end_at': '2026-09-14T16:00:00',
        'kind': 'task',
        'evidence': planEvidence,
      };
      const conflict: TestConflict = {
        'left_id': 'e1',
        'right_id': 'e2',
        'start_at': '2026-09-14T10:00:00',
        'end_at': '2026-09-14T10:30:00',
      };
      const payload: TestDayPayload = {
        'date': '2026-09-14',
        'events': [ev],
        'anchors': [anchor1, anchor2],
        'plan_items': [plan],
        'conflicts': [conflict],
        'plan_status': 'pending',
      };
      const raw: string = JSON.stringify(payload);
      const p = parseDayPayload(raw);
      expect(p.date).assertEqual('2026-09-14');
      expect(p.events.length).assertEqual(1);
      expect(p.events[0].id).assertEqual('e1');
      expect(p.anchors.length).assertEqual(2);
      expect(p.anchors[1].template_id).assertEqual('sleep');
      expect(p.anchors[1].flex).assertFalse();
      expect(p.plan_items.length).assertEqual(1);
      expect(p.conflicts.length).assertEqual(1);
      expect(p.plan_status).assertEqual('pending');
    });

    it('handles empty arrays and null plan_status', 0, (): void => {
      const payload: TestDayPayload = {
        'date': '2026-09-14',
        'events': [],
        'anchors': [],
        'plan_items': [],
        'conflicts': [],
        'plan_status': null,
      };
      const p = parseDayPayload(JSON.stringify(payload));
      expect(p.date).assertEqual('2026-09-14');
      expect(p.events.length).assertEqual(0);
      expect(p.anchors.length).assertEqual(0);
      expect(p.plan_items.length).assertEqual(0);
      expect(p.conflicts.length).assertEqual(0);
      expect(p.plan_status).assertEqual(null);
    });

    it('flags flex:true anchor', 0, (): void => {
      const anchor: TestAnchor = {
        'id': 'routine:lunch',
        'title': '午饭',
        'start_at': '2026-09-14T13:00:00',
        'end_at': '2026-09-14T13:40:00',
        'template_id': 'lunch',
        'flex': true,
      };
      const payload: TestDayPayload = {
        'date': '2026-09-14',
        'events': [],
        'anchors': [anchor],
        'plan_items': [],
        'conflicts': [],
        'plan_status': null,
      };
      const p = parseDayPayload(JSON.stringify(payload));
      expect(p.anchors[0].flex).assertTrue();
    });

    it('returns empty on malformed JSON', 0, (): void => {
      const p = parseDayPayload('{not-json');
      expect(p.date).assertEqual('');
      expect(p.anchors.length).assertEqual(0);
    });

    it('returns empty on non-object root', 0, (): void => {
      const p = parseDayPayload('"hello"');
      expect(p.date).assertEqual('');
    });

    it('skips anchors missing start_at', 0, (): void => {
      const broken: TestAnchor = {
        'id': 'broken',
        'title': '?',
        'start_at': '',
        'end_at': '',
        'template_id': 'x',
        'flex': false,
      };
      const good: TestAnchor = {
        'id': 'routine:lunch',
        'title': '午饭',
        'start_at': '2026-09-14T12:00:00',
        'end_at': '2026-09-14T12:40:00',
        'template_id': 'lunch',
        'flex': false,
      };
      const payload: TestDayPayload = {
        'date': '2026-09-14',
        'events': [],
        'anchors': [broken, good],
        'plan_items': [],
        'conflicts': [],
        'plan_status': null,
      };
      const p = parseDayPayload(JSON.stringify(payload));
      expect(p.anchors.length).assertEqual(1);
      expect(p.anchors[0].id).assertEqual('routine:lunch');
    });

    it('passes through location / notes / overlaps', 0, (): void => {
      const ev: TestEvent = {
        'id': 'e1',
        'title': '课',
        'start_at': '2026-09-14T09:00:00',
        'end_at': '2026-09-14T10:40:00',
        'kind': 'class',
        'status': 'confirmed',
        'source': 'timetable',
        'location': '紫金港西2-415',
        'notes': '带课本',
        'overlaps': ['e2'],
      };
      const payload: TestDayPayload = {
        'date': '2026-09-14',
        'events': [ev],
        'anchors': [],
        'plan_items': [],
        'conflicts': [],
        'plan_status': null,
      };
      const p = parseDayPayload(JSON.stringify(payload));
      expect(p.events[0].location).assertEqual('紫金港西2-415');
      expect(p.events[0].notes).assertEqual('带课本');
      expect(p.events[0].overlaps !== undefined).assertTrue();
      if (p.events[0].overlaps !== undefined) {
        expect(p.events[0].overlaps.length).assertEqual(1);
        expect(p.events[0].overlaps[0]).assertEqual('e2');
      }
    });

    it('end_at null stays undefined (no fake duration)', 0, (): void => {
      const ev: TestEvent = {
        'id': 'e1',
        'title': '组会',
        'start_at': '2026-09-14T10:00:00',
        'end_at': null,
        'kind': 'meeting',
        'status': 'confirmed',
        'source': 'manual',
      };
      const payload: TestDayPayload = {
        'date': '2026-09-14',
        'events': [ev],
        'anchors': [],
        'plan_items': [],
        'conflicts': [],
        'plan_status': null,
      };
      const p = parseDayPayload(JSON.stringify(payload));
      expect(p.events[0].end_at).assertEqual(undefined);
    });
  });

  describe('DayParser.parseCachedDays / serializeCachedDays (T4 周缓存)', (): void => {
    it('round-trips a week of seven days', 0, (): void => {
      const days: Map<string, DayPayload> = new Map<string, DayPayload>();
      for (let i: number = 0; i < 7; i++) {
        const d: string = '2026-10-1' + String(2 + i);
        days.set(d, emptyDayPayload(d));
      }
      const anchor: Anchor = {
        'id': 'routine:lunch',
        'title': '午饭',
        'start_at': '2026-10-15T12:00:00',
        'end_at': '2026-10-15T12:40:00',
        'template_id': 'lunch',
        'flex': false,
      };
      const wed: DayPayload | undefined = days.get('2026-10-15');
      if (wed !== undefined) {
        wed.anchors = [anchor];
      }
      const raw: string = serializeCachedDays(days);
      const back: Map<string, DayPayload> = parseCachedDays(raw);
      expect(back.size).assertEqual(7);
      expect(back.has('2026-10-12')).assertTrue();
      expect(back.has('2026-10-18')).assertTrue();
      const wedBack: DayPayload | undefined = back.get('2026-10-15');
      expect(wedBack !== undefined).assertTrue();
      if (wedBack !== undefined) {
        expect(wedBack.anchors.length).assertEqual(1);
        expect(wedBack.anchors[0].template_id).assertEqual('lunch');
      }
    });

    it('migrates legacy single-day format by its own date', 0, (): void => {
      const legacy: TestDayPayload = {
        'date': '2026-10-12',
        'events': [],
        'anchors': [],
        'plan_items': [],
        'conflicts': [],
        'plan_status': null,
      };
      const back: Map<string, DayPayload> = parseCachedDays(JSON.stringify(legacy));
      expect(back.size).assertEqual(1);
      const dp: DayPayload | undefined = back.get('2026-10-12');
      expect(dp !== undefined).assertTrue();
    });

    it('returns empty map on empty / malformed string', 0, (): void => {
      expect(parseCachedDays('').size).assertEqual(0);
      expect(parseCachedDays('{not-json').size).assertEqual(0);
    });

    it('returns empty map on non-object root', 0, (): void => {
      expect(parseCachedDays('"hello"').size).assertEqual(0);
      expect(parseCachedDays('[1,2,3]').size).assertEqual(0);
    });

    it('skips entries whose payload has no date', 0, (): void => {
      const raw: string = '{"days":{'
        + '"2026-10-13":{"date":"2026-10-13","events":[],"anchors":[],"plan_items":[],"conflicts":[],"plan_status":null},'
        + '"broken":{"events":[],"anchors":[],"plan_items":[],"conflicts":[],"plan_status":null}'
        + '}}';
      const back: Map<string, DayPayload> = parseCachedDays(raw);
      expect(back.size).assertEqual(1);
      expect(back.has('2026-10-13')).assertTrue();
    });

    it('legacy payload without date yields empty map', 0, (): void => {
      const raw: string = '{"events":[],"anchors":[],"plan_items":[],"conflicts":[],"plan_status":null}';
      expect(parseCachedDays(raw).size).assertEqual(0);
    });
  });
}