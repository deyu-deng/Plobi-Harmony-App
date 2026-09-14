/**
 * 一条日程事件（与桌面 `/api/agenda` 返回字段对齐）。
 * 字段命名遵循 snake_case，对应后端 `to_dict()` 形状。
 */
export interface AgendaEvent {
  id: string;
  title: string;
  start_at: string;
  end_at?: string;
  kind: string;
  status: string;
  source: string;
}

export const EVENT_KIND_LABEL: Record<string, string> = {
  'meeting': '会',
  'task': '事',
  'ddl': '截',
  'class': '课',
};

export const EVENT_KIND_LIST: ReadonlyArray<string> = ['meeting', 'task', 'ddl', 'class'];
