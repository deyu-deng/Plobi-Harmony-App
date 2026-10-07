/**
 * API 错误分类器（纯函数，便于单测）。
 *
 * 把 HTTP / 网络层的结果映成用户可感知的失败原因（裁定 32.6）：
 *   - 'desktop-offline'  = TCP 连不上（电脑没开 / 端口未开 / 服务进程挂了）
 *   - 'lan-unreachable'  = TCP 超时（同网不同段 / 桌面端 PLOBI_LAN 没开 / WiFi 错）
 *   - 'token-rejected'   = HTTP 401 / 403（令牌错 / 过期 / 被撤销）
 *   - 'pair-code-rejected' = 配对码错 / 过期 / 已用（HTTP 401，配对接口专用）
 *   - 'pair-locked'      = 配对连错锁定（HTTP 429 + Retry-After，不自动重试）
 *
 * 加上一种版本不匹配（不是失败，但用户需要看升级提示）：
 *   - 'version-mismatch' = 响应 X-Plobi-Api-Version 主版本 ≠ 1
 */

export type ApiFailureKind = 'desktop-offline' | 'lan-unreachable' | 'token-rejected' | 'http-error' | 'unknown' | 'pair-code-rejected' | 'pair-locked';

export interface ApiFailure {
  kind: ApiFailureKind;
  short: string;
  hint: string;
  retryAfterSeconds?: number;
}

const TIMEOUT_HINT: string = '检查 WiFi 是否同一局域网，或桌面侧 PLOBI_LAN 没开';
const OFFLINE_HINT: string = '打开桌面上的 Plobi（启动后端会在 0.0.0.0:8787）';
const TOKEN_HINT: string = '令牌失效：到「设置」里重新配对';
const HTTP_HINT: string = '桌面侧返回错误，检查桌面日志';

const REFUSED_KEYS: ReadonlyArray<string> = [
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
  if (hasAny(msg, REFUSED_KEYS)) {
    return {
      'kind': 'desktop-offline',
      'short': '电脑上的 Plobi 没开',
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
 * 把 Retry-After 秒数转成用户可读的等待时长（FR-006）。
 * <60 → 「N 秒」；<3600 → 「约 N 分钟」（向上取整）；≥3600 → 「约 N 小时」（四舍五入）；
 * 缺失/非法 → 「约 1 小时」。
 */
export function formatWaitSeconds(seconds?: number): string {
  if (seconds === undefined || isNaN(seconds) || seconds <= 0) {
    return '约 1 小时';
  }
  if (seconds < 60) {
    return String(seconds) + ' 秒';
  }
  if (seconds < 3600) {
    const minutes: number = Math.ceil(seconds / 60);
    return '约 ' + String(minutes) + ' 分钟';
  }
  const hours: number = Math.round(seconds / 3600);
  return '约 ' + String(hours) + ' 小时';
}

/**
 * 配对接口（/api/handset/pair/redeem）的失败分类：
 * 401 = 码错/过期/已用；429 = 连错锁定（带 Retry-After 等待时长）；其余委托通用分类。
 * 锁定期间 App 不自动重试（仅用户再次点击才发请求）。
 */
export function classifyPairFailure(status: number, retryAfterSeconds?: number): ApiFailure {
  if (status === 401) {
    return {
      'kind': 'pair-code-rejected',
      'short': '码错或已过期，回桌面重新开一个码',
      'hint': '配对码 5 分钟有效且只能用一次；到桌面 PAIRING 页点「新码」后重新输入',
    };
  }
  if (status === 429) {
    const wait: string = formatWaitSeconds(retryAfterSeconds);
    return {
      'kind': 'pair-locked',
      'short': '配对被锁定，' + wait + '后再试',
      'hint': '连错次数太多被锁定；期间不会自动重试，' + wait + '后再到设置页重新配对',
      'retryAfterSeconds': retryAfterSeconds,
    };
  }
  return classifyHttpFailure(status, undefined);
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
