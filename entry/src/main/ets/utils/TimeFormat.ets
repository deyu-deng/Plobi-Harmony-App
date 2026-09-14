/**
 * 时间格式工具：严格遵守「end_at 为空只显示开始并标『未写结束』」，
 * 不补 1 小时、不编 9:00（裁定 27 + 25.1 + 任务书 §冻结契约）。
 */

const PAD_TWO: (n: number) => string = (n: number): string => {
  return n < 10 ? '0' + n.toString() : n.toString();
};

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
  return PAD_TWO(d.getHours()) + ':' + PAD_TWO(d.getMinutes());
}

/**
 * 一行「HH:MM 标题」或「HH:MM–HH:MM 标题」或「HH:MM · 未写结束 标题」。
 */
export function formatEventLine(title: string, startIso: string, endIso?: string): string {
  const start: string = formatHHmm(startIso);
  const endRaw: string | undefined = endIso;
  let timePart: string;
  if (endRaw !== undefined && endRaw.length > 0) {
    timePart = start + '–' + formatHHmm(endRaw);
  } else {
    timePart = start + ' · 未写结束';
  }
  return timePart + '  ' + title;
}
