/**
 * API 错误分类器（纯函数，便于单测）。
 *
 * 把 HTTP / 网络层的结果映成 3 种用户可感知的失败原因（裁定 32.6）：
 *   - 'desktop-offline'  = TCP 连不上（电脑没开 / 端口未开 / 服务进程挂了）
 *   - 'lan-unreachable'  = TCP 超时（同网不同段 / 桌面端 VAELIS_LAN 没开 / WiFi 错）
 *   - 'token-rejected'   = HTTP 401 / 403（令牌错 / 过期 / 文件被覆盖）
 *
 * 加上一种版本不匹配（不是失败，但用户需要看升级提示）：
 *   - 'version-mismatch' = 响应 X-Vaelis-Api-Version 主版本 ≠ 1
 */

export type ApiFailureKind = 'desktop-offline' | 'lan-unreachable' | 'token-rejected' | 'http-error' | 'unknown';

export interface ApiFailure {
  kind: ApiFailureKind;
  short: string;
  hint: string;
}

const TIMEOUT_HINT: string = '检查 WiFi 是否同一局域网，或桌面侧 VAELIS_LAN 没开';
const OFFLINE_HINT: string = '打开桌面上的 Vaelis（启动后端会在 0.0.0.0:8787）';
const TOKEN_HINT: string = '令牌错：在桌面运行 python scripts/vaelis/doctor.py --print-app-token 重新填';
const HTTP_HINT: string = '桌面侧返回错误，检查桌面日志';

const REFETUSED_KEYS: ReadonlyArray<string> = [
  'refused', 'connection refused', 'unable to connect', 'connect failed',
];

const TIMEOUT_KEYS: ReadonlyArray<string> = [
  'timeout', 'timed out', 'etimedout',
];

const UNREACHABLE_KEYS: ReadonlyArray<string> = [
  'unreachable', 'network unreachable', 'no route', 'enotfound', 'ehostunreach',
];

/**
 * 客户端 connect 失败（status=0, no response）：根据 err.message 分类。
 */
export function classifyConnectFailure(reason: string | undefined): ApiFailure {
  const msg: string = (reason ?? '').toLowerCase();
  if (hasAny(msg, TIMEOUT_KEYS)) {
    return {
      'kind': 'lan-unreachable',
      'short': '连不上桌面',
      'hint': TIMEOUT_HINT,
    };
  }
  if (hasAny(msg, REFETUSED_KEYS)) {
    return {
      'kind': 'desktop-offline',
      'short': '电脑上的 Vaelis 没开',
      'hint': OFFLINE_HINT,
    };
  }
  if (hasAny(msg, UNREACHABLE_KEYS)) {
    return {
      'kind': 'lan-unreachable',
      'short': '连不上桌面（不可达）',
      'hint': TIMEOUT_HINT,
    };
  }
  return {
    'kind': 'unknown',
    'short': '网络错误',
    'hint': '检查 WiFi 与桌面地址',
  };
}

/**
 * HTTP 状态码 → 失败原因。
 */
export function classifyHttpFailure(status: number, reason: string | undefined): ApiFailure {
  if (status === 401 || status === 403) {
    return {
      'kind': 'token-rejected',
      'short': '令牌错（HTTP ' + String(status) + '）',
      'hint': TOKEN_HINT,
    };
  }
  if (status === 404) {
    return {
      'kind': 'http-error',
      'short': '桌面接口路径错（HTTP 404）',
      'hint': '检查桌面地址（应是 http://<LAN-IP>:8787）',
    };
  }
  if (status >= 500) {
    return {
      'kind': 'http-error',
      'short': '桌面内部错误（HTTP ' + String(status) + '）',
      'hint': HTTP_HINT + (reason !== undefined && reason.length > 0 ? '：' + reason : ''),
    };
  }
  if (status >= 400) {
    return {
      'kind': 'http-error',
      'short': '请求被拒（HTTP ' + String(status) + '）',
      'hint': HTTP_HINT,
    };
  }
  return {
    'kind': 'unknown',
    'short': '网络错误（HTTP ' + String(status) + '）',
    'hint': '检查桌面地址',
  };
}

/**
 * 给响应主版本号；返回 undefined 表示响应未声明 / 头部缺失。
 * H1 期望主版本 = 1。
 */
export function serverMajorVersion(headerValue: string | undefined): number | undefined {
  if (headerValue === undefined || headerValue.length === 0) {
    return undefined;
  }
  const dot: number = headerValue.indexOf('.');
  const head: string = dot >= 0 ? headerValue.substring(0, dot) : headerValue;
  const n: number = Number(head);
  if (isNaN(n)) {
    return undefined;
  }
  return n;
}

/**
 * 与 App 期望的主版本比对。期望 = 1。
 */
export function classifyVersion(actual: number | undefined, expected: number): ApiFailure | undefined {
  if (actual === undefined) {
    return undefined;
  }
  if (actual === expected) {
    return undefined;
  }
  if (actual > expected) {
    return {
      'kind': 'unknown',
      'short': '桌面版本更新，请升级 App',
      'hint': '桌面主版本 ' + String(actual) + '，App 期望 ' + String(expected) + '。仍可看缓存，行为未验。',
    };
  }
  return {
    'kind': 'unknown',
    'short': '桌面版本太旧，请升级桌面',
    'hint': '桌面主版本 ' + String(actual) + '，App 期望 ' + String(expected) + '。仍可看缓存。',
  };
}

function hasAny(haystack: string, needles: ReadonlyArray<string>): boolean {
  for (let i: number = 0; i < needles.length; i++) {
    if (haystack.indexOf(needles[i]) >= 0) {
      return true;
    }
  }
  return false;
}