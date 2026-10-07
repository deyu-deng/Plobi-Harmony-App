# Implementation Plan: handset-pairing（设备配对与设备面切换 WP-APP-HANDSET）

**Input**: Feature specification from `D:\Projects\Plobi\Plobi-Harmony-App\spec\handset-pairing\spec.md`

## Summary

把鸿蒙 App 从旧看板路径 `/api/agenda/*` + 手填令牌（当前必 401）整体切换到桌面设备面 `/api/handset/*` + 配对签发的一机一令牌：新增 6 位配对码兑换流程（设置页）、五个日程接口与 agents 预切全部改走设备面前缀、401/403 与 WS 握手失败统一引导「重新配对」、移除手填令牌入口；同时按用户确认清理上次代码体检发现的工程瑕疵（死代码、重复样板、魔法字符串、kind 标签不一致、targetSdkVersion 缺失）。

技术路径：新建 `service/HttpKit.ets` 收敛两份 HTTP 客户端的全部公共样板并单点定义令牌头常量；新建 `service/PairingApi.ets` 承载配对兑换与纯函数解析（可单测）；`AgendaApi`/`AgentApi` 仅保留路径与响应形状差异；`ApiError` 增加配对失败分类与等待时长文案。页面层只改 `SettingsPage`（配对表单全面改版）与两个既有页的辅助函数收敛，数据流（Preferences 缓存、离线降级、提醒重排）不动。

## Technical Context

**Language/Version**: ArkTS（HarmonyOS Stage 模型，工程开启 strictMode）；compatibleSdkVersion `5.0.0(12)`，本次补 targetSdkVersion `5.0.0(12)`
**Primary Dependencies**: `@kit.NetworkKit`（http / webSocket）、`@kit.BasicServicesKit`（BusinessError）、`@kit.BackgroundTasksKit`（reminderAgentManager）、`@kit.NotificationKit`、`@ohos/hypium` 1.0.21（单测）
**State Management**: State Management V1（@Component/@State/@Prop）。增量项目，按规则保留现状，不迁移 V2
**Storage**: 本机 Preferences（经 `entry\src\main\ets\service\Cache.ets` 的 getStringSync/putString/putNumber 封装）。令牌与配对信息只存本机、不入日志、不入 URL
**Testing**: hypium 纯逻辑单测，位于 `entry\src\test\`（describe/it + `export default function xxxTest()` 约定；本仓无集中注册入口，新文件沿用既有 8 个测试文件的同款形态）
**Target Platform**: HarmonyOS 平板（Plobi 平板端），经局域网访问 Windows 桌面后端 `http://<LAN-IP>:8787`
**Project Type**: mobile-app
**Performance Goals**: 请求超时沿用 5s；配对全流程（填码→点配对→见已配对）≤1 分钟（SC-001）
**Constraints**: 401 判定只看状态码（不解析响应体字样）；配对锁定（429）期间不自动重试；设备钥匙打写口必 401（设计如此，不重试）；WS 握手真机能否带自定义头未实测（按现状实现，提示文案覆盖两种可能）
**Scale/Scope**: 3 页 + 约 20 个源文件的小型应用。本次改 13 个既有源文件 + 4 个既有测试文件 + 1 个配置文件，新增 2 个源文件 + 2 个测试文件

## Project Structure

PROJECT_ROOT = `D:\Projects\Plobi\Plobi-Harmony-App`

### Documentation (this feature)

```text
D:\Projects\Plobi\Plobi-Harmony-App\spec\handset-pairing\
├── spec.md              # 需求基线（Phase 1 已确认）
├── plan.md              # 本文件（/spec-plan 输出）
└── tasks.md             # Phase 3 生成
```

### Source Code (repository root)

