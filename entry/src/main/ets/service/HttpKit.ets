import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DEFAULT_API_VERSION } from '../model/AppConfig';
import { ApiFailure, classifyConnectFailure, classifyHttpFailure, classifyVersion, serverMajorVersion } from './ApiError';

/**
 * 共享 HTTP 底座：请求头构造、URL 拼装、响应头读取与通用 doRequest。
 * 两份 API 客户端（AgendaApi/AgentApi）与配对客户端（PairingApi）三方共用（FR-012）。
 * 令牌头常量在此单点定义，全仓不得再建本地副本。
 */
export const HEADER_TOKEN: string = 'X-Plobi-Session-Token';
export const HEADER_API_VERSION: string = 'X-Plobi-Api-Version';

export interface RequestHeader {
  'Accept': string;
  'X-Plobi-Session-Token': string;
  'X-Plobi-Api-Version': string;
}

export interface ApiResult<T> {
  ok: boolean;
  status: number;
  data?: T;
  apiVersion?: number;
  serverMajor?: number;
  expectedMajor: number;
  failure?: ApiFailure;
  versionNotice?: ApiFailure;
  reason?: string;
  headers?: Object;
}

const DIGIT_RE: RegExp = new RegExp('([0-9]+)');
const TRAILING_SLASH_RE: RegExp = new RegExp('/+$');

/**
 * 从原始响应头值（如 '1' / '1.2.3' / 'v2'）里提取首个数字段为 API 版本号。
 */
export function readApiVersion(header: Object | undefined): number | undefined {
  if (header === undefined) {
    return undefined;
  }
  const raw: string = String(header);
  const m: RegExpMatchArray | null = raw.match(DIGIT_RE);
  if (m === null || m.length < 2) {
    return undefined;
  }
  const digits: string = m[1];
  const n: number = Number(digits);
  if (isNaN(n)) {
    return undefined;
  }
  return n;
}

/**
 * 去掉基址末尾的全部斜杠（用户常多敲一个）。
 */
export function trimTrailingSlash(s: string): string {
  return s.replace(TRAILING_SLASH_RE, '');
}

/**
 * 基址 + 路径 + 可选 query（键值均经 encodeURIComponent）。
 */
export function buildUrl(baseUrl: string, path: string, query: Record<string, string> | undefined): string {
  let url: string = trimTrailingSlash(baseUrl) + path;
  if (query !== undefined) {
    const parts: string[] = [];
    const keys: string[] = Object.keys(query);
    for (let i: number = 0; i < keys.length; i++) {
      const k: string = keys[i];
      const v: string = query[k];
      parts.push(encodeURIComponent(k) + '=' + encodeURIComponent(v));
    }
    if (parts.length > 0) {
      url = url + '?' + parts.join('&');
    }
  }
  return url;
}

/**
 * 从响应头对象里按键取字符串值（http 模块的响应头键为小写）。
 */
export function readHeader(headerObj: Object, key: string): string | undefined {
  const rec: Record<string, Object> = headerObj as Record<string, Object>;
  const v: Object | undefined = rec[key];
  if (v === undefined) {
    return undefined;
  }
  return String(v);
}

/**
 * 通用失败构造：status=0 走连接失败分类，其余走 HTTP 状态码分类。
 */
export function buildFailure(status: number, reason: string | undefined): ApiFailure {
  if (status === 0) {
    return classifyConnectFailure(reason);
  }
  return classifyHttpFailure(status, reason);
}

/**
 * 构造请求头：token 为空时省略令牌头（配对 redeem 是设备面唯一免凭证调用）；
 * 带请求体时补 Content-Type: application/json。
 */
function buildHeaderRecord(token: string, hasBody: boolean): Record<string, string> {
  if (token.length > 0) {
    const full: RequestHeader = {
      'Accept': 'application/json',
      'X-Plobi-Session-Token': token,
      'X-Plobi-Api-Version': String(DEFAULT_API_VERSION),
    };
    const header: Record<string, string> = full as Object as Record<string, string>;
    if (hasBody) {
      header['Content-Type'] = 'application/json';
    }
    return header;
  }
  const guest: Record<string, string> = {
    'Accept': 'application/json',
    'X-Plobi-Api-Version': String(DEFAULT_API_VERSION),
  };
  if (hasBody) {
    guest['Content-Type'] = 'application/json';
  }
  return guest;
}

/**
 * 通用请求：GET/POST 共用；token 为空省略令牌头；body 非空按 JSON 发送；超时 5s。
 * 成功/失败结果都带可选原始响应头（headers），供调用方读取 Retry-After 等标准头。
 */
export function doRequest<T>(
  baseUrl: string,
  token: string,
  method: http.RequestMethod,
  path: string,
  query?: Record<string, string>,
  body?: Object,
): Promise<ApiResult<T>> {
  return new Promise<ApiResult<T>>((resolve: (v: ApiResult<T>) => void): void => {
    const req: http.HttpRequest = http.createHttp();
    const header: Record<string, string> = buildHeaderRecord(token, body !== undefined);
    req.request(
      buildUrl(baseUrl, path, query),
      {
        method: method,
        header: header,
        readTimeout: 5000,
        connectTimeout: 5000,
        expectDataType: http.HttpDataType.STRING,
        extraData: body !== undefined ? JSON.stringify(body) : undefined,
      },
      (err: BusinessError, resp: http.HttpResponse): void => {
        req.destroy();
        if (err) {
          const failure: ApiFailure = buildFailure(0, err.message);
          const out: ApiResult<T> = {
            ok: false,
            status: 0,
            expectedMajor: DEFAULT_API_VERSION,
            failure: failure,
            reason: err.message,
          };
          resolve(out);
          return;
        }
        const code: number = resp.responseCode;
        const raw: string = typeof resp.result === 'string' ? resp.result : '';
        const apiVersionRaw: string | undefined = readHeader(resp.header, HEADER_API_VERSION.toLowerCase());
        const apiVersion: number | undefined = readApiVersion(apiVersionRaw);
        const major: number | undefined = serverMajorVersion(apiVersionRaw);
        const versionNotice: ApiFailure | undefined = classifyVersion(major, DEFAULT_API_VERSION);
        if (code < 200 || code >= 300) {
          const failure: ApiFailure = buildFailure(code, raw);
          const out: ApiResult<T> = {
            ok: false,
            status: code,
            apiVersion: apiVersion,
            serverMajor: major,
            expectedMajor: DEFAULT_API_VERSION,
            failure: failure,
            versionNotice: versionNotice,
            reason: raw,
            headers: resp.header,
          };
          resolve(out);
          return;
        }
        let parsed: T | undefined = undefined;
        if (raw.length > 0) {
          try {
            parsed = JSON.parse(raw) as T;
          } catch (e) {
            const failure: ApiFailure = buildFailure(code, 'invalid JSON');
            const out: ApiResult<T> = {
              ok: false,
              status: code,
              expectedMajor: DEFAULT_API_VERSION,
              failure: failure,
              reason: 'invalid JSON',
              headers: resp.header,
            };
            resolve(out);
            return;
          }
        }
        const out: ApiResult<T> = {
          ok: true,
          status: code,
          data: parsed,
          apiVersion: apiVersion,
          serverMajor: major,
          expectedMajor: DEFAULT_API_VERSION,
          versionNotice: versionNotice,
          headers: resp.header,
        };
        resolve(out);
      },
    );
  });
}
