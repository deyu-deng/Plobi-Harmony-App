import { webSocket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { buildWsUrl } from './WsUrl';
import { ApiFailure, classifyConnectFailure, classifyHttpFailure } from './ApiError';
import { ChatEvent, ChatEventKind, ChatSubmitParams } from '../model/ChatMessage';

const HEADER_TOKEN: string = 'X-Vaelis-Session-Token';
const WS_CLOSE_TOKEN_REJECTED: number = 4401;
const REQUEST_TIMEOUT_MS: number = 30000;

export interface ChatSendOutcome {
  ok: boolean;
  fullText: string;
  failure?: ApiFailure;
  reason?: string;
}

interface RequestHeader {
  'X-Vaelis-Session-Token': string;
}

function classifyWsClose(code: number): ApiFailure | undefined {
  if (code === WS_CLOSE_TOKEN_REJECTED) {
    return {
      'kind': 'token-rejected',
      'short': '令牌错（WS 4401）',
      'hint': '令牌错：在桌面运行 python scripts/vaelis/doctor.py --print-app-token 重新填',
    };
  }
  return {
    'kind': 'http-error',
    'short': 'WS 连接关闭（' + String(code) + '）',
    'hint': '电脑端还没打开平板对话通道，或服务暂时不可用',
  };
}

function classifyWsConnectError(err: BusinessError): ApiFailure {
  return classifyConnectFailure(err.message);
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
 * 连接 / 鉴权失败 → 复用 ApiError 三分类。
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
    const header: RequestHeader = {
      'X-Vaelis-Session-Token': token,
    };
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
              failure: classifyWsConnectError(sendErr ?? { code: 0, message: reason, name: '', stack: '' }),
              reason: reason,
            });
          }
        });
      } catch (e) {
        const err: BusinessError = e as BusinessError;
        finalize({
          ok: false,
          fullText: accumulated,
          failure: classifyWsConnectError(err),
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
      const failure: ApiFailure = code >= 0 ? (classifyWsClose(code) ?? classifyWsHttpError(code)) : classifyWsConnectError({ code: code, message: 'ws closed', name: '', stack: '' });
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
          failure: classifyWsConnectError(err),
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
      ws.connect(wsUrl, { 'header': header as Object as Record<string, string> }, (err: BusinessError, _value: boolean): void => {
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