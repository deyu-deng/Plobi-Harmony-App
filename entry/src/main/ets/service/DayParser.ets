import { AgendaEvent, Anchor, PlanItem, ConflictPair, DayPayload } from '../model/AgendaEvent';

interface EmptyEvidence {
}

const EMPTY_EVIDENCE: EmptyEvidence = {};

/**
 * 把 `/api/agenda/day` 返回的 JSON 解到 `DayPayload`。
 * 缺字段降级为空数组 / null；不抛、不猜（与 H2-APP-V0 / H2-PAIR 同口径）。
 */
export function parseDayPayload(raw: string): DayPayload {
  const empty: DayPayload = {
    'date': '',
    'events': [],
    'anchors': [],
    'plan_items': [],
    'conflicts': [],
    'plan_status': null,
  };
  let obj: Object;
  try {
    obj = JSON.parse(raw) as Object;
  } catch (e) {
    return empty;
  }
  if (typeof obj !== 'object' || obj === null) {
    return empty;
  }
  const rec: Record<string, Object> = obj as Record<string, Object>;
  const out: DayPayload = {
    'date': typeof rec['date'] === 'string' ? (rec['date'] as string) : '',
    'events': parseEvents(rec['events']),
    'anchors': parseAnchors(rec['anchors']),
    'plan_items': parsePlanItems(rec['plan_items']),
    'conflicts': parseConflicts(rec['conflicts']),
    'plan_status': typeof rec['plan_status'] === 'string' ? (rec['plan_status'] as string) : null,
  };
  return out;
}

function parseEvents(raw: Object | undefined): AgendaEvent[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const arr: Object[] = raw as Object[];
  const out: AgendaEvent[] = [];
  for (let i: number = 0; i < arr.length; i++) {
    const e: Object | null = arr[i] as Object;
    if (e === null || typeof e !== 'object') {
      continue;
    }
    const r: Record<string, Object> = e as Record<string, Object>;
    const id: string = typeof r['id'] === 'string' ? (r['id'] as string) : '';
    if (id.length === 0) {
      continue;
    }
    const ev: AgendaEvent = {
      'id': id,
      'title': typeof r['title'] === 'string' ? (r['title'] as string) : '',
      'start_at': typeof r['start_at'] === 'string' ? (r['start_at'] as string) : '',
      'end_at': typeof r['end_at'] === 'string' ? (r['end_at'] as string) : undefined,
      'kind': typeof r['kind'] === 'string' ? (r['kind'] as string) : 'task',
      'status': typeof r['status'] === 'string' ? (r['status'] as string) : 'confirmed',
      'source': typeof r['source'] === 'string' ? (r['source'] as string) : 'manual',
      'overlaps': parseStringArray(r['overlaps']),
      'location': typeof r['location'] === 'string' ? (r['location'] as string) : undefined,
      'notes': typeof r['notes'] === 'string' ? (r['notes'] as string) : undefined,
    };
    out.push(ev);
  }
  return out;
}

function parseAnchors(raw: Object | undefined): Anchor[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const arr: Object[] = raw as Object[];
  const out: Anchor[] = [];
  for (let i: number = 0; i < arr.length; i++) {
    const a: Object | null = arr[i] as Object;
    if (a === null || typeof a !== 'object') {
      continue;
    }
    const r: Record<string, Object> = a as Record<string, Object>;
    const id: string = typeof r['id'] === 'string' ? (r['id'] as string) : '';
    const startAt: string = typeof r['start_at'] === 'string' ? (r['start_at'] as string) : '';
    const endAt: string = typeof r['end_at'] === 'string' ? (r['end_at'] as string) : '';
    if (id.length === 0 || startAt.length === 0) {
      continue;
    }
    const anc: Anchor = {
      'id': id,
      'title': typeof r['title'] === 'string' ? (r['title'] as string) : '',
      'start_at': startAt,
      'end_at': endAt,
      'template_id': typeof r['template_id'] === 'string' ? (r['template_id'] as string) : '',
      'flex': r['flex'] === true,
    };
    out.push(anc);
  }
  return out;
}

function parsePlanItems(raw: Object | undefined): PlanItem[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const arr: Object[] = raw as Object[];
  const out: PlanItem[] = [];
  for (let i: number = 0; i < arr.length; i++) {
    const p: Object | null = arr[i] as Object;
    if (p === null || typeof p !== 'object') {
      continue;
    }
    const r: Record<string, Object> = p as Record<string, Object>;
    const id: string = typeof r['id'] === 'string' ? (r['id'] as string) : '';
    if (id.length === 0) {
      continue;
    }
    const evEmpty: Object = EMPTY_EVIDENCE;
    const evRaw: Object | undefined = r['evidence'];
    const ev: Object = evRaw === undefined || evRaw === null ? evEmpty : evRaw;
    const item: PlanItem = {
      'id': id,
      'title': typeof r['title'] === 'string' ? (r['title'] as string) : '',
      'start_at': typeof r['start_at'] === 'string' ? (r['start_at'] as string) : '',
      'end_at': typeof r['end_at'] === 'string' ? (r['end_at'] as string) : undefined,
      'kind': typeof r['kind'] === 'string' ? (r['kind'] as string) : 'task',
      'evidence': ev,
    };
    out.push(item);
  }
  return out;
}

function parseConflicts(raw: Object | undefined): ConflictPair[] {
  if (!Array.isArray(raw)) {
    return [];
  }
  const arr: Object[] = raw as Object[];
  const out: ConflictPair[] = [];
  for (let i: number = 0; i < arr.length; i++) {
    const c: Object | null = arr[i] as Object;
    if (c === null || typeof c !== 'object') {
      continue;
    }
    const r: Record<string, Object> = c as Record<string, Object>;
    const left: string = typeof r['left_id'] === 'string' ? (r['left_id'] as string) : '';
    const right: string = typeof r['right_id'] === 'string' ? (r['right_id'] as string) : '';
    const startAt: string = typeof r['start_at'] === 'string' ? (r['start_at'] as string) : '';
    const endAt: string = typeof r['end_at'] === 'string' ? (r['end_at'] as string) : '';
    if (left.length === 0 || right.length === 0) {
      continue;
    }
    const pair: ConflictPair = {
      'left_id': left,
      'right_id': right,
      'start_at': startAt,
      'end_at': endAt,
    };
    out.push(pair);
  }
  return out;
}

function parseStringArray(raw: Object | undefined): string[] | undefined {
  if (!Array.isArray(raw)) {
    return undefined;
  }
  const arr: Object[] = raw as Object[];
  const out: string[] = [];
  for (let i: number = 0; i < arr.length; i++) {
    if (typeof arr[i] === 'string') {
      out.push(arr[i] as string);
    }
  }
  return out;
}