```text
# [新] 新增文件
entry/src/main/ets/service/HttpKit.ets           # 共享 HTTP 样板 + 令牌头常量单点
entry/src/main/ets/service/PairingApi.ets        # 配对兑换 + 纯函数解析/校验
entry/src/test/HttpKit.test.ets                  # HttpKit 纯函数单测
entry/src/test/PairingApi.test.ets               # 配对纯函数单测

# [改] 修改文件
entry/src/main/ets/service/AgendaApi.ets         # 路径切设备面；样板收敛到 HttpKit
entry/src/main/ets/service/AgentApi.ets          # 路径预切设备面；结果类型统一
entry/src/main/ets/service/ApiError.ets          # 拼写修复；401 提示改写；配对失败分类
entry/src/main/ets/service/WsChat.ets            # 令牌头改导入；握手失败归类改写
entry/src/main/ets/service/Timeline.ets          # kind 映射委托 kindLabelOf；补零收敛
entry/src/main/ets/service/ChatSession.ets       # 删 asObject/JsonObject 死代码
entry/src/main/ets/service/ReminderService.ets   # 删不可达分支；触发时刻改用 tMinusFifteen
entry/src/main/ets/model/AppConfig.ets           # 删未用接口；新增 3 个常量键 + 默认设备名
entry/src/main/ets/model/AgendaEvent.ets         # 新增 kindLabelOf；删未用 kind 常量
entry/src/main/ets/utils/TimeFormat.ets          # 导出 padTwo；新增 formatTimeRange/formatLocalNowHHmm
entry/src/main/ets/utils/LocalDate.ets           # 内部补零收敛；新增 tomorrowLocalIso
entry/src/main/ets/components/EventCard.ets      # kind 显示改中文标签（与时间线同源）
entry/src/main/ets/pages/SettingsPage.ets        # 配对表单全面改版（删手填令牌）
entry/src/main/ets/pages/Index.ets               # 删本地重复辅助；未配对提示改口径
entry/src/main/ets/pages/ChatPage.ets            # 删未用常量/本地时间函数；类型随 AgentApi 统一
entry/src/test/ApiError.test.ets                 # 401 提示断言更新；新增配对分类/时长文案测试
entry/src/test/TimeFormat.test.ets               # 新增 formatTimeRange/padTwo 断言
entry/src/test/LocalDate.test.ets                # 新增 tomorrowLocalIso 断言
entry/src/test/Timeline.test.ets                 # kindLabelOf 断言（kindLabel 行为保持）
build-profile.json5                              # products[0] 增加 targetSdkVersion
```

**Structure Decision**: 沿用既有工程架构（`pages/ components/ service/ model/ utils/ entryability/` 责任边界，数据持久化经 `service/Cache.ets`）。不做 MVVM 迁移、不新增目录层级——这是增量改造而非新工程，触发条件不满足。只新增 2 个源文件：`HttpKit.ets`（FR-012 要求的样板单点收敛，两个既有客户端 + 新配对客户端三方共享，必须独立成模块避免循环依赖）；`PairingApi.ets`（FR-004/005/006 的配对调用与纯函数解析，独立成模块才能在不依赖网络的前提下单测）。资源无新增，全部放 `entry/src/main/resources/` 之外的改动为零。

## Complexity Tracking

无 Constitution 违规，无需豁免条目。

## Research & Decisions

### D1 配对契约采信与响应处理

- **Decision**: 配对调用 `POST /api/handset/pair/redeem`，请求体 `{"code": "<6位数字>", "deviceName": "<名字>"}`，成功 200 返回 `{"deviceId": "...", "token": "...", "scopes": [...]}`。设备面唯一免凭证调用（不带令牌头）。`token`/`deviceId` 解析缺失即视为失败（不落半截状态）；`scopes` 不落盘（App 侧暂无用途，减少敏感数据持久化）。
- **Rationale**: 桌面契约真源（`D:\Projects\Plobi\Plobi-Desktop\Docs\specs\handset-app.md` §2）实测口径：令牌只在配对响应出现一次，桌面不存明文；丢令牌无找回只能重新配对。spec 边缘情况明确 200 缺 token 按失败处理。
- **Alternatives considered**: 保存 scopes 备将来权限 UI（拒绝——无消费方，先不落盘）；解析失败时仍保存部分字段（拒绝——半截状态正是 spec 明令禁止的）。

### D2 令牌传递方式沿用 X-Plobi-Session-Token

- **Decision**: 所有设备面请求继续用既有头名 `X-Plobi-Session-Token` 传设备令牌，不切换到 `Authorization: Bearer`。
- **Rationale**: 桌面两种方式都接受，后者是给「反代理占用 Authorization」留的口；App 已在用前者，令牌值从「手填」变「配对签发」但头名与存储键（`plobi.token`）不变，链路（含 WS 头注入）零额外改动，符合 spec 假设「沿用现有令牌头名」。
- **Alternatives considered**: 切 Authorization Bearer（拒绝——无收益，徒增改动面）；两种都发（拒绝——多余且泄露传递方式细节）。

### D3 令牌头常量单点定义

- **Decision**: `HEADER_TOKEN`（与 `HEADER_API_VERSION`）只在 `HttpKit.ets` 定义并导出；`WsChat.ets` 改为导入，删除其本地副本；`AgendaApi`/`AgentApi` 的本地副本随样板收敛一并消失。
- **Rationale**: FR-012/US6-3 要求全仓单点；当前 4 处定义（AgendaApi/AgentApi/WsChat/ChatPage——后者定义了但未使用，属死代码直接删）。
- **Alternatives considered**: 放 `model/AppConfig.ets`（拒绝——配置键与协议头语义不同；HttpKit 是所有请求构造的汇聚点，放这里最小导入距离）。

### D4 401 判定与提示改写

