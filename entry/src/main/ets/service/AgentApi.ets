import { http } from '@kit.NetworkKit';
import { ApiResult, doRequest } from './HttpKit';
import { ApiFailure } from './ApiError';

export interface AgentRowRaw {
  id: string;
  name?: string;
  role?: string;
  sessionId?: string;
}

/**
 * 总秘书列表客户端：设备面前缀 /api/handset/agents，由配对得到的设备令牌鉴权。
 * HTTP 样板收敛在 HttpKit.doRequest；200 但响应体不是数组时按失败分类，
 * 调用方按「拉取总秘书列表失败」口径提示。
 */
export function fetchAgents(baseUrl: string, token: string): Promise<ApiResult<AgentRowRaw[]>> {
  return doRequest<AgentRowRaw[]>(baseUrl, token, http.RequestMethod.GET, '/api/handset/agents', undefined)
    .then((res: ApiResult<AgentRowRaw[]>): ApiResult<AgentRowRaw[]> => {
      if (res.ok && res.data !== undefined && !Array.isArray(res.data)) {
        const failure: ApiFailure = {
          'kind': 'unknown',
          'short': '拉取总秘书列表失败',
          'hint': '桌面返回的不是列表；检查桌面版本',
        };
        const out: ApiResult<AgentRowRaw[]> = {
          ok: false,
          status: res.status,
          apiVersion: res.apiVersion,
          serverMajor: res.serverMajor,
          expectedMajor: res.expectedMajor,
          failure: failure,
          reason: 'agents response is not an array',
        };
        return out;
      }
      return res;
    });
}
