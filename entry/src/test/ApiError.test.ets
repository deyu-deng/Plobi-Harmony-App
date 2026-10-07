import { describe, it, expect } from '@ohos/hypium';
import {
  classifyConnectFailure,
  classifyHttpFailure,
  classifyPairFailure,
  classifyVersion,
  formatWaitSeconds,
  serverMajorVersion,
} from '../main/ets/service/ApiError';

export default function apiErrorTest(): void {
  describe('ApiError.classifyConnectFailure', (): void => {
    it('flags connection refused as desktop-offline', 0, (): void => {
      const f = classifyConnectFailure('Connection refused: 127.0.0.1:8787');
      expect(f.kind).assertEqual('desktop-offline');
      expect(f.short).assertContain('没开');
    });

    it('flags ETIMEDOUT as lan-unreachable', 0, (): void => {
      const f = classifyConnectFailure('connect ETIMEDOUT 10.195.150.138:8787');
      expect(f.kind).assertEqual('lan-unreachable');
      expect(f.short).assertContain('连不上');
    });

    it('flags timed out (lower-case) as lan-unreachable', 0, (): void => {
      const f = classifyConnectFailure('request timed out');
      expect(f.kind).assertEqual('lan-unreachable');
    });

    it('flags network unreachable as lan-unreachable', 0, (): void => {
      const f = classifyConnectFailure('Network unreachable');
      expect(f.kind).assertEqual('lan-unreachable');
    });

    it('flags ENOTFOUND as lan-unreachable', 0, (): void => {
      const f = classifyConnectFailure('getaddrinfo ENOTFOUND foo.bar');
      expect(f.kind).assertEqual('lan-unreachable');
    });

    it('unknown message falls to unknown', 0, (): void => {
      const f = classifyConnectFailure('something weird happened');
      expect(f.kind).assertEqual('unknown');
      expect(f.short).assertContain('网络');
    });

    it('undefined reason falls to unknown', 0, (): void => {
      const f = classifyConnectFailure(undefined);
      expect(f.kind).assertEqual('unknown');
    });
  });

  describe('ApiError.classifyHttpFailure', (): void => {
    it('401 maps to token-rejected', 0, (): void => {
      const f = classifyHttpFailure(401, 'unauthorized');
      expect(f.kind).assertEqual('token-rejected');
      expect(f.short).assertContain('令牌');
      expect(f.hint).assertContain('重新配对');
    });

    it('403 maps to token-rejected', 0, (): void => {
      const f = classifyHttpFailure(403, 'forbidden');
      expect(f.kind).assertEqual('token-rejected');
    });

    it('404 maps to http-error (path hint)', 0, (): void => {
      const f = classifyHttpFailure(404, 'not found');
      expect(f.kind).assertEqual('http-error');
      expect(f.hint).assertContain('地址');
    });

    it('500 maps to http-error with reason', 0, (): void => {
      const f = classifyHttpFailure(500, 'internal');
      expect(f.kind).assertEqual('http-error');
      expect(f.hint).assertContain('internal');
    });

    it('429 maps to http-error', 0, (): void => {
      const f = classifyHttpFailure(429, 'too many requests');
      expect(f.kind).assertEqual('http-error');
    });

    it('200 (success path) maps to unknown', 0, (): void => {
      const f = classifyHttpFailure(200, '');
      expect(f.kind).assertEqual('unknown');
    });
  });

  describe('ApiError.classifyVersion', (): void => {
    it('matching major returns undefined', 0, (): void => {
      expect(classifyVersion(1, 1)).assertEqual(undefined);
    });

    it('server newer returns upgrade-app notice', 0, (): void => {
      const f = classifyVersion(2, 1);
      expect(f === undefined).assertFalse();
      if (f !== undefined) {
        expect(f.short).assertContain('升级');
        expect(f.hint).assertContain('缓存');
      }
    });

    it('server older returns upgrade-desktop notice', 0, (): void => {
      const f = classifyVersion(0, 1);
      expect(f === undefined).assertFalse();
      if (f !== undefined) {
        expect(f.short).assertContain('桌面');
        expect(f.hint).assertContain('缓存');
      }
    });

    it('undefined actual returns undefined (silent)', 0, (): void => {
      expect(classifyVersion(undefined, 1)).assertEqual(undefined);
    });
  });

  describe('ApiError.serverMajorVersion', (): void => {
    it('parses "1"', 0, (): void => {
      expect(serverMajorVersion('1')).assertEqual(1);
    });

    it('parses "1.2.3"', 0, (): void => {
      expect(serverMajorVersion('1.2.3')).assertEqual(1);
    });

    it('parses "2"', 0, (): void => {
      expect(serverMajorVersion('2')).assertEqual(2);
    });

    it('parses "v2" (non-strict)', 0, (): void => {
      // indexOf('.') returns -1; substring(0, -1) is undefined-ish; Number(undefined) = NaN
      expect(serverMajorVersion('v2')).assertEqual(undefined);
    });

    it('undefined returns undefined', 0, (): void => {
      expect(serverMajorVersion(undefined)).assertEqual(undefined);
    });

    it('empty returns undefined', 0, (): void => {
      expect(serverMajorVersion('')).assertEqual(undefined);
    });
  });

  describe('ApiError.classifyPairFailure', (): void => {
    it('401 maps to pair-code-rejected', 0, (): void => {
      const f = classifyPairFailure(401, undefined);
      expect(f.kind).assertEqual('pair-code-rejected');
      expect(f.short).assertContain('重新开一个码');
      expect(f.hint).assertContain('新码');
    });

    it('429 with retryAfterSeconds maps to pair-locked with wait text', 0, (): void => {
      const f = classifyPairFailure(429, 1800);
      expect(f.kind).assertEqual('pair-locked');
      expect(f.short).assertContain('30 分钟');
      expect(f.retryAfterSeconds).assertEqual(1800);
    });

    it('429 without retryAfterSeconds falls back to about one hour', 0, (): void => {
      const f = classifyPairFailure(429, undefined);
      expect(f.kind).assertEqual('pair-locked');
      expect(f.short).assertContain('约 1 小时');
      expect(f.retryAfterSeconds).assertEqual(undefined);
    });

    it('other statuses delegate to classifyHttpFailure', 0, (): void => {
      const f = classifyPairFailure(404, undefined);
      expect(f.kind).assertEqual('http-error');
    });
  });

  describe('ApiError.formatWaitSeconds', (): void => {
    it('under a minute shows seconds', 0, (): void => {
      expect(formatWaitSeconds(30)).assertEqual('30 秒');
    });

    it('minutes round up', 0, (): void => {
      expect(formatWaitSeconds(90)).assertEqual('约 2 分钟');
    });

    it('hours round to nearest', 0, (): void => {
      expect(formatWaitSeconds(7200)).assertEqual('约 2 小时');
    });

    it('missing falls back to about one hour', 0, (): void => {
      expect(formatWaitSeconds(undefined)).assertEqual('约 1 小时');
    });
  });
}