- **Decision**: 拒绝判定只看 HTTP 状态码（401/403 → token-rejected），不解析响应体。`TOKEN_HINT` 从「桌面运行 doctor --print-app-token 重新填」改为「令牌失效：到「设置」里重新配对」类指引（含「重新配对」字样）。`classifyHttpFailure` 的 401/403 分支 short 保持「令牌错（HTTP xxx）」口径，hint 换新文案——Index/ChatPage 的错误横幅自动获得新指引（FR-009）。
- **Rationale**: 契约明确「拒绝只看状态码：401 = 钥匙不对/没给；不要靠 body 里的字样判断」；`doctor --print-app-token` 已随裁定 68 退役，旧提示指向不存在的命令。
- **Alternatives considered**: 保留旧提示（拒绝——指引错误路径）；按 body 字样细分（拒绝——契约明令禁止）。

### D5 agents 预切设备面前缀

- **Decision**: `fetchAgents` 的路径改为 `/api/handset/agents`（其余签名不变）。桌面侧尚未开放此口子，失败时 ChatPage 沿用既有「电脑端还没打开平板对话通道」类提示，不新增任何契约猜测。
- **Rationale**: 用户在 Phase 1 澄清中明确选择预切（FR-003）；桌面开口后 App 无需再改。设备面前缀下未知路由由桌面返回失败，App 侧按通用失败口径展示即可。
- **Alternatives considered**: 保持 `/api/agents`（拒绝——用户已裁决预切）；新增配置开关切换前缀（拒绝——过度设计）。

### D6 测试连接改打 GET /api/status

- **Decision**: 设置页「测试连接」改调免钥匙的 `GET /api/status`，替换现版 `fetchAgenda(url, tok, '2999-01-01', '2999-01-02')` 的探活 hack。
- **Rationale**: 契约表内明确 `GET /api/status` 是「后端活没活」专用口、无需钥匙——探活语义精确匹配，且不依赖令牌（可在配对前单独验证地址）。现版 hack 在配对流程里既要求令牌又构造假日期，语义都不对。
- **Alternatives considered**: 打设备面 agenda 口探活（拒绝——要求令牌，配对前不可用，且混淆「桌面活着」与「令牌有效」两件事）。

### D7 HTTP 样板收敛为 HttpKit + 结果类型统一

- **Decision**: 新建 `HttpKit.ets` 收拢 `AgendaApi`/`AgentApi` 的全部重复样板（请求头构造、尾部斜杠处理、URL+query 拼装、响应头读取、版本解析、失败分类入口、通用 doRequest）。`ApiResult<T>` 移到 HttpKit 定义，`AgendaApi` re-export 保持既有导入点兼容；`AgentApi` 重复的 `ApiResultAgents` 删除，`fetchAgents` 返回 `ApiResult<AgentRowRaw[]>`（200 但非数组的响应按失败分类，保持既有「拉取总秘书列表失败」口径）。`doRequest` 增加两个能力：可选请求体（POST JSON，配对需要）、`token` 为空时省略令牌头（redeem 免凭证）；结果对象增加可选原始响应头（`headers?: Object`），供 PairingApi 读取 `Retry-After`。
- **Rationale**: FR-012 要求公共样板收敛为共享实现；当前两份客户端约 60 行逐行雷同。`ApiResult` 是请求结果的通用契约，属于 HttpKit 的自然职责；re-export 让 Index/SettingsPage 的导入行不动。响应头透出保持 HttpKit 通用性（Retry-After 是标准 HTTP 头，不在通用层做配对特判）。
- **Alternatives considered**: 各客户端保留私有样板仅共享常量（拒绝——收敛不彻底，新增第三个客户端时样板会三度复制）；把 Retry-After 解析放 HttpKit（拒绝——配对特有语义，放 PairingApi 纯函数侧便于单测）。

### D8 WS 握手失败的归类（有文档证据）

- **Decision**: `WsChat` 连接阶段失败（open 前的 error / connect 回调 err）的归类规则：timeout / unreachable 类消息保留网络归因（lan-unreachable / desktop-offline 的既有 hint）；其余（含「Websocket connect failed」「connect failed」等通用握手失败签名）统一归入 kind `token-rejected`，short「对话通道握手失败」，hint 覆盖三种可能：「令牌可能已失效，到「设置」里重新配对；或电脑端还没打开平板对话通道；或桌面没开机」。同时 `classifyWsClose` 的 4401 分支保留但 hint 改为重新配对指引（删 doctor 引用）；通用关闭分支 hint 补「或令牌失效，到设置重新配对」。
- **Rationale**: 已用 `devecocli docs` 核实（webSocket错误码文档）：`@ohos.net.webSocket` 握手被服务端 HTTP 拒绝时客户端只收到通用错误 code 200「Websocket connect failed.」，**不透出 HTTP 403 状态码**——无法在客户端精确区分 403 与其他握手失败。FR-010 与 spec 边缘情况明确要求提示文案「覆盖两种可能」（重新配对或通道未开），合并提示是诚实且合规的唯一方案。失败 kind 不驱动任何分支逻辑（仅展示 short/hint），归 token-rejected 不产生副作用。
- **Alternatives considered**: 按消息含「403」精确识别（拒绝——文档证实状态码不透出，做了也是死分支）；connect 失败一律显示裸网络错误（拒绝——违反 FR-010「不显示为裸网络错误」）。

