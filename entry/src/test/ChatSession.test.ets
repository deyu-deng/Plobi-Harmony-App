import { describe, it, expect } from '@ohos/hypium';
import { pickL1Row, extractSessionIdFromOverview } from '../main/ets/service/ChatSession';

export default function chatSessionTest(): void {
  describe('ChatSession.pickL1Row', (): void => {
    it('finds L1 by role=l1_secretary with sessionId', 0, (): void => {
      const raw: string = JSON.stringify([
        { id: 'a', role: 'l2_project', sessionId: 'l2-sess' },
        { id: 'master', role: 'l1_secretary', sessionId: 'l1-sess-1', name: '总秘书' },
      ]);
      const l1 = pickL1Row(raw);
      expect(l1 !== undefined).assertTrue();
      if (l1 !== undefined) {
        expect(l1.agentId).assertEqual('master');
        expect(l1.sessionId).assertEqual('l1-sess-1');
        expect(l1.role).assertEqual('l1_secretary');
      }
    });

    it('matches secretary by role substring', 0, (): void => {
      const raw: string = JSON.stringify([
        { id: 'agenda-secretary', role: 'secretary', sessionId: 'sess-1', name: '日程秘书' },
      ]);
      const l1 = pickL1Row(raw);
      expect(l1 !== undefined).assertTrue();
      if (l1 !== undefined) {
        expect(l1.sessionId).assertEqual('sess-1');
      }
    });

    it('matches L1 by name substring (Chinese alias)', 0, (): void => {
      const raw: string = JSON.stringify([
        { id: 'master', role: 'master', name: '总秘书', sessionId: 'sess-x' },
      ]);
      const l1 = pickL1Row(raw);
      expect(l1 !== undefined).assertTrue();
      if (l1 !== undefined) {
        expect(l1.sessionId).assertEqual('sess-x');
      }
    });

    it('skips L1 row with empty sessionId', 0, (): void => {
      const raw: string = JSON.stringify([
        { id: 'master', role: 'l1_secretary', sessionId: '', name: '总秘书' },
      ]);
      const l1 = pickL1Row(raw);
      expect(l1).assertEqual(undefined);
    });

    it('skips L1 row without sessionId field at all', 0, (): void => {
      const raw: string = JSON.stringify([
        { id: 'master', role: 'l1_secretary', name: '总秘书' },
      ]);
      const l1 = pickL1Row(raw);
      expect(l1).assertEqual(undefined);
    });

    it('returns undefined for L2-only list', 0, (): void => {
      const raw: string = JSON.stringify([
        { id: 'a', role: 'l2_project', sessionId: 'sess-a', name: '项目 A' },
        { id: 'b', role: 'l2_agenda', sessionId: 'sess-b', name: '日程秘书' },
      ]);
      expect(pickL1Row(raw)).assertEqual(undefined);
    });

    it('returns undefined on empty list', 0, (): void => {
      expect(pickL1Row('[]')).assertEqual(undefined);
    });

    it('returns undefined on malformed JSON', 0, (): void => {
      expect(pickL1Row('{not-json')).assertEqual(undefined);
    });

    it('returns undefined on non-array root', 0, (): void => {
      expect(pickL1Row('{"foo":"bar"}')).assertEqual(undefined);
    });

    it('skips row missing id', 0, (): void => {
      const raw: string = JSON.stringify([
        { role: 'l1_secretary', sessionId: 's1' },
        { id: 'master', role: 'l1_secretary', sessionId: 's2' },
      ]);
      const l1 = pickL1Row(raw);
      expect(l1 !== undefined).assertTrue();
      if (l1 !== undefined) {
        expect(l1.sessionId).assertEqual('s2');
      }
    });
  });

  describe('ChatSession.extractSessionIdFromOverview', (): void => {
    interface OverviewShape {
      agent: OverviewAgent;
      sessionId: string;
      todayCostUsd: number;
      todayTokens: number;
      projectPath: string;
    }

    interface OverviewAgent {
      id: string;
      role: string;
      name: string;
    }

    it('extracts sessionId from overview JSON', 0, (): void => {
      const ov: OverviewShape = {
        'agent': { 'id': 'master', 'role': 'l1_secretary', 'name': '总秘书' },
        'sessionId': 'sess-overview-1',
        'todayCostUsd': 0,
        'todayTokens': 0,
        'projectPath': '',
      };
      const raw: string = JSON.stringify(ov);
      expect(extractSessionIdFromOverview(raw)).assertEqual('sess-overview-1');
    });

    it('returns undefined on missing sessionId', 0, (): void => {
      expect(extractSessionIdFromOverview('{}')).assertEqual(undefined);
    });

    it('returns undefined on empty sessionId', 0, (): void => {
      expect(extractSessionIdFromOverview('{"sessionId":""}')).assertEqual(undefined);
    });

    it('returns undefined on malformed JSON', 0, (): void => {
      expect(extractSessionIdFromOverview('xxx')).assertEqual(undefined);
    });
  });
}