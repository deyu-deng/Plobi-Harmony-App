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

export const PREF_KEY_BASE_URL: string = 'plobi.baseUrl';
export const PREF_KEY_TOKEN: string = 'plobi.token';
export const PREF_KEY_LAST_SYNC: string = 'plobi.lastSyncAt';
export const PREF_KEY_CACHED_EVENTS: string = 'plobi.cachedEvents';
export const PREF_KEY_CACHED_PENDING: string = 'plobi.cachedPending';
export const PREF_KEY_CACHED_DAY: string = 'plobi.cachedDay';
export const PREF_KEY_L1_INFO: string = 'plobi.l1Info';
export const PREF_KEY_CHAT_HISTORY: string = 'plobi.chatHistory';