### D9 kind 中文标签全仓单点

- **Decision**: `AgendaEvent.ets` 新增导出 `kindLabelOf(kind: string): string`（meeting→会、task→事、ddl→截、class→课、meal→餐、空→事、其他→原样）；`Timeline.kindLabel` 的 kind 映射委托给它（anchor→作息特例保留在 Timeline）；`EventCard` 的 kind 徽标从裸英文 `this.event.kind` 改为 `kindLabelOf(this.event.kind)`。删除无使用者的 `EVENT_KIND_LABEL` 与 `EVENT_KIND_LIST`。
- **Rationale**: FR-013 要求全仓一份映射；当前 EventCard 显示英文裸值、Timeline 显示中文，同屏不一致。映射的「领域真源」是事件模型，放 `AgendaEvent.ets`；Timeline 保留 anchor 特例是因为 anchor 是时间线概念不是事件 kind。
- **Alternatives considered**: 映射留在 Timeline 让 EventCard 导入（拒绝——待确认卡片不是时间线的从属概念，事件模型才是共同上游）。

### D10 时间/日期辅助收敛

- **Decision**: `TimeFormat.ets` 导出 `padTwo(n)`、新增 `formatTimeRange(startIso, endIso?)`（只产时间段文本「HH:MM–HH:MM」或「HH:MM · 未写结束」，解析失败 `--:--`；`formatEventLine` 内部改用它，行为不变）与 `formatLocalNowHHmm()`。`LocalDate.ets` 新增 `tomorrowLocalIso()`（用 Date 构造器日期进位处理跨月/跨年），内部补零改用 `padTwo`。`Index.ets` 删除本地 `formatLine/hhmm/isoDay/tomorrowLocalIso/formatNow` 五个重复实现，改用上述共享版；`parseEventsJson` 内的 `isoDay(0)/isoDay(1)` 改用 `todayLocalIso()/tomorrowLocalIso()`。`ChatPage.ets` 删本地 `formatLocalTime`，改用 `formatHHmm`。`Timeline.ets` 的 `startMinute` 内部补零改用 `padTwo`。
- **Rationale**: FR-012 要求补零与时间格式化单点复用；当前 `pad()` 局部函数在 6 处重复、`formatLine/hhmm` 与 `formatEventLine/formatHHmm` 语义重复。`formatEventLine` 现签名强制拼标题，时间线行只要时间段，故拆出 `formatTimeRange` 作为共用底座。
- **Alternatives considered**: `formatEventLine` 加可选参（拒绝——两职责两个函数比一个带开关的函数清晰）。

### D11 ReminderService 不可达分支移除

- **Decision**: `rescheduleReminders` 循环内删除 `pickRemindersForEvents([e], nowEpochSeconds)` 的逐条重推导（e 已在 picked 结果里，重推导必然非空，属不可达防御分支）；提醒触发时刻改用 `tMinusFifteen(e.start_at, nowEpochSeconds)` 的结果（与挑选口径同源），行为不变。
- **Rationale**: FR-016 要求移除不可达分支且行为不变；触发时刻「start − 15min」当前在两处各写一遍（挑选器内部与发布处），统一走 `tMinusFifteen` 消除双份口径漂移风险。
- **Alternatives considered**: 保留防御分支（拒绝——体检已判定死代码）。

### D12 targetSdkVersion 声明位置（有文档证据）

- **Decision**: 工程级 `build-profile.json5` 的 `app.products[0]` 中、与 `compatibleSdkVersion` 并列增加 `"targetSdkVersion": "5.0.0(12)"`。
- **Rationale**: 已用 `devecocli docs` 核实（工程级 build-profile.json5 文档与 FAQ：compileSdkVersion/targetSdkVersion/compatibleSdkVersion 均为 products 下字段）。与 compatibleSdkVersion 取同值，消除构建警告（FR-015）且不改变兼容语义。
- **Alternatives considered**: 模块级配置（拒绝——文档明确为工程级 app.products 字段）。

### D13 状态管理保留 V1

- **Decision**: 本次全部改动沿用 @State/@Prop/@Component（V1），不迁移 V2。
- **Rationale**: 增量项目规则：保留既有状态管理，除非显式要求迁移。新表单状态量小（约 8 个 @State），V1 完全胜任。
- **Alternatives considered**: 顺手迁移 V2（拒绝——超范围，扩大回归面）。

