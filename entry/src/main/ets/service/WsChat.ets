import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { buildWsUrl } from './WsUrl';
import { ApiFailure, classifyConnectFailure, classifyHttpFailure } from './ApiError';
import { HEADER_TOKEN } from './HttpKit';
import { ChatEvent, ChatEventKind, ChatSubmitParams } from '../model/ChatMessage';

const WS_CLOSE_TOKEN_REJECTED: number = 4401;
const REQUEST_TIMEOUT_MS: number = 30000;

export interface ChatSendOutcome {
  ok: boolean;
  fullText: string;
  failure?: ApiFailure;
  reason?: string;
}

/**
 * 连接阶段（open 前）明确属于网络问题的消息特征。
 * 注意不含 'connect failed'：@ohos.net.webSocket 把升级被拒（如令牌错的 HTTP 403）
 * 也报成「Websocket connect failed.」，无法与网络失败区分（plan.md D8）。
 */
const WS_CONNECT_NETWORK_KEYS: ReadonlyArray<string> = [
  'timeout', 'timed out', 'etimedout',
  'refused', 'connection refused', 'unable to connect',
  'unreachable', 'network unreachable', 'no route', 'enotfound', 'ehostunreach',
];

function isWsNetworkError(message: string): boolean {
  const low: string = message.toLowerCase();
  for (let i: number = 0; i < WS_CONNECT_NETWORK_KEYS.length; i++) {
    if (low.indexOf(WS_CONNECT_NETWORK_KEYS[i]) >= 0) {
      return true;
    }
  }
  return false;
}

function classifyWsClose(code: number): ApiFailure | undefined {
  if (code === WS_CLOSE_TOKEN_REJECTED) {
    return {
      'kind': 'token-rejected',
      'short': '令牌错（WS 4401）',
      'hint': '令牌失效：到「设置」里重新配对',
    };
  }
  return {
    'kind': 'http-error',
    'short': 'WS 连接关闭（' + String(code) + '）',
    'hint': '电脑端还没打开平板对话通道，或服务暂时不可用；或令牌失效，到设置重新配对',
  };
}

/**
 * 连接阶段失败归类（plan.md D8）：明确网络类消息保留 ApiError 网络归因；
 * 其余（含「Websocket connect failed」签名，无法与令牌被拒的升级失败区分）
 * 归 token-rejected，hint 覆盖令牌失效 / 通道未开 / 桌面没开机三种可能。
 */
function classifyWsConnectError(err: BusinessError): ApiFailure {
  if (isWsNetworkError(err.message)) {
    return classifyConnectFailure(err.message);
  }
  return {
    'kind': 'token-rejected',
    'short': '对话通道握手失败',
    'hint': '令牌可能已失效，到「设置」里重新配对；或电脑端还没打开平板对话通道；或桌面没开机',
  };
}

function classifyWsHttpError(code: number): ApiFailure {
  return classifyHttpFailure(code, undefined);
}

function parseEvent(raw: string): ChatEvent {
  const fallback: ChatEvent = {
    'kind': 'unknown',
    'text': '',
    'rawType': '',
  };
  let obj: Object;
  try {
    obj = JSON.parse(raw) as Object;
  } catch (e) {
    return fallback;
  }
  if (typeof obj !== 'object' || obj === null) {
    return fallback;
  }
  const rec: Record<string, Object> = obj as Record<string, Object>;
  const paramsVal: Object | undefined = rec['params'];
  if (typeof paramsVal !== 'object' || paramsVal === null) {
    return fallback;
  }
  const params: Record<string, Object> = paramsVal as Record<string, Object>;
  const typeVal: Object | undefined = params['type'];
  const typeStr: string = typeof typeVal === 'string' ? (typeVal as string) : '';
  const kind: ChatEventKind = mapEventType(typeStr);
  let text: string = '';
  if (kind === 'message-delta') {
    const delta: Object | undefined = params['delta'];
    if (typeof delta === 'string') {
      text = delta;
    } else {
      const payload: Object | undefined = params['payload'];
      if (typeof payload === 'object' && payload !== null) {
        const p: Record<string, Object> = payload as Record<string, Object>;
        const d: Object | undefined = p['delta'];
        if (typeof d === 'string') {
          text = d;
        }
      }
    }
  }
  let errorCode: string | undefined = undefined;
  let errorMessage: string | undefined = undefined;
  if (kind === 'error') {
    const errVal: Object | undefined = params['error'];
    if (typeof errVal === 'object' && errVal !== null) {
      const e: Record<string, Object> = errVal as Record<string, Object>;
      const c: Object | undefined = e['code'];
      const m: Object | undefined = e['message'];
      errorCode = typeof c === 'string' || typeof c === 'number' ? String(c) : undefined;
      errorMessage = typeof m === 'string' ? m : undefined;
    } else if (typeof errVal === 'string') {
      errorMessage = errVal;
    }
  }
  return {
    'kind': kind,
    'text': text,
    'rawType': typeStr,
    'errorCode': errorCode,
    'errorMessage': errorMessage,
  };
}

function mapEventType(typeStr: string): ChatEventKind {
  const low: string = typeStr.toLowerCase();
  if (low === 'gateway.ready' || low === 'gateway-ready') {
    return 'gateway-ready';
  }
  if (low === 'message.delta' || low === 'message-delta' || low === 'message_delta') {
    return 'message-delta';
  }
  if (low === 'message.complete' || low === 'message-complete' || low === 'message_complete' ||
      low === 'message.done' || low === 'message-done') {
    return 'message-complete';
  }
  if (low === 'error' || low.indexOf('error') >= 0 || low.indexOf('fail') >= 0) {
    return 'error';
  }
  if (low.indexOf('tool') >= 0) {
    return 'tool';
  }
  return 'unknown';
}

