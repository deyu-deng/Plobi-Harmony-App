import { http } from '@kit.NetworkKit';
import { AgendaEvent, DayPayload } from '../model/AgendaEvent';
import { ApiResult, doRequest } from './HttpKit';
import { dayEndBound, dayStartBound } from './WeekView';

/**
 * 日程客户端：读接口走设备面前缀 /api/handset/agenda*；令牌为设置页配对得到的设备令牌。
 * HTTP 样板（头部/URL/失败分类）收敛在 HttpKit.doRequest。
 */

export interface DismissResult {
  deleted: boolean;
  id: string;
}

export type DecideResponse = AgendaEvent | DismissResult;

export { ApiResult };

export function fetchAgenda(
  baseUrl: string,
  token: string,
  fromIso: string,
  toIso: string,
): Promise<ApiResult<AgendaEvent[]>> {
  const q: Record<string, string> = {
    // 后端 to 是时刻端点：裸日期会漏掉最后一整天（2026-10-14 实测丢周日 2 条），
    // 所以两端都补成日界——纯函数与用例在 service/WeekView.ets。
    'from': dayStartBound(fromIso),
    'to': dayEndBound(toIso),
  };
  return doRequest<AgendaEvent[]>(baseUrl, token, http.RequestMethod.GET, '/api/handset/agenda', q);
}

export function fetchPending(
  baseUrl: string,
  token: string,
): Promise<ApiResult<AgendaEvent[]>> {
  return doRequest<AgendaEvent[]>(baseUrl, token, http.RequestMethod.GET, '/api/handset/agenda/pending', undefined);
}

export function fetchDay(
  baseUrl: string,
  token: string,
  localDate: string,
): Promise<ApiResult<DayPayload>> {
  const q: Record<string, string> = {
    'date': localDate,
  };
  return doRequest<DayPayload>(baseUrl, token, http.RequestMethod.GET, '/api/handset/agenda/day', q);
}

export function postDecide(
  baseUrl: string,
  token: string,
  eventId: string,
  action: 'confirm' | 'dismiss',
): Promise<ApiResult<DecideResponse>> {
  return doRequest<DecideResponse>(
    baseUrl,
    token,
    http.RequestMethod.POST,
    '/api/handset/agenda/' + encodeURIComponent(eventId) + '/' + action,
    undefined,
  );
}
