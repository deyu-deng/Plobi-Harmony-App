import { describe, it, expect } from '@ohos/hypium';
import {
  buildUrl,
  readApiVersion,
  readHeader,
  trimTrailingSlash,
} from '../main/ets/service/HttpKit';

export default function httpKitTest(): void {
  describe('HttpKit.trimTrailingSlash', (): void => {
    it('strips one trailing slash', 0, (): void => {
      expect(trimTrailingSlash('http://192.168.1.10:8787/')).assertEqual('http://192.168.1.10:8787');
    });

    it('strips multiple trailing slashes', 0, (): void => {
      expect(trimTrailingSlash('http://192.168.1.10:8787///')).assertEqual('http://192.168.1.10:8787');
    });

    it('keeps url without trailing slash', 0, (): void => {
      expect(trimTrailingSlash('http://192.168.1.10:8787')).assertEqual('http://192.168.1.10:8787');
    });
  });

  describe('HttpKit.buildUrl', (): void => {
    it('strips base trailing slash and appends path', 0, (): void => {
      expect(buildUrl('http://a:8787/', '/api/handset/agenda', undefined)).assertEqual('http://a:8787/api/handset/agenda');
    });

    it('appends encoded query', 0, (): void => {
      const q: Record<string, string> = { 'date': '2026-10-07' };
      expect(buildUrl('http://a:8787', '/api/handset/agenda/day', q)).assertEqual('http://a:8787/api/handset/agenda/day?date=2026-10-07');
    });

    it('no question mark when query is empty', 0, (): void => {
      const q: Record<string, string> = {};
      expect(buildUrl('http://a:8787', '/api/status', q)).assertEqual('http://a:8787/api/status');
    });
  });

  describe('HttpKit.readApiVersion', (): void => {
    it('extracts digits', 0, (): void => {
      expect(readApiVersion('1')).assertEqual(1);
      expect(readApiVersion('1.2.3')).assertEqual(1);
      expect(readApiVersion('v2')).assertEqual(2);
    });

    it('returns undefined without digits', 0, (): void => {
      expect(readApiVersion('abc')).assertEqual(undefined);
      expect(readApiVersion(undefined)).assertEqual(undefined);
    });
  });

  describe('HttpKit.readHeader', (): void => {
    it('reads string value by key', 0, (): void => {
      const h: Record<string, Object> = { 'retry-after': '30' };
      expect(readHeader(h, 'retry-after')).assertEqual('30');
    });

    it('returns undefined for missing key', 0, (): void => {
      const h: Record<string, Object> = { 'retry-after': '30' };
      expect(readHeader(h, 'nope')).assertEqual(undefined);
    });
  });
}
