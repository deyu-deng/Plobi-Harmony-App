/**
 * 配置常量：桌面基址、设备令牌、本地缓存键与默认值。
 * 全部在 Preferences 中保存，不入日志。
 */
export const DEFAULT_API_VERSION: number = 1;
export const DEFAULT_DEVICE_NAME: string = 'Plobi 平板';

export const PREF_KEY_BASE_URL: string = 'plobi.baseUrl';
export const PREF_KEY_TOKEN: string = 'plobi.token';
export const PREF_KEY_API_VERSION: string = 'plobi.apiVersion';
export const PREF_KEY_DEVICE_ID: string = 'plobi.deviceId';
export const PREF_KEY_DEVICE_NAME: string = 'plobi.deviceName';
export const PREF_KEY_LAST_SYNC: string = 'plobi.lastSyncAt';
export const PREF_KEY_CACHED_EVENTS: string = 'plobi.cachedEvents';
export const PREF_KEY_CACHED_PENDING: string = 'plobi.cachedPending';
export const PREF_KEY_CACHED_DAY: string = 'plobi.cachedDay';
export const PREF_KEY_L1_INFO: string = 'plobi.l1Info';
export const PREF_KEY_CHAT_HISTORY: string = 'plobi.chatHistory';
