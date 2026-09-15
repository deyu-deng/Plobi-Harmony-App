import { describe, it, expect } from '@ohos/hypium';
import { buildWsUrl, wsUrlHasNoToken } from '../main/ets/service/WsUrl';

export default function wsUrlTest(): void {
  describe('WsUrl.buildWsUrl', (): void => {
    it('converts http://host:port to ws://host:port/api/ws', 0, (): void => {
      const url: string = buildWsUrl('http://192.168.1.8:8787');
      expect(url).assertEqual('ws://192.168.1.8:8787/api/ws');
    });

    it('converts https://host to wss://host/api/ws', 0, (): void => {
      const url: string = buildWsUrl('https://vaelis.example.com');
      expect(url).assertEqual('wss://vaelis.example.com/api/ws');
    });

    it('strips trailing slash before adding path', 0, (): void => {
      const url: string = buildWsUrl('http://10.0.0.1:8787/');
      expect(url).assertEqual('ws://10.0.0.1:8787/api/ws');
    });

    it('strips multiple trailing slashes', 0, (): void => {
      const url: string = buildWsUrl('http://10.0.0.1:8787///');
      expect(url).assertEqual('ws://10.0.0.1:8787/api/ws');
    });

    it('returns ws://... for unknown scheme prefix', 0, (): void => {
      const url: string = buildWsUrl('vaelis.local:8787');
      expect(url).assertEqual('ws://vaelis.local:8787/api/ws');
    });

    it('NEVER embeds token in URL (negative test)', 0, (): void => {
      const token: string = 'secret-jwt-token-abc123';
      const url: string = buildWsUrl('http://192.168.1.8:8787');
      expect(url.indexOf(token)).assertEqual(-1);
      expect(url.indexOf('?token=')).assertEqual(-1);
      expect(url.indexOf('token=')).assertEqual(-1);
      expect(url.indexOf('Bearer ')).assertEqual(-1);
    });

    it('URL length stays well under 1024', 0, (): void => {
      const url: string = buildWsUrl('http://10.0.0.1:8787');
      expect(url.length < 1024).assertTrue();
    });
  });

  describe('WsUrl.wsUrlHasNoToken', (): void => {
    it('returns true for clean url', 0, (): void => {
      const url: string = 'ws://192.168.1.8:8787/api/ws';
      expect(wsUrlHasNoToken(url, 'abc123')).assertTrue();
    });

    it('returns true for empty token', 0, (): void => {
      const url: string = 'ws://192.168.1.8:8787/api/ws?token=foo';
      expect(wsUrlHasNoToken(url, '')).assertTrue();
    });

    it('returns false when token embedded raw', 0, (): void => {
      const url: string = 'ws://192.168.1.8:8787/api/ws/secret-jwt';
      expect(wsUrlHasNoToken(url, 'secret-jwt')).assertFalse();
    });

    it('returns false when ?token= present', 0, (): void => {
      const url: string = 'ws://192.168.1.8:8787/api/ws?token=secret';
      expect(wsUrlHasNoToken(url, 'anything')).assertFalse();
    });

    it('returns false when Bearer embedded', 0, (): void => {
      const url: string = 'ws://192.168.1.8:8787/api/ws?x=Bearer y';
      expect(wsUrlHasNoToken(url, 'anything')).assertFalse();
    });
  });
}