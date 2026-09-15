import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DEFAULT_API_VERSION } from '../model/AppConfig';
import { ApiFailure, classifyConnectFailure, classifyHttpFailure, classifyVersion, serverMajorVersion } from './ApiError';

export interface AgentRowRaw {
  id: string;
  name?: string;
  role?: string;
  sessionId?: string;
}

export interface ApiResultAgents {
  ok: boolean;
  status: number;
  data?: AgentRowRaw[];
  serverMajor?: number;
  expectedMajor: number;
  failure?: ApiFailure;
  versionNotice?: ApiFailure;
  reason?: string;
}

interface RequestHeader {
  'Accept': string;
  'X-Vaelis-Session-Token': string;
  'X-Vaelis-Api-Version': string;
}

const HEADER_TOKEN: string = 'X-Vaelis-Session-Token';
const HEADER_API_VERSION: string = 'X-Vaelis-Api-Version';
const TRAILING_SLASH_RE: RegExp = new RegExp('/+$');

function trimTrailingSlash(s: string): string {
  return s.replace(TRAILING_SLASH_RE, '');
}

function buildUrl(baseUrl: string, path: string): string {
  return trimTrailingSlash(baseUrl) + path;
}

function buildFailure(status: number, reason: string | undefined): ApiFailure {
  if (status === 0) {
    return classifyConnectFailure(reason);
  }
  return classifyHttpFailure(status, reason);
}

function readHeader(headerObj: Object, key: string): string | undefined {
  const rec: Record<string, Object> = headerObj as Record<string, Object>;
  const v: Object | undefined = rec[key];
  if (v === undefined) {
    return undefined;
  }
  return String(v);
}

export function fetchAgents(baseUrl: string, token: string): Promise<ApiResultAgents> {
  return new Promise<ApiResultAgents>((resolve: (v: ApiResultAgents) => void): void => {
    const req: http.HttpRequest = http.createHttp();
    const header: RequestHeader = {
      'Accept': 'application/json',
      'X-Vaelis-Session-Token': token,
      'X-Vaelis-Api-Version': String(DEFAULT_API_VERSION),
    };
    req.request(
      buildUrl(baseUrl, '/api/agents'),
      {
        method: http.RequestMethod.GET,
        header: header as Object as Record<string, string>,
        readTimeout: 5000,
        connectTimeout: 5000,
        expectDataType: http.HttpDataType.STRING,
      },
      (err: BusinessError, resp: http.HttpResponse): void => {
        req.destroy();
        if (err) {
          const failure: ApiFailure = buildFailure(0, err.message);
          const out: ApiResultAgents = {
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
        const rawVersion: string | undefined = readHeader(resp.header, HEADER_API_VERSION.toLowerCase());
        const major: number | undefined = serverMajorVersion(rawVersion);
        const versionNotice: ApiFailure | undefined = classifyVersion(major, DEFAULT_API_VERSION);
        if (code < 200 || code >= 300) {
          const failure: ApiFailure = buildFailure(code, raw);
          const out: ApiResultAgents = {
            ok: false,
            status: code,
            serverMajor: major,
            expectedMajor: DEFAULT_API_VERSION,
            failure: failure,
            versionNotice: versionNotice,
            reason: raw,
          };
          resolve(out);
          return;
        }
        let parsed: AgentRowRaw[] | undefined = undefined;
        if (raw.length > 0) {
          try {
            const obj: Object = JSON.parse(raw) as Object;
            if (Array.isArray(obj)) {
              parsed = obj as AgentRowRaw[];
            }
          } catch (e) {
            const failure: ApiFailure = buildFailure(code, 'invalid JSON');
            const out: ApiResultAgents = {
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
        const out: ApiResultAgents = {
          ok: true,
          status: code,
          data: parsed,
          serverMajor: major,
          expectedMajor: DEFAULT_API_VERSION,
          versionNotice: versionNotice,
        };
        resolve(out);
      },
    );
  });
}