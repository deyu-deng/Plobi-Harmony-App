/**
 * 一条聊天消息（用户问 / 秘书答）。
 * `role` 严格只用 'user' / 'assistant'，UI 不暴露内部话术。
 */
export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  createdAtIso: string;
}

/**
 * 从 `/api/agents` 抽出的 L1（总秘书）信息。
 * 任务书 §复用：字段名以响应为准，不发明第二套 id。
 * 当前 desktop 的 `/api/agents` 会过滤掉 L1（裁定 19）；但 row 字段
 * 在架构师把 L1 加回该端点时可读。找不到时 `undefined`。
 */
export interface L1Info {
  agentId: string;
  agentName: string;
  role: string;
  sessionId: string;
}

/**
 * 一个 agent 行（`/api/agents` 列表的原始形状，按需取字段）。
 * 字段皆可缺（响应里有什么算什么）。
 */
export interface AgentRow {
  id: string;
  name?: string;
  role?: string;
  sessionId?: string;
}

/**
 * JSON-RPC `prompt.submit` 的 params（与 tui_gateway/server.py:8452 对齐）。
 * `session_id` 来自 L1Info.sessionId；`text` 是用户原话。
 */
export interface ChatSubmitParams {
  session_id: string;
  text: string;
}

/**
 * WS 服务端事件帧（按 tui_gateway/ws.py 已知 type 字段解析）。
 * 任何 type 未知 / 缺字段的事件 → kind='unknown'，UI 不崩。
 */
export type ChatEventKind = 'gateway-ready' | 'message-delta' | 'message-complete' | 'tool' | 'error' | 'unknown';

export interface ChatEvent {
  kind: ChatEventKind;
  /** For 'message-delta': the delta text. For others: empty. */
  text: string;
  /** Raw event type string for debug. */
  rawType: string;
  /** For 'error': the error code (string) if available. */
  errorCode?: string;
  /** For 'error': human-readable message. */
  errorMessage?: string;
}