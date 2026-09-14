import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AgendaEvent } from '../model/AgendaEvent';
import { DEFAULT_API_VERSION } from '../model/AppConfig';

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
  reason?: string;
}

interface RequestHeader {
  'Accept': string;
  'X-Vaelis-Session-Token': string;
  'X-Vaelis-Api-Version': string;
}

const HEADER_TOKEN: string = 'X-Vaelis-Session-Token';
const HEADER_API_VERSION: string = 'X-Vaelis-Api-Version';
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
      'X-Vaelis-Session-Token': token,
      'X-Vaelis-Api-Version': String(DEFAULT_API_VERSION),
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
          resolve({ ok: false, status: 0, reason: err.message });
          return;
        }
        const code: number = resp.responseCode;
        const raw: string = typeof resp.result === 'string' ? resp.result : '';
        if (code < 200 || code >= 300) {
          resolve({ ok: false, status: code, reason: raw });
          return;
        }
        let parsed: T | undefined = undefined;
        if (raw.length > 0) {
          try {
            parsed = JSON.parse(raw) as T;
          } catch (e) {
            resolve({ ok: false, status: code, reason: 'invalid JSON' });
            return;
          }
        }
        const rawVersion: string | undefined = readHeader(resp.header, HEADER_API_VERSION.toLowerCase());
        const apiVersion: number | undefined = readApiVersion(rawVersion);
        resolve({ ok: true, status: code, data: parsed, apiVersion: apiVersion });
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
