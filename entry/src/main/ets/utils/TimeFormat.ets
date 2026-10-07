/**
 * 时间格式工具：严格遵守「end_at 为空只显示开始并标『未写结束』」，
 * 不补 1 小时、不编 9:00（裁定 27 + 25.1 + 任务书 §冻结契约）。
 */

/**
 * 数字补零到两位（0–9 → '00'–'09'，两位数原样）。
 * 时间/日期补零的全仓单点实现（FR-012）。
 */
export function padTwo(n: number): string {
  return n < 10 ? '0' + n.toString() : n.toString();
}

/**
 * 把 ISO 字符串解析为本地 Date；解析失败返回 undefined（不抛、不猜）。
 */
export function parseLocalTime(iso: string): Date | undefined {
  if (!iso) {
    return undefined;
  }
  const d: Date = new Date(iso);
  if (isNaN(d.getTime())) {
    return undefined;
  }
  return d;
}

export function formatHHmm(iso: string): string {
  const d: Date | undefined = parseLocalTime(iso);
  if (d === undefined) {
    return '--:--';
  }
  return padTwo(d.getHours()) + ':' + padTwo(d.getMinutes());
}

/**
 * 仅时间段文本：「HH:MM–HH:MM」或「HH:MM · 未写结束」。
 * 开始时间解析失败 → '--:--'；结束时间缺失/为空/解析失败 → 不编造，按「未写结束」处理。
 */
export function formatTimeRange(startIso: string, endIso?: string): string {
  const start: Date | undefined = parseLocalTime(startIso);
  if (start === undefined) {
    return '--:--';
  }
  const startText: string = padTwo(start.getHours()) + ':' + padTwo(start.getMinutes());
  const endRaw: string | undefined = endIso;
  if (endRaw === undefined || endRaw.length === 0) {
    return startText + ' · 未写结束';
  }
  const end: Date | undefined = parseLocalTime(endRaw);
  if (end === undefined) {
    return startText + ' · 未写结束';
  }
  return startText + '–' + padTwo(end.getHours()) + ':' + padTwo(end.getMinutes());
}

/**
 * 当前本地时刻的「HH:MM」（时间线「现在」行）。
 */
export function formatLocalNowHHmm(): string {
  const now: Date = new Date();
  return padTwo(now.getHours()) + ':' + padTwo(now.getMinutes());
}

/**
 * 一行「HH:MM 标题」或「HH:MM–HH:MM 标题」或「HH:MM · 未写结束 标题」。
 */
export function formatEventLine(title: string, startIso: string, endIso?: string): string {
  return formatTimeRange(startIso, endIso) + '  ' + title;
}
