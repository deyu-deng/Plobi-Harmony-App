import { http } from '@kit.NetworkKit';
import { DEFAULT_DEVICE_NAME } from '../model/AppConfig';
import { ApiFailure, classifyPairFailure } from './ApiError';
import { ApiResult, doRequest, readHeader } from './HttpKit';

/**
 * 配对客户端：6 位配对码兑换设备令牌（POST /api/handset/pair/redeem，设备面唯一免凭证调用）。
 * 解析/校验全部是纯函数，可在不依赖网络的前提下单测。
 * 纪律：设备令牌与配对码不写日志、不进 URL，只在配对响应里出现一次。
 */

export interface PairResult {
  ok: boolean;
  deviceId?: string;
  token?: string;
  failure?: ApiFailure;
}

interface PairRedeemRequest {
  code: string;
  deviceName: string;
}

export interface PairRedeemParsed {
  deviceId: string;
  token: string;
}

const SIX_DIGIT_RE: RegExp = new RegExp('^[0-9]{6}$');
const RETRY_AFTER_RE: RegExp = new RegExp('^[0-9]+$');

/**
 * 配对码必须是精确的 6 位数字；不匹配则前端直接拦截，不发请求。
 */
export function isSixDigitCode(raw: string): boolean {
  return SIX_DIGIT_RE.test(raw);
}

/**
 * 设备名上报值：trim 后为空 → 默认「Plobi 平板」；其余 trim 后原样上报。
 */
export function resolveDeviceName(raw: string): string {
  const trimmed: string = raw.trim();
  if (trimmed.length === 0) {
    return DEFAULT_DEVICE_NAME;
  }
  return trimmed;
}

/**
 * 设备名合法性：trim 后长度 ≤ 64 字（超长不允许提交）。
 */
export function isValidDeviceName(raw: string): boolean {
  return raw.trim().length <= 64;
}

/**
 * 解析配对响应：deviceId 与 token 必须都是非空字符串，缺一即视为失败（不落半截状态）。
 * scopes 字段允许存在但不持久化（App 侧暂无用途，减少敏感数据落盘）。
 */
export function parsePairResponse(raw: string): PairRedeemParsed | undefined {
  if (raw.length === 0) {
    return undefined;
  }
  let obj: Object;
  try {
    obj = JSON.parse(raw) as Object;
  } catch (e) {
    return undefined;
  }
  if (obj === null || typeof obj !== 'object') {
    return undefined;
  }
  const rec: Record<string, Object> = obj as Record<string, Object>;
  const token: Object | undefined = rec['token'];
  const deviceId: Object | undefined = rec['deviceId'];
  if (token === undefined || deviceId === undefined) {
    return undefined;
  }
  if (typeof token !== 'string' || typeof deviceId !== 'string') {
    return undefined;
  }
  if (token.length === 0 || deviceId.length === 0) {
    return undefined;
  }
  const parsed: PairRedeemParsed = { 'deviceId': deviceId, 'token': token };
  return parsed;
}

/**
 * 解析 Retry-After 响应头：非正整数（缺失/非数字/≤0）→ undefined。
 */
export function parseRetryAfterSeconds(raw: string | undefined): number | undefined {
  if (raw === undefined) {
    return undefined;
  }
  const trimmed: string = raw.trim();
  if (!RETRY_AFTER_RE.test(trimmed)) {
    return undefined;
  }
  const n: number = Number(trimmed);
  if (isNaN(n) || n <= 0) {
    return undefined;
  }
  return n;
}

/**
 * 用 6 位配对码兑换设备令牌（免凭证，不带令牌头）。
 * 401 = 码错/过期/已用；429 = 连错锁定（读小写 retry-after 头，锁定期间不自动重试）；
 * 200 但 token/deviceId 缺失 = 配对响应不完整，按失败处理。
 * 成功时 ok=true 且 deviceId/token 必有；失败时 failure 必有。
 */
export function redeemPairCode(baseUrl: string, code: string, deviceName: string): Promise<PairResult> {
  const body: PairRedeemRequest = {
    'code': code,
    'deviceName': deviceName,
  };
  return doRequest<Object>(
    baseUrl,
    '',
    http.RequestMethod.POST,
    '/api/handset/pair/redeem',
    undefined,
    body,
  ).then((res: ApiResult<Object>): PairResult => {
    if (!res.ok) {
      if (res.status === 401 || res.status === 429) {
        const retryAfterRaw: string | undefined = res.headers !== undefined
          ? readHeader(res.headers, 'retry-after')
          : undefined;
        const retryAfter: number | undefined = parseRetryAfterSeconds(retryAfterRaw);
        const failure: ApiFailure = classifyPairFailure(res.status, retryAfter);
        const rejected: PairResult = { 'ok': false, 'failure': failure };
        return rejected;
      }
      const generic: ApiFailure = {
        'kind': 'unknown',
        'short': '配对失败',
        'hint': '检查桌面地址与网络',
      };
      const failure: ApiFailure = res.failure !== undefined ? res.failure : generic;
      const failed: PairResult = { 'ok': false, 'failure': failure };
      return failed;
    }
    const raw: string = res.data !== undefined ? JSON.stringify(res.data) : '';
    const parsed: PairRedeemParsed | undefined = parsePairResponse(raw);
    if (parsed === undefined) {
      const incomplete: ApiFailure = {
        'kind': 'unknown',
        'short': '配对响应不完整',
        'hint': '桌面返回的数据缺了设备令牌或设备号；请检查桌面版本后重新配对',
      };
      const failed: PairResult = { 'ok': false, 'failure': incomplete };
      return failed;
    }
    const ok: PairResult = { 'ok': true, 'deviceId': parsed.deviceId, 'token': parsed.token };
    return ok;
  });
}

/**
 * 桌面探活（GET /api/status，免钥匙）：设置页「测试连接」用，可在配对前单独验证地址。
 */
export function fetchServerStatus(baseUrl: string): Promise<ApiResult<Object>> {
  return doRequest<Object>(baseUrl, '', http.RequestMethod.GET, '/api/status', undefined);
}
