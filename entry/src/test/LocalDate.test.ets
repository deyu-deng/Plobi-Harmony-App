import { describe, it, expect } from '@ohos/hypium';
import { localDateIso, todayLocalIso, localDateOfIso } from '../main/ets/utils/LocalDate';

export default function localDateTest(): void {
  describe('LocalDate.localDateIso', (): void => {
    it('formats local date as YYYY-MM-DD', 0, (): void => {
      // Use local-timezone date components so the test is timezone-independent.
      const d: Date = new Date(2026, 8, 14, 9, 0, 0);
      expect(localDateIso(d)).assertEqual('2026-09-14');
    });

    it('zero-pads single digit month/day', 0, (): void => {
      const d: Date = new Date(2026, 0, 5, 0, 0, 0);
      expect(localDateIso(d)).assertEqual('2026-01-05');
    });

    it('cross-year rollover handled', 0, (): void => {
      const d: Date = new Date(2026, 11, 31, 23, 59, 0);
      expect(localDateIso(d)).assertEqual('2026-12-31');
    });
  });

  describe('LocalDate.todayLocalIso', (): void => {
    it('matches local YYYY-MM-DD of system clock', 0, (): void => {
      const now: Date = new Date();
      const expected: string = localDateIso(now);
      expect(todayLocalIso()).assertEqual(expected);
    });
  });

  describe('LocalDate.localDateOfIso', (): void => {
    it('extracts local calendar day from ISO', 0, (): void => {
      // 2026-09-14 23:00 in Asia/Shanghai = 2026-09-14 15:00 UTC; the local
      // component is what matters, not the UTC slice.
      const iso: string = '2026-09-14T23:00:00';
      expect(localDateOfIso(iso)).assertEqual('2026-09-14');
    });

    it('returns undefined for empty', 0, (): void => {
      expect(localDateOfIso('')).assertEqual(undefined);
    });

    it('returns undefined for garbage', 0, (): void => {
      expect(localDateOfIso('not-a-date')).assertEqual(undefined);
    });

    it('returns undefined for undefined', 0, (): void => {
      expect(localDateOfIso(undefined)).assertEqual(undefined);
    });
  });
}