### D14 测试策略

- **Decision**: 新增测试只覆盖纯函数（HttpKit 的 URL/头解析、PairingApi 的校验/解析/Retry-After、ApiError 的配对分类与时长文案、formatTimeRange、tomorrowLocalIso、kindLabelOf），不做网络/真机依赖测试；受提示文案变化影响的既有断言（`ApiError.test.ets` 中 401 hint 含「doctor」）同步更新为含「重新配对」。新测试文件沿用本仓既有形态（hypium describe/it + export default function，无集中注册入口）。
- **Rationale**: spec 假设「单测保持纯逻辑风格（不依赖真机/网络）」；网络路径由桌面契约实测背书，App 侧单测钉住的是映射/解析/文案逻辑。
- **Alternatives considered**: 加 mock HTTP 层测 doRequest（拒绝——引入 mock 基建超范围，纯函数覆盖已钉住分类逻辑）。

### D15 解除配对语义

- **Decision**: 「解除配对」清除本机三个键：`plobi.token`、`plobi.deviceId`、`plobi.deviceName`；`plobi.baseUrl` 保留（用户下次配对不用重填地址）。回未配对态。桌面侧设备列表的撤销由桌面管理，不在本仓范围。
- **Rationale**: FR-008 只要求清本机令牌与配对信息；地址不是配对产物，保留它符合「1 分钟完成配对」的 SC-001。
- **Alternatives considered**: 连地址一起清（拒绝——制造无谓的重输成本）；调桌面 API 注销设备（拒绝——契约无此口子，且 spec 明确划出范围）。

## Data Model

### 配对请求/响应（与桌面契约对齐）

- **PairRedeemRequest**（请求体形状）：`{ code: string, deviceName: string }`；code 恒为 6 位数字字符串；deviceName 为 trim 后非空字符串（空输入用默认值填充后才发送）。
- **PairRedeemResponse**（响应形状）：`{ deviceId: string, token: string, scopes?: string[] }`；`token` 43 字符设备令牌；`scopes` 收到但不持久化。
- **PairResult**（PairingApi 返回）：`{ ok: boolean, deviceId?: string, token?: string, failure?: ApiFailure }`；ok=true 时 deviceId/token 必有；失败时 failure 必有。

### 失败分类扩展（ApiError）

- `ApiFailureKind` 在既有五种（desktop-offline / lan-unreachable / token-rejected / http-error / unknown）外新增：`'pair-code-rejected'`（401：码错/过期/已用）与 `'pair-locked'`（429：连错锁定）。
- `ApiFailure` 新增可选字段 `retryAfterSeconds?: number`（仅 pair-locked 携带，来自 `Retry-After` 响应头，秒）。

### 输入校验规则（纯函数，SettingsPage 前置拦截）

- 配对码：`^[0-9]{6}$` 精确匹配；不匹配则不发请求，提示格式错误。
- 设备名：trim 后为空 → 上报默认 `'Plobi 平板'`（DEFAULT_DEVICE_NAME）；trim 后长度（string.length）> 64 → 不允许提交，提示超长；其余原样上报。
- 桌面地址：trim 后非空即可（沿用现状，不新增格式校验）。

### 配对等待时长文案（formatWaitSeconds）

- `retryAfterSeconds` < 60 → 「N 秒」；< 3600 → 「约 N 分钟」（向上取整）；≥ 3600 → 「约 N 小时」（四舍五入）；缺失 → 「约 1 小时」。文案拼接进 pair-locked 的 hint，锁定期间不自动重试（仅用户再次点击才发请求）。

### Preferences 键（model/AppConfig）

| 键 | 常量 | 语义 |
|---|---|---|
| `plobi.baseUrl` | PREF_KEY_BASE_URL（既有） | 桌面地址；配对与解除配对均保留 |
| `plobi.token` | PREF_KEY_TOKEN（既有） | 设备令牌（值来源从手填改为配对签发；键名/头名不变） |
| `plobi.deviceId` | PREF_KEY_DEVICE_ID（新） | 配对响应的 deviceId；解除配对时清除 |
| `plobi.deviceName` | PREF_KEY_DEVICE_NAME（新） | 已配对设备名（设置页展示用）；解除配对时清除 |
| `plobi.apiVersion` | PREF_KEY_API_VERSION（新） | Index 刷新后落盘的桌面版本号（原裸字符串键纳入常量，FR-014） |
| `plobi.lastSyncAt` 等 | 既有缓存键 | 不动 |

- **配对态判定**：`plobi.token` 存在且非空 = 已配对（派生态，不单独存布尔）。

### SettingsPage 视图状态（@State）

