/**
 * 把 HTTP 基址映成 WebSocket 端点 URL（**不含** token）。
 *
 * 任务书 §复用：「**禁止**把 token 放进 URL」。
 * 鉴权走请求头 `X-Plobi-Session-Token`（与 HTTP 同步）。
 *
 * 例：baseUrl=http://192.168.1.8:8787 → ws://192.168.1.8:8787/api/ws
 */
const TRAILING_SLASHES: RegExp = new RegExp('/+$');
const HTTPS_PREFIX: string = 'https://';
const HTTP_PREFIX: string = 'http://';

export function buildWsUrl(baseUrl: string): string {
  const trimmed: string = baseUrl.replace(TRAILING_SLASHES, '');
  let scheme: string = 'ws://';
  let rest: string = trimmed;
  if (trimmed.startsWith(HTTPS_PREFIX)) {
    scheme = 'wss://';
    rest = trimmed.substring(HTTPS_PREFIX.length);
  } else if (trimmed.startsWith(HTTP_PREFIX)) {
    rest = trimmed.substring(HTTP_PREFIX.length);
  }
  return scheme + rest + '/api/ws';
}

/**
 * 校验生成的 WS URL 不含 token 痕迹（防御性自检；UI 不会调用）。
 */
export function wsUrlHasNoToken(url: string, token: string): boolean {
  if (token.length === 0) {
    return true;
  }
  return url.indexOf(token) < 0 && url.indexOf('token=') < 0 && url.indexOf('Bearer ') < 0;
}