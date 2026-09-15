/**
 * 把 Date 映成本地日历日的 YYYY-MM-DD。
 *
 * **重要**：永远不要 `toISOString().slice(0, 10)`——那是 UTC 日期，
 * 跨日界会差一天（中国时区 16:00 之后就是 UTC 次日）。
 * 任务书 WP-H2-DAY + 裁定 33.5 同口径。
 */
export function localDateIso(now: Date): string {
  const pad: (n: number) => string = (n: number): string => {
    return n < 10 ? '0' + n.toString() : n.toString();
  };
  const y: number = now.getFullYear();
  const m: number = now.getMonth() + 1;
  const d: number = now.getDate();
  return pad(y) + '-' + pad(m) + '-' + pad(d);
}

/**
 * 「今日」= 设备本地日历日。任务书 §「真窗口」明确要求设备本地。
 */
export function todayLocalIso(): string {
  return localDateIso(new Date());
}

/**
 * 给一条事件的 start_at 取其本地日历日（YYYY-MM-DD）。
 * 解析失败返回 undefined（不抛、不猜）。
 */
export function localDateOfIso(iso: string | undefined): string | undefined {
  if (iso === undefined || iso.length === 0) {
    return undefined;
  }
  const d: Date = new Date(iso);
  if (isNaN(d.getTime())) {
    return undefined;
  }
  return localDateIso(d);
}