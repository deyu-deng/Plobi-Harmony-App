import { AgentRow, L1Info } from '../model/ChatMessage';

interface JsonObject {
}

function asObject(v: Object | undefined | null): JsonObject | undefined {
  if (v === undefined || v === null) {
    return undefined;
  }
  return v as JsonObject;
}

/**
 * 从 `GET /api/agents` 返回的 JSON 里挑出「总秘书 / L1」那条。
 *
 * 任务书 §复用：
 *   「字段名以响应为准，不要猜出第二套 id」
 *   「找总秘书 / L1 / `sessionId` 非空的那条」
 *
 * 判定顺序（字段名按现有响应 + 常见别名）：
 *   1. `role === 'l1_secretary'` 或 role 含 'l1' / 'secretary'
 *   2. 同上但用 `name` 字段推断（中文别名 '总秘书' / 'master' 等）
 *   3. sessionId 非空
 *
 * 当前 desktop 的 `/api/agents` 会**过滤**掉 L1（裁定 19）—— 此函数会返回
 * undefined，调用方按「电脑端还没打开平板对话通道」提示用户即可。
 */
export function pickL1Row(json: string): L1Info | undefined {
  let parsed: Object;
  try {
    parsed = JSON.parse(json) as Object;
  } catch (e) {
    return undefined;
  }
  if (!Array.isArray(parsed)) {
    return undefined;
  }
  const arr: Object[] = parsed as Object[];
  for (let i: number = 0; i < arr.length; i++) {
    const info: L1Info | undefined = rowToL1IfMatches(arr[i]);
    if (info !== undefined) {
      return info;
    }
  }
  return undefined;
}

function rowToL1IfMatches(raw: Object | null): L1Info | undefined {
  if (raw === null || typeof raw !== 'object') {
    return undefined;
  }
  const rec: Record<string, Object> = raw as Record<string, Object>;
  const row: AgentRow = parseRow(rec);
  if (!isL1Row(row)) {
    return undefined;
  }
  if (row.sessionId === undefined || row.sessionId.length === 0) {
    return undefined;
  }
  return {
    'agentId': row.id,
    'agentName': row.name ?? row.id,
    'role': row.role ?? 'l1_secretary',
    'sessionId': row.sessionId,
  };
}

function parseRow(rec: Record<string, Object>): AgentRow {
  const idVal: Object = rec['id'];
  const nameVal: Object = rec['name'];
  const roleVal: Object = rec['role'];
  const sidVal: Object = rec['sessionId'];
  const id: string = typeof idVal === 'string' ? (idVal as string) : '';
  if (id.length === 0) {
    return { 'id': '' };
  }
  return {
    'id': id,
    'name': typeof nameVal === 'string' ? (nameVal as string) : undefined,
    'role': typeof roleVal === 'string' ? (roleVal as string) : undefined,
    'sessionId': typeof sidVal === 'string' ? (sidVal as string) : undefined,
  };
}

function isL1Row(row: AgentRow): boolean {
  const role: string | undefined = row.role;
  if (role !== undefined) {
    const low: string = role.toLowerCase();
    if (low === 'l1_secretary' || low.indexOf('l1') >= 0 || low.indexOf('secretary') >= 0) {
      return true;
    }
  }
  const name: string | undefined = row.name;
  if (name !== undefined) {
    const lowN: string = name.toLowerCase();
    if (lowN.indexOf('总秘书') >= 0 || lowN.indexOf('master') >= 0 || lowN.indexOf('secretary') >= 0) {
      return true;
    }
  }
  return false;
}

/**
 * 把 `/api/agents/:id/overview` 返回里的 `sessionId` 抽出来。
 * 用于「列表里没 L1 但 id 已知」的退化路径；裁定 19 当前 L1 不在列表里。
 */
export function extractSessionIdFromOverview(json: string): string | undefined {
  let parsed: Object;
  try {
    parsed = JSON.parse(json) as Object;
  } catch (e) {
    return undefined;
  }
  const rec: Record<string, Object> = parsed as Record<string, Object>;
  const v: Object | undefined = rec['sessionId'];
  if (typeof v === 'string') {
    const s: string = v as string;
    if (s.length > 0) {
      return s;
    }
  }
  return undefined;
}