`baseUrl`（回填）、`pairCode`、`deviceName`（回填）、`isPairing`（请求中禁用按钮）、`pairedDeviceName`（已配对态展示）、`pairHint`（配对结果/错误文案）、`testHint`（测试连接文案）；已配对/未配对两段 UI 由 token 派生切换。

## Contracts & Interfaces

### 外部契约：桌面设备面 API（真源 `D:\Projects\Plobi\Plobi-Desktop\Docs\specs\handset-app.md` §2）

| 用途 | 请求 | 鉴权 | 成功响应 | 失败语义 |
|---|---|---|---|---|
| 配对兑换 | `POST /api/handset/pair/redeem`，body `{code, deviceName}` | **免凭证**（唯一例外） | 200 `{deviceId, token, scopes}` | 同码二次/过期/错码=401；连错 5 次=429+`Retry-After`（秒），锁 1 小时 |
| 今日+明日清单 | `GET /api/handset/agenda?from=YYYY-MM-DD&to=YYYY-MM-DD` | 设备令牌 | 200 `AgendaEvent[]` | 401/403=令牌问题 |
| 待确认队列 | `GET /api/handset/agenda/pending` | 设备令牌 | 200 `AgendaEvent[]` | 同上 |
| 一天快照 | `GET /api/handset/agenda/day?date=YYYY-MM-DD` | 设备令牌 | 200 `DayPayload` | 同上 |
| 批一条 | `POST /api/handset/agenda/{id}/confirm` | 设备令牌 | 200 `AgendaEvent` 或 `{deleted:true}` | 错 id=404（不是 401） |
| 忽略一条 | `POST /api/handset/agenda/{id}/dismiss` | 设备令牌 | 200 同上 | 同上 |
| 桌面探活 | `GET /api/status` | 免钥匙 | 200 | 连接层失败走三分类 |
| 聊天 | `ws://<LAN-IP>:8787/api/ws` + `X-Plobi-Session-Token` 头 | 设备令牌 | 升级成功 | 错/缺令牌=HTTP 403 升级拒绝（客户端只见通用握手失败错误）；撤销设备下次握手即失败 |
| （预切）总秘书列表 | `GET /api/handset/agents` | 设备令牌 | 桌面侧**未开放** | 失败按既有「通道未开」提示，不猜契约 |

横切规则：每个响应带 `X-Plobi-Api-Version: 1`；鉴权失败判定只看状态码；设备钥匙打写口（POST/PATCH/DELETE 到 agenda 本体）一律 401，不重试；`/api/handset/*` 桌面浏览器登录态同样 401（设备专用前缀）。

### 内部契约：模块公开接口（文件绝对路径）

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\service\HttpKit.ets`（新）**

- `HEADER_TOKEN: string`、`HEADER_API_VERSION: string`（常量单点，FR-012）
- `RequestHeader`（接口：Accept + 令牌头 + 版本头）
- `ApiResult<T>`（自 AgendaApi 迁入，形状不变；新增可选 `headers?: Object` 原始响应头）
- `doRequest<T>(baseUrl, token, method, path, query?, body?): Promise<ApiResult<T>>` —— token 为空字符串时省略令牌头；body 非空时按 JSON 请求体发送；超时 5s；返回结果含响应头与版本解析，与现 AgendaApi.doRequest 行为一致
- 纯函数（导出供单测）：`trimTrailingSlash(s)`、`buildUrl(baseUrl, path, query?)`、`readHeader(headerObj, key)`、`readApiVersion(header)`、`buildFailure(status, reason)`

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\service\PairingApi.ets`（新）**

- `redeemPairCode(baseUrl, code, deviceName): Promise<PairResult>` —— POST redeem，免凭证；401→pair-code-rejected、429→pair-locked（读 `Retry-After` 头，小写键）、其余按 ApiError 通用分类；200 但缺 token/deviceId → `{ok:false, failure:{kind:'unknown', short:'配对响应不完整', …}}`，不落半截状态
- `fetchServerStatus(baseUrl): Promise<ApiResult<Object>>` —— GET `/api/status`，免钥匙（设置页测试连接）
- 纯函数（导出供单测）：`isSixDigitCode(raw)`、`resolveDeviceName(raw)`、`isValidDeviceName(raw)`、`parsePairResponse(raw)`、`parseRetryAfterSeconds(raw)`

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\service\ApiError.ets`（改）**

- 既有四函数签名不变：`classifyConnectFailure` / `classifyHttpFailure` / `serverMajorVersion` / `classifyVersion`
- `classifyHttpFailure` 的 401/403 分支：short 不变，hint 改为「令牌失效：到「设置」里重新配对」类指引（删 doctor 引用）
- 新增：`classifyPairFailure(status, retryAfterSeconds?): ApiFailure`（401→pair-code-rejected；429→pair-locked 含等待文案；其余委托 classifyHttpFailure）；`formatWaitSeconds(seconds?): string`（D10 文案规则）
- 私有常量 `REFETUSED_KEYS` 改名 `REFUSED_KEYS`（拼写修复，无外部影响）
- `ApiFailureKind` 扩两值、`ApiFailure` 加可选 `retryAfterSeconds`（见 Data Model）

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\service\AgendaApi.ets`（改）**

