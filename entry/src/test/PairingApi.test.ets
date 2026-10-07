import { describe, it, expect } from '@ohos/hypium';
import {
  isSixDigitCode,
  isValidDeviceName,
  parsePairResponse,
  parseRetryAfterSeconds,
  resolveDeviceName,
} from '../main/ets/service/PairingApi';

function repeatChar(ch: string, times: number): string {
  let out: string = '';
  for (let i: number = 0; i < times; i++) {
    out += ch;
  }
  return out;
}

export default function pairingApiTest(): void {
  describe('PairingApi.isSixDigitCode', (): void => {
    it('accepts exactly six digits', 0, (): void => {
      expect(isSixDigitCode('123456')).assertTrue();
      expect(isSixDigitCode('000000')).assertTrue();
    });

    it('rejects non-six-digit input', 0, (): void => {
      expect(isSixDigitCode('12345')).assertFalse();
      expect(isSixDigitCode('1234567')).assertFalse();
      expect(isSixDigitCode('123 45')).assertFalse();
      expect(isSixDigitCode('abcdef')).assertFalse();
      expect(isSixDigitCode('')).assertFalse();
    });
  });

  describe('PairingApi.resolveDeviceName', (): void => {
    it('empty or whitespace falls back to default', 0, (): void => {
      expect(resolveDeviceName('')).assertEqual('Plobi 平板');
      expect(resolveDeviceName('   ')).assertEqual('Plobi 平板');
    });

    it('trims surrounding whitespace', 0, (): void => {
      expect(resolveDeviceName('  客厅平板  ')).assertEqual('客厅平板');
    });
  });

  describe('PairingApi.isValidDeviceName', (): void => {
    it('accepts up to 64 chars', 0, (): void => {
      expect(isValidDeviceName(repeatChar('名', 64))).assertTrue();
    });

    it('rejects longer than 64 chars', 0, (): void => {
      expect(isValidDeviceName(repeatChar('名', 65))).assertFalse();
    });

    it('empty is valid (resolved to default later)', 0, (): void => {
      expect(isValidDeviceName('')).assertTrue();
    });
  });

  describe('PairingApi.parsePairResponse', (): void => {
    it('parses complete response', 0, (): void => {
      const raw: string = '{"deviceId":"dev-1","token":"t-1","scopes":["agenda"]}';
      const parsed = parsePairResponse(raw);
      expect(parsed !== undefined).assertTrue();
      if (parsed !== undefined) {
        expect(parsed.deviceId).assertEqual('dev-1');
        expect(parsed.token).assertEqual('t-1');
      }
    });

    it('missing token returns undefined', 0, (): void => {
      const parsed = parsePairResponse('{"deviceId":"dev-1"}');
      expect(parsed === undefined).assertTrue();
    });

    it('missing deviceId returns undefined', 0, (): void => {
      const parsed = parsePairResponse('{"token":"t-1"}');
      expect(parsed === undefined).assertTrue();
    });

    it('empty token returns undefined', 0, (): void => {
      const parsed = parsePairResponse('{"deviceId":"dev-1","token":""}');
      expect(parsed === undefined).assertTrue();
    });

    it('bad JSON returns undefined', 0, (): void => {
      const parsed = parsePairResponse('not-json');
      expect(parsed === undefined).assertTrue();
    });
  });

  describe('PairingApi.parseRetryAfterSeconds', (): void => {
    it('parses positive integer seconds', 0, (): void => {
      expect(parseRetryAfterSeconds('3600')).assertEqual(3600);
      expect(parseRetryAfterSeconds(' 30 ')).assertEqual(30);
    });

    it('rejects non-positive or non-numeric', 0, (): void => {
      expect(parseRetryAfterSeconds('0')).assertEqual(undefined);
      expect(parseRetryAfterSeconds('-5')).assertEqual(undefined);
      expect(parseRetryAfterSeconds('abc')).assertEqual(undefined);
      expect(parseRetryAfterSeconds(undefined)).assertEqual(undefined);
    });
  });
}