interface SubmitFrame {
  'jsonrpc': string;
  'id': number;
  'method': string;
  'params': ChatSubmitParams;
}

function buildSubmitFrame(params: ChatSubmitParams, rid: number): string {
  const frame: SubmitFrame = {
    'jsonrpc': '2.0',
    'id': rid,
    'method': 'prompt.submit',
    'params': params,
  };
  return JSON.stringify(frame);
}

/**
 * 一次性发一话 + 等 `message.complete` 或错误。
 * 连接阶段失败按 plan.md D8 归类：明确网络类消息走 ApiError 网络归因，其余归
 * token-rejected（webSocket 库把升级被拒也报成「Websocket connect failed」，无法区分）。
 * token 仅在 `connect` 的 header，不进 URL（任务书 §复用）。
 */
export function sendPromptOverWs(
  baseUrl: string,
  token: string,
  params: ChatSubmitParams,
): Promise<ChatSendOutcome> {
  return new Promise<ChatSendOutcome>((resolve: (v: ChatSendOutcome) => void): void => {
    const ws: webSocket.WebSocket = webSocket.createWebSocket();
    const wsUrl: string = buildWsUrl(baseUrl);
    const header: Record<string, string> = {};
    header[HEADER_TOKEN] = token;
    let accumulated: string = '';
    let done: boolean = false;
    let timeoutHandle: number = -1;
    let connected: boolean = false;

    const cleanup: () => void = (): void => {
      try {
        ws.off('open');
        ws.off('message');
        ws.off('close');
        ws.off('error');
      } catch (e) {
      }
      if (timeoutHandle >= 0) {
        clearTimeout(timeoutHandle);
      }
      try {
        ws.close();
      } catch (e) {
      }
    };

    const finalize: (outcome: ChatSendOutcome) => void = (outcome: ChatSendOutcome): void => {
      if (done) {
        return;
      }
      done = true;
      cleanup();
      resolve(outcome);
    };

    ws.on('open', (_openErr: BusinessError, _value: Object): void => {
      connected = true;
      const rid: number = Math.floor(Math.random() * 1000000) + 1;
      const frame: string = buildSubmitFrame(params, rid);
      try {
        ws.send(frame, (sendErr: BusinessError, ok: boolean): void => {
          if (sendErr || !ok) {
            const reason: string = sendErr ? sendErr.message : 'send returned false';
            finalize({
              ok: false,
              fullText: accumulated,
              failure: classifyConnectFailure(reason),
              reason: reason,
            });
          }
        });
      } catch (e) {
        const err: BusinessError = e as BusinessError;
        finalize({
          ok: false,
          fullText: accumulated,
          failure: classifyConnectFailure(err.message),
          reason: err.message,
        });
      }
    });

    ws.on('message', (_err: BusinessError, value: string | ArrayBuffer): void => {
      if (typeof value !== 'string') {
        return;
      }
      const event: ChatEvent = parseEvent(value);
      if (event.kind === 'message-delta') {
        accumulated = accumulated + event.text;
      } else if (event.kind === 'message-complete') {
        finalize({
          ok: true,
          fullText: accumulated,
        });
      } else if (event.kind === 'error') {
        finalize({
          ok: false,
          fullText: accumulated,
          failure: {
            'kind': 'http-error',
            'short': '服务器报 ' + (event.errorCode ?? '?') + '：' + (event.errorMessage ?? '未知'),
            'hint': '检查桌面日志；可能需要重发',
          },
          reason: event.errorMessage,
        });
      }
    });

    ws.on('close', (_err: BusinessError, value: Object): void => {
      if (done) {
        return;
      }
      let code: number = -1;
      if (typeof value === 'object' && value !== null) {
        const rec: Record<string, Object> = value as Record<string, Object>;
        const c: Object | undefined = rec['code'];
        if (typeof c === 'number') {
          code = c as number;
        }
      }
      if (code === 1000 || code === 1005) {
        finalize({
          ok: accumulated.length > 0,
          fullText: accumulated,
        });
        return;
      }
      const failure: ApiFailure = code >= 0 ? (classifyWsClose(code) ?? classifyWsHttpError(code)) : classifyConnectFailure('ws closed');
      finalize({
        ok: false,
        fullText: accumulated,
        failure: failure,
        reason: 'ws closed code=' + String(code),
      });
    });

    ws.on('error', (err: BusinessError): void => {
      if (!connected) {
        finalize({
          ok: false,
          fullText: '',
          failure: classifyWsConnectError(err),
          reason: err.message,
        });
      } else {
        finalize({
          ok: false,
          fullText: accumulated,
          failure: classifyConnectFailure(err.message),
          reason: err.message,
        });
      }
    });

    timeoutHandle = setTimeout((): void => {
      finalize({
        ok: false,
        fullText: accumulated,
        failure: {
          'kind': 'lan-unreachable',
          'short': '总秘书没回（30s 超时）',
          'hint': '检查 WiFi / 桌面是否在线',
        },
        reason: 'timeout',
      });
    }, REQUEST_TIMEOUT_MS);

    try {
      ws.connect(wsUrl, { 'header': header }, (err: BusinessError, _value: boolean): void => {
        if (err) {
          finalize({
            ok: false,
            fullText: '',
            failure: classifyWsConnectError(err),
            reason: err.message,
          });
        }
      });
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      finalize({
        ok: false,
        fullText: '',
        failure: classifyWsConnectError(err),
        reason: err.message,
      });
    }
  });
}