- 公开函数签名不变：`fetchAgenda(baseUrl, token, fromIso, toIso)` / `fetchPending(baseUrl, token)` / `fetchDay(baseUrl, token, localDate)` / `postDecide(baseUrl, token, eventId, action)`；`DismissResult`、`DecideResponse` 不动
- 路径换前缀：`/api/handset/agenda`、`/api/handset/agenda/pending`、`/api/handset/agenda/day`、`/api/handset/agenda/{id}/confirm|dismiss`（FR-001）
- `ApiResult` re-export（导入点 `D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\pages\Index.ets` 与 SettingsPage 的既有 import 不需改）
- 本地样板（RequestHeader/常量/解析/构造函数）全部删除，改用 HttpKit

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\service\AgentApi.ets`（改）**

- `fetchAgents(baseUrl, token): Promise<ApiResult<AgentRowRaw[]>>`（路径 `/api/handset/agents`，FR-003；`ApiResultAgents` 删除，类型统一）；200 非数组按失败分类（保持既有提示口径）；`AgentRowRaw` 不动；本地样板删除

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\service\WsChat.ets`（改）**

- `sendPromptOverWs(baseUrl, token, params): Promise<ChatSendOutcome>` 签名与事件解析逻辑不变
- 删本地 `HEADER_TOKEN`，改导入 HttpKit（FR-012）
- 连接阶段失败归类按 D8；`classifyWsClose` 4401 分支 hint 改重新配对指引、通用关闭分支 hint 补令牌失效可能（FR-010）

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\model\AppConfig.ets`（改）**

- 删 `AppConfig` 接口（无使用者，FR-011）
- 新增导出：`PREF_KEY_API_VERSION = 'plobi.apiVersion'`、`PREF_KEY_DEVICE_ID = 'plobi.deviceId'`、`PREF_KEY_DEVICE_NAME = 'plobi.deviceName'`、`DEFAULT_DEVICE_NAME = 'Plobi 平板'`；`DEFAULT_API_VERSION` 与既有 PREF_KEY_* 不动（FR-014）

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\model\AgendaEvent.ets`（改）**

- 新增导出 `kindLabelOf(kind: string): string`（映射见 D9）；删 `EVENT_KIND_LABEL`、`EVENT_KIND_LIST`（均无使用者，FR-011/013）；其余接口（AgendaEvent/Anchor/PlanItem/ConflictPair/DayPayload）不动

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\utils\TimeFormat.ets`（改）**

- 新增导出：`padTwo(n: number): string`、`formatTimeRange(startIso: string, endIso?: string): string`、`formatLocalNowHHmm(): string`
- `formatHHmm` / `parseLocalTime` / `formatEventLine` 签名与行为不变（后者内部改用 formatTimeRange）

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\utils\LocalDate.ets`（改）**

- 新增导出 `tomorrowLocalIso(): string`；`localDateIso` / `todayLocalIso` / `localDateOfIso` 签名不变；内部补零改用 padTwo（FR-012）

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\service\Timeline.ets`（改）**

- `kindLabel(r: TimelineRow): string` 签名与行为不变（既有测试保持绿），kind 映射委托 `kindLabelOf`，anchor→作息特例保留；其余导出不动；`startMinute` 内部补零改用 padTwo

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\service\ChatSession.ets`（改）**

- 删 `JsonObject` 接口与 `asObject` 函数（无使用者，FR-011）；`pickL1Row` / `extractSessionIdFromOverview` 不动

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\service\ReminderService.ets`（改）**

- `rescheduleReminders(events, previous, nowEpochSeconds): Promise<RescheduleOutcome>` 签名与行为不变；内部删不可达重推导分支、触发时刻改用 `tMinusFifteen`（FR-016，D11）；其余导出不动

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\components\EventCard.ets`（改）**

