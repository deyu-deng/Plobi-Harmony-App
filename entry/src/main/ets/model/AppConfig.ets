/**
 * 配对设置：桌面基址 + 会话令牌。
 * 全部在 Keystore / Preferences 中保存，不入日志。
 */
export interface AppConfig {
  baseUrl: string;
  token: string;
  apiVersion: number;
}

export const DEFAULT_API_VERSION: number = 1;

export const PREF_KEY_BASE_URL: string = 'vaelis.baseUrl';
export const PREF_KEY_TOKEN: string = 'vaelis.token';
export const PREF_KEY_LAST_SYNC: string = 'vaelis.lastSyncAt';
export const PREF_KEY_CACHED_EVENTS: string = 'vaelis.cachedEvents';
export const PREF_KEY_CACHED_PENDING: string = 'vaelis.cachedPending';
export const PREF_KEY_CACHED_DAY: string = 'vaelis.cachedDay';
