import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'plobi_app_cache';

let cached: preferences.Preferences | null = null;

/**
 * 在 EntryAbility.onWindowStageCreate 调用一次，缓存 Preferences 句柄。
 */
export function initCache(context: common.UIAbilityContext): Promise<void> {
  return preferences.getPreferences(context, STORE_NAME).then((store: preferences.Preferences): void => {
    cached = store;
  });
}

function requireStore(): preferences.Preferences {
  if (cached === null) {
    throw new Error('cache not initialised; call initCache in EntryAbility.onWindowStageCreate');
  }
  return cached;
}

/**
 * 同步读字符串。空串 / 缺键 / 异常都返回 undefined（不抛、不猜）。
 */
export function getStringSync(key: string): string | undefined {
  const store: preferences.Preferences = requireStore();
  try {
    const v: preferences.ValueType = store.getSync(key, '');
    if (typeof v === 'string' && (v as string).length > 0) {
      return v as string;
    }
    return undefined;
  } catch (e) {
    return undefined;
  }
}

/**
 * 同步读数字。
 */
export function getNumberSync(key: string): number | undefined {
  const store: preferences.Preferences = requireStore();
  try {
    const v: preferences.ValueType = store.getSync(key, 0);
    if (typeof v === 'number') {
      return v as number;
    }
    return undefined;
  } catch (e) {
    return undefined;
  }
}

/**
 * 异步写字符串：putSync + flush。
 * flush 失败仅警告，不阻塞调用方。
 */
export async function putString(key: string, value: string): Promise<void> {
  const store: preferences.Preferences = requireStore();
  try {
    store.putSync(key, value);
    await store.flush();
  } catch (e) {
    const err: BusinessError = e as BusinessError;
    console.warn('[cache] putString failed', err.code, err.message);
  }
}

export async function putNumber(key: string, value: number): Promise<void> {
  const store: preferences.Preferences = requireStore();
  try {
    store.putSync(key, value);
    await store.flush();
  } catch (e) {
    const err: BusinessError = e as BusinessError;
    console.warn('[cache] putNumber failed', err.code, err.message);
  }
}