- 对外属性（event/confirmAction/dismissAction）与交互不变；kind 徽标改显 `kindLabelOf(this.event.kind)`（FR-013）

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\pages\SettingsPage.ets`（改版）**

- 删手填令牌输入框与旧「保存」双字段流程（FR-007）
- 未配对态：桌面地址 + 配对码（6 位数字，数字键盘）+ 设备名（可选）+「配对」按钮；地址在每次配对/测试动作前往 `plobi.baseUrl` 持久化（无独立保存按钮）
- 已配对态：`已配对 · <设备名>` +「解除配对」+「测试连接」；解除配对清三键（D15）
- 配对动作前置校验（D10 规则）：码非 6 位数字/设备名超长 → 本地提示不发请求；成功 → 持久化 token/deviceId/deviceName 并切已配对态；失败 → 按 failure.kind 显示（pair-code-rejected / pair-locked 含等待时长 / 网络类 short+hint）；isPairing 期间禁用按钮；**无任何自动重试**（FR-006）
- 测试连接：`fetchServerStatus`；成功「桌面在线」；失败按分类提示（FR 与 D6）
- 说明文案更新：删 doctor 引用，改为「在桌面 PAIRING 页点新码获得 6 位配对码」指引

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\pages\Index.ets`（改）**

- 数据流（缓存加载、三接口并发刷新、错误/版本横幅、提醒重排）不动；调用签名不变
- 删本地 `formatLine/hhmm/isoDay/tomorrowLocalIso/formatNow`（改用共享版，D10）；删未使用的 `localDateOfIso` 导入（FR-011）
- `putNumber('plobi.apiVersion', …)` 改用 `PREF_KEY_API_VERSION`（FR-014）
- 刷新前置校验文案：`请先在「设置」里填桌面地址和令牌` → `请先在「设置」里配对`（US2-3）；`decide` 的既有同款文案不动

**`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\main\ets\pages\ChatPage.ets`（改）**

- 删未使用 `HEADER_TOKEN` 常量（FR-011）；删本地 `formatLocalTime` 改用 `formatHHmm`（FR-012）；`ApiResultAgents` → `ApiResult<AgentRowRaw[]>`（D7）；其余逻辑（L1 解析、历史持久化、发送流程）不动

**`D:\Projects\Plobi\Plobi-Harmony-App\build-profile.json5`（改）**

- `app.products[0]` 增加 `"targetSdkVersion": "5.0.0(12)"`（D12，FR-015）；其余不动

**测试文件（`D:\Projects\Plobi\Plobi-Harmony-App\entry\src\test\`）**

- `ApiError.test.ets`（改）：401 hint 断言「doctor」→「重新配对」；新增 classifyPairFailure（401/429 带/不带时长/其他状态）与 formatWaitSeconds（秒/分钟/小时/缺失四档）用例
- `PairingApi.test.ets`（新）：isSixDigitCode、resolveDeviceName（空→默认/trim）、isValidDeviceName（64 边界）、parsePairResponse（完整/缺 token/缺 deviceId/坏 JSON）、parseRetryAfterSeconds（'3600'→3600、'0'/'-5'/'abc'/undefined→undefined）
- `HttpKit.test.ets`（新）：trimTrailingSlash（尾斜杠/多斜杠/无斜杠）、buildUrl（尾斜杠剥离 + query 编码）、readApiVersion（数字提取/无数字）、readHeader（命中/缺失）
- `TimeFormat.test.ets`（改）：新增 formatTimeRange（有/无 end、坏 ISO）、padTwo、formatLocalNowHHmm（格式校验）
- `LocalDate.test.ets`（改）：新增 tomorrowLocalIso（与 today 差一天、格式、跨日用例）
- `Timeline.test.ets`（改）：既有 kindLabel 断言全部保持；新增 kindLabelOf 直接断言（含未知回退）

### 需求覆盖对照（FR → 设计落点）

| FR | 落点 |
|---|---|
| FR-001 设备面路径 | AgendaApi 路径常量 |
| FR-002 令牌携带 | HttpKit 请求头构造 + PREF_KEY_TOKEN 沿用 |
| FR-003 agents 预切 | AgentApi 路径 + ChatPage 既有提示 |
| FR-004 配对入口 | SettingsPage 表单 + 校验纯函数 |
| FR-005 兑换与持久化 | PairingApi.redeemPairCode + 三键落盘 |
| FR-006 失败分支 | ApiError.classifyPairFailure + formatWaitSeconds + 无自动重试 |
| FR-007 删手填令牌 | SettingsPage 改版 |
| FR-008 解除配对 | SettingsPage 清三键（D15） |
| FR-009 失效引导 | ApiError TOKEN_HINT 改写（横幅自动继承） |
| FR-010 WS 归类 | WsChat 按 D8 改写 |
| FR-011 死代码 | ChatSession/AppConfig 接口/EVENT_KIND_* /ChatPage 常量/Index 导入 |
| FR-012 样板收敛 | HttpKit + padTwo/formatTimeRange 等共享辅助 |
| FR-013 kind 标签 | kindLabelOf 单点 + EventCard/Timeline 同源 |
| FR-014 版本键常量 | PREF_KEY_API_VERSION |
| FR-015 targetSdkVersion | build-profile.json5 |
| FR-016 提醒死分支 | ReminderService 内部改写（行为不变） |
