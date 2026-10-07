import { describe, it, expect } from '@ohos/hypium';
import { localDateIso, todayLocalIso, tomorrowLocalIso, localDateOfIso } from '../main/ets/utils/LocalDate';

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

  describe('LocalDate.tomorrowLocalIso', (): void => {
    it('is exactly one local day after today', 0, (): void => {
      const now: Date = new Date();
      const expected: string = localDateIso(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1));
      expect(tomorrowLocalIso()).assertEqual(expected);
    });

    it('matches YYYY-MM-DD shape', 0, (): void => {
      const re: RegExp = new RegExp('^[0-9]{4}-[0-9]{2}-[0-9]{2}$');
      expect(re.test(tomorrowLocalIso())).assertTrue();
    });

    it('month rollover via Date constructor day overflow', 0, (): void => {
      // tomorrowLocalIso 的同款机制：Date 构造器把 1 月 32 日进位为 2 月 1 日。
      expect(localDateIso(new Date(2026, 0, 32))).assertEqual('2026-02-01');
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