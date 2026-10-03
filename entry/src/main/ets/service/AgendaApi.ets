import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AgendaEvent, DayPayload } from '../model/AgendaEvent';
import { DEFAULT_API_VERSION } from '../model/AppConfig';
import { ApiFailure, classifyConnectFailure, classifyHttpFailure, classifyVersion, serverMajorVersion } from './ApiError';

export interface DismissResult {
  deleted: boolean;
  id: string;
}

export type DecideResponse = AgendaEvent | DismissResult;

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
}

interface RequestHeader {
  'Accept': string;
  'X-Plobi-Session-Token': string;
  'X-Plobi-Api-Version': string;
}

const HEADER_TOKEN: string = 'X-Plobi-Session-Token';
const HEADER_API_VERSION: string = 'X-Plobi-Api-Version';
const DIGIT_RE: RegExp = new RegExp('([0-9]+)');
const TRAILING_SLASH_RE: RegExp = new RegExp('/+$');

function readApiVersion(header: Object | undefined): number | undefined {
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

function trimTrailingSlash(s: string): string {
  return s.replace(TRAILING_SLASH_RE, '');
}

function buildUrl(baseUrl: string, path: string, query: Record<string, string> | undefined): string {
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

function readHeader(headerObj: Object, key: string): string | undefined {
  const rec: Record<string, Object> = headerObj as Record<string, Object>;
  const v: Object | undefined = rec[key];
  if (v === undefined) {
    return undefined;
  }
  return String(v);
}

function buildFailure(status: number, reason: string | undefined): ApiFailure {
  if (status === 0) {
    return classifyConnectFailure(reason);
  }
  return classifyHttpFailure(status, reason);
}

function doRequest<T>(
  baseUrl: string,
  token: string,
  method: http.RequestMethod,
  path: string,
  query: Record<string, string> | undefined,
): Promise<ApiResult<T>> {
  return new Promise<ApiResult<T>>((resolve: (v: ApiResult<T>) => void): void => {
    const req: http.HttpRequest = http.createHttp();
    const header: RequestHeader = {
      'Accept': 'application/json',
      'X-Plobi-Session-Token': token,
      'X-Plobi-Api-Version': String(DEFAULT_API_VERSION),
    };
    req.request(
      buildUrl(baseUrl, path, query),
      {
        method: method,
        header: header as Object as Record<string, string>,
        readTimeout: 5000,
        connectTimeout: 5000,
        expectDataType: http.HttpDataType.STRING,
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
        };
        resolve(out);
      },
    );
  });
}

export function fetchAgenda(
  baseUrl: string,
  token: string,
  fromIso: string,
  toIso: string,
): Promise<ApiResult<AgendaEvent[]>> {
  const q: Record<string, string> = {
    'from': fromIso,
    'to': toIso,
  };
  return doRequest<AgendaEvent[]>(baseUrl, token, http.RequestMethod.GET, '/api/agenda', q);
}

export function fetchPending(
  baseUrl: string,
  token: string,
): Promise<ApiResult<AgendaEvent[]>> {
  return doRequest<AgendaEvent[]>(baseUrl, token, http.RequestMethod.GET, '/api/agenda/pending', undefined);
}

export function fetchDay(
  baseUrl: string,
  token: string,
  localDate: string,
): Promise<ApiResult<DayPayload>> {
  const q: Record<string, string> = {
    'date': localDate,
  };
  return doRequest<DayPayload>(baseUrl, token, http.RequestMethod.GET, '/api/agenda/day', q);
}

export function postDecide(
  baseUrl: string,
  token: string,
  eventId: string,
  action: 'confirm' | 'dismiss',
): Promise<ApiResult<DecideResponse>> {
  return doRequest<DecideResponse>(
    baseUrl,
    token,
    http.RequestMethod.POST,
    '/api/agenda/' + encodeURIComponent(eventId) + '/' + action,
    undefined,
  );
}