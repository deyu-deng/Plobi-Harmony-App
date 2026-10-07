import { describe, it, expect } from '@ohos/hypium';
import { formatEventLine, formatHHmm, formatLocalNowHHmm, formatTimeRange, padTwo, parseLocalTime } from '../main/ets/utils/TimeFormat';

export default function timeFormatTest(): void {
  describe('TimeFormat', (): void => {
    it('parseLocalTime handles empty', 0, (): void => {
      const d: Date | undefined = parseLocalTime('');
      expect(d === undefined).assertTrue();
    });

    it('parseLocalTime handles garbage', 0, (): void => {
      const d: Date | undefined = parseLocalTime('not-a-date');
      expect(d === undefined).assertTrue();
    });

    it('parseLocalTime parses ISO', 0, (): void => {
      const d: Date | undefined = parseLocalTime('2026-09-14T09:00:00');
      expect(d !== undefined).assertTrue();
      if (d !== undefined) {
        expect(d.getHours()).assertEqual(9);
        expect(d.getMinutes()).assertEqual(0);
      }
    });

    it('formatHHmm returns HH:MM', 0, (): void => {
      expect(formatHHmm('2026-09-14T09:05:00')).assertEqual('09:05');
      expect(formatHHmm('2026-09-14T23:59:00')).assertEqual('23:59');
    });

    it('formatHHmm returns --:-- for invalid', 0, (): void => {
      expect(formatHHmm('')).assertEqual('--:--');
      expect(formatHHmm('bad')).assertEqual('--:--');
    });

    it('formatEventLine with end_at', 0, (): void => {
      const line: string = formatEventLine('高数课', '2026-09-14T09:00:00', '2026-09-14T10:40:00');
      expect(line).assertEqual('09:00–10:40  高数课');
    });

    it('formatEventLine with null end_at does not fabricate', 0, (): void => {
      const line: string = formatEventLine('组会', '2026-09-14T10:00:00', undefined);
      expect(line).assertContain('10:00');
      expect(line).assertContain('未写结束');
      expect(line).assertContain('组会');
      // 不准补 1 小时 / 不准编 9:00
      expect(line.indexOf('11:00')).assertEqual(-1);
    });

    it('formatEventLine with empty end_at does not fabricate', 0, (): void => {
      const line: string = formatEventLine('任务', '2026-09-14T15:00:00', '');
      expect(line).assertContain('15:00');
      expect(line).assertContain('未写结束');
    });
  });

  describe('TimeFormat.padTwo', (): void => {
    it('pads single digit to two chars', 0, (): void => {
      expect(padTwo(0)).assertEqual('00');
      expect(padTwo(9)).assertEqual('09');
    });

    it('keeps two-digit numbers as-is', 0, (): void => {
      expect(padTwo(10)).assertEqual('10');
      expect(padTwo(59)).assertEqual('59');
    });
  });

  describe('TimeFormat.formatTimeRange', (): void => {
    it('with end renders start–end', 0, (): void => {
      expect(formatTimeRange('2026-09-14T09:00:00', '2026-09-14T10:40:00')).assertEqual('09:00–10:40');
    });

    it('without end renders 未写结束', 0, (): void => {
      expect(formatTimeRange('2026-09-14T10:00:00', undefined)).assertEqual('10:00 · 未写结束');
    });

    it('empty end renders 未写结束', 0, (): void => {
      expect(formatTimeRange('2026-09-14T10:00:00', '')).assertEqual('10:00 · 未写结束');
    });

    it('bad start ISO renders --:--', 0, (): void => {
      expect(formatTimeRange('not-a-date', '2026-09-14T10:40:00')).assertEqual('--:--');
      expect(formatTimeRange('', undefined)).assertEqual('--:--');
    });

    it('bad end ISO falls back to 未写结束 (no fabricated time)', 0, (): void => {
      expect(formatTimeRange('2026-09-14T10:00:00', 'garbage')).assertEqual('10:00 · 未写结束');
    });
  });

  describe('TimeFormat.formatLocalNowHHmm', (): void => {
    it('matches HH:MM shape', 0, (): void => {
      const re: RegExp = new RegExp('^([01][0-9]|2[0-3]):[0-5][0-9]$');
      expect(re.test(formatLocalNowHHmm())).assertTrue();
    });
  });
}
