# Plobi Harmony App

> WP-H2-APP-V0 · 独立 git 仓（Mac `/Users/ciel/Projects/Plobi/Plobi-Harmony-App`、Windows
> `D:\Projects\Plobi\Plobi-Harmony-App` 各一份；分支 **`main`**，2026-10-03 实测，旧文档写的 `master` 已过时；
> `git remote -v` 为空 = **无远端**），与 `Code` 仓解耦。两机真源口径未定（裁定 52.7）。
> 鸿蒙 NEXT 平板：今日/明日清单 + 课前提醒 + 批待确认。
>
> **命名注**：本仓目录名与仓内标识在 R-038 全面改名（2026-09-26 起）之后才统一成 Plobi，
> 早期文档与源码里仍写作 `vaelis-harmony-app` / `X-Vaelis-Session-Token`——那是**旧名 Vaelis**（产品旧名，非上游）。
> 本 README 只描述现役事实，见到旧名一律标注出处，不冒充新名。

## 这是什么

ArkTS Stage 模型工程，对应 Plobi 系统的**手机面**：
[Docs/SPEC-FINAL.md](../Plobi-Desktop/Docs/SPEC-FINAL.md) 的「人机面 · 终极手机」段（独立 App、鸿蒙优先、看板/批准/指令/预览/本地提醒、**不接管鼠标**）。

> 调研见 [Docs/reference/harmony-app.md](../Plobi-Desktop/Docs/reference/harmony-app.md)（H0 交付物）。
> 排期与关门条件见 [Docs/ROADMAP.md](../Plobi-Desktop/Docs/ROADMAP.md) §4 Wave H。
> ~~任务书 `AGENT-TASK-H2-APP-V0.md`~~ 已按文档纪律在验收后删除（一次性耗材），结论在 `Docs/PROGRESS.md`。

## 能力（H2 切片）

1. **配对**：首启填桌面 LAN 地址；**钥匙不再手填**——桌面点「新码」出 6 位数字，App 一次
   `POST /api/handset/pair/redeem` 换回**本机专属令牌**，入 Preferences，冷启动自动用
   （2026-10-05 裁定 64 改了这一块，见下面「请求头与钥匙」）
2. **清单**：今日 / 明日 / 待确认 三段；`HH:MM–HH:MM 标题`，`end_at` 空只显示开始并标「未写结束」
3. **批待确认**：点「确认 / 忽略」→ 调 `POST /api/handset/agenda/{id}/{confirm|dismiss}`
4. **本地提醒**：每次同步后重排，触发 = `start_at − 15min`，上限 30 条/包（系统限制 1700002）
5. **离线**：先渲染缓存 + 标「上次同步 HH:MM」；桌面关闭不白屏
6. **冷启动 < 3s**：先 cache 后 network
7. **权限**：`INTERNET` / `PUBLISH_AGENT_REMINDER` / `NOTIFICATION_CONTROLLER`
8. **测试**：纯逻辑单测跑在 `entry/src/test/`

## 栈

- ArkTS Stage 模型（API 12+）
- `@ohos.reminderAgentManager` ← 官方后台代理提醒（H0 调研时写作 `backgroundReminderManager`，**官方包名是 `reminderAgentManager`**，本仓用官方命名）
- `@ohos.notificationManager`
- `@ohos.net.http`
- `@ohos.data.preferences`
- 拒 RN / Flutter / Compose / WebView 壳

## 公开 API（消费）——**本表已于 2026-10-04 过期，照下面这份改**

契约真源只有一份：[Docs/specs/handset-app.md](../Plobi-Desktop/Docs/specs/handset-app.md)
（手机侧交接规格）与 [Docs/specs/api.md](../Plobi-Desktop/Docs/specs/api.md)「Plobi App / 设备面」。

| Method | Path | 说明 |
|---|---|---|
| GET | `/api/handset/agenda?from=&to=` | 已确认事件 + 待确认事件 |
| GET | `/api/handset/agenda/pending` | 仅待确认 |
| GET | `/api/handset/agenda/day?date=` | 一天快照（含冲突、避让时段） |
| POST | `/api/handset/agenda/{id}/confirm` | 确认 |
| POST | `/api/handset/agenda/{id}/dismiss` | 忽略（响应可能 `{deleted:true}`） |

**为什么多了 `/api/handset` 这一段**（裁定 57）：桌面把一条 URL 注册成"钥匙认证"之后，
那条 URL 就**只认设备钥匙**、浏览器登录态反被挡在外面；而 `/api/agenda` 是桌面看板
每分钟都在调的。所以同一份 handler 挂两个门牌：浏览器留 `/api/agenda`，设备走
`/api/handset/agenda`。**本仓现有代码还在打 `/api/agenda*`，在局域网绑定上必然 401**——
这就是交接规格里的 `WP-APP-HANDSET`（第一刀）。

### 请求头与钥匙（这段已由实测替换，旧结论作废）

- ~~本仓改之前每个请求都是 401，改头名之后待验~~ → **2026-10-04 实测**：只改头名**不通**。
  非本机绑定时判断权在 cookie/session 网关手里，而**唯一认 app_token 的那段代码在这条路上
  不被调用**（当时 `WP-APP-TOKEN` 那一刀因此只算"改对了名字"）。真正的修法是桌面侧把设备路由
  注册进现成的 token-auth 门缝，即上面那个前缀。
- ~~头：`Authorization: Bearer <app_token>` 或 `X-Plobi-Session-Token: <app_token>` 两种都收
  （现仓发的 `X-Plobi-Session-Token` 仍然有效，**不用改头名，只改路径**）~~
  **2026-10-05 纠正（裁定 64）：头名照旧，但里面放的东西换了。**设备面现在只认**这台设备配对换来的
  令牌**，`app_token` 打 `/api/handset/*` 一律 401（有测试钉住）。**同日裁定 68 更进一步：`app_token`
  已整体退役**（mint、读盘、loopback HTTP 那一跳、WS 升级那一跳全删，`doctor --print-app-token` 也没了），
  所以它**任何面都不认**——没配对过的设备连不上，**没有回退路**，配对界面是进门唯一通道。
  所以本仓要做的是**三件事**，
  不是原来说的两件：① 路径 `/api/agenda*` → `/api/handset/agenda*`；② **加一个配对界面**
  （桌面开码 → 用户敲 6 位 → 存返回的 `token`）；③ 之后每个请求把 `token` 放头里
  （`X-Plobi-Session-Token: <设备令牌>` 或 `Authorization: Bearer <设备令牌>`，两种都收）。
- **配对这一趟的契约**（详细版在交接规格 §2，那才是真源）：
  `POST /api/handset/pair/redeem`，body `{"code": "123456", "deviceName": "客厅平板"}` →
  `200 {"deviceId", "token", "scopes"}`。这是设备面**唯一免凭证**的一次调用。码 **5 分钟有效、只能用一次**；
  **令牌只在这次响应里出现**，桌面不存明文，所以拿到就得存好——丢了没有"找回"，只能回桌面重新配一次。
  错误分支要分开提示用户：**401** = 码错/过期/用过（让用户回桌面重开一个码），
  **429 + `Retry-After`** = 连错 5 次、配对锁 1 小时（这段时间**别自动重试**，照 `Retry-After` 提示）。
  `deviceName` 最长 64 字，建议给一个用户看得懂的名字（"客厅平板"），桌面列表就显示它。
- 版本头：响应带 `X-Plobi-Api-Version: 1`；主版本对不上就提示"请升级桌面"，别硬解字段。
- 钥匙打不开写口：`POST /api/handset/agenda`（往看板加一条）与 `PATCH/DELETE` 一律 401——
  这是设计，不是 bug。拿设备钥匙打 `/api/agenda*` 也是 401；反过来**浏览器登录态也进不了
  `/api/handset/*`**（那个前缀是设备专用的，裁定 64.4）。
- WS `ws://<LAN-IP>:8787/api/ws`：**带设备令牌的升级请求能过认证**（桌面侧实测到 `_ws_auth_reason`
  这一层，真机那一跳还没打，走的是同一条分支），无/错的被 **HTTP 403** 拒（旧文档写的"拒绝码 4401"
  不成立）。桌面撤销一台设备之后，它**下一次握手就进不来**。**待真机确认**：
  `@ohos.net.webSocket` 握手能不能带自定义头。
- 聊天那一格还欠一个桌面侧的口子：拿 `sessionId` 要用的 `/api/agents` 现在钥匙打不开（见交接规格 §8）。

## 工程落点

- 本仓在两台上各有一份副本：Mac `/Users/ciel/Projects/Plobi/Plobi-Harmony-App`、Windows `D:\Projects\Plobi\Plobi-Harmony-App`。
  **当前分支是 `main`**（本 README 顶部与 `Docs/README.md` 原先写的 `master` 已不符，2026-10-03 实测）。
  两机真源口径未定（裁定 52.7），改之前先问在哪台写。
- 与 `Plobi-Desktop/Code/` **完全隔离**——App 不引用 Code 内任何代码
- 桌面侧改动（H1-API-HARDEN：LAN 绑定 / CORS / version header）由 Code 仓负责；本仓只等它们落地
- 历史文档里的 `D:\Projects\vaelis-harmony-app\` 与 `D:\Projects\Vaelis\Code\` 是**那台已报废的 Windows 机**上的路径，2026-09-27 起不可执行

## 当前状态

- **ArkTS 编译已真跑通一次**（2026-10-03，Windows 机 `Cycle`，DevEco Studio 26.0 自带工具链）：
  `ohpm install --all` 成功 → `hvigor assembleHap` 的 **`CompileArkTS` 通过（23.4s）**。
- **但 HAP 还没出过货**：同一个构建停在 `:entry:default@PackageHap`，报 **`spawn java ENOENT`**。
  已排除"PATH 没设好"——把 DevEco 自带 jbr（OpenJDK 25.0.2）加进 PATH 后 `where java` /
  `java -version` / node `spawnSync('java')` 全部成功，hvigor 自己的 java daemon 仍报同一句。
  **下一步该查的是 hvigor 怎么找 java**（或直接在 DevEco GUI 里构建），不是再折腾 PATH。
- **仍未上真机**：设备上跑起来还没验过——这一条不许因为"编译通过"就升级。**但 401 的根因已在桌面这一边修掉并实测**（2026-10-04，真实局域网绑定上带钥匙读清单/day/pending = 200；见 `Docs/specs/handset-app.md`）。**设备侧还差三件事**：① 把请求从 `/api/agenda*` 换到 `/api/handset/agenda*`（`WP-APP-HANDSET`，不换必 401）；② **加配对界面**换设备令牌（裁定 64 之后 `app_token` 打不开设备面，**裁定 68 之后它哪儿都不认——这一格是进门唯一通道**，见上）；③ 出包（停在 `PackageHap` 那条）。
- 本机命令入口（这套路径只在 `Cycle` 上成立）：
  `node "D:\Software\DevEco Studio\tools\hvigor\bin\hvigorw.js" assembleHap --mode module -p product=default`，
  环境变量 `DEVECO_SDK_HOME=D:\Software\DevEco Studio\sdk`。
- 以上两条 `Docs/PROGRESS.md` 有对应流水，勿在本 README 里升级成「已验收」

## 怎么用 DevEco 打开

```
1. DevEco Studio → Open → 选 /Users/ciel/Projects/Plobi/Plobi-Harmony-App
2. 等 ohpm 装依赖
3. 配置签名（自动签名 or 自备 .p12）
4. 真机/模拟器：选 ≥ API 12 的设备
5. Run EntryAbility
```

## 目录结构

```
Plobi-Harmony-App/
├── AppScope/                       # 应用级配置
│   ├── app.json5
│   └── resources/base/element/string.json
├── entry/                          # 主模块（Stage）
│   ├── build-profile.json5
│   ├── hvigorfile.ts
│   ├── oh-package.json5
│   └── src/
│       ├── main/
│       │   ├── module.json5        # 权限 + UIAbility + 路由
│       │   ├── ets/
│       │   │   ├── entryability/EntryAbility.ets
│       │   │   ├── model/          # AgendaEvent, AppConfig
│       │   │   ├── service/        # Cache, AgendaApi, ReminderService, WsChat, WsUrl
│       │   │   ├── utils/          # TimeFormat, ReminderCalculator
│       │   │   ├── components/     # EventCard
│       │   │   └── pages/          # Index, SettingsPage, ChatPage
│       │   └── resources/base/...
│       ├── test/                   # 纯逻辑单测
│       └── mock/                   # （空，待后续）
├── build-profile.json5
├── hvigorfile.ts
├── oh-package.json5
└── package.json
```

## 与 Plobi 其它仓库的关系

| 仓库 | 角色 |
|---|---|
| `Plobi-Desktop/Code/` | 桌面后端 / Electron / Python（分支 `main`，远端名 `github`）。本仓不引用它 |
| `Plobi-Desktop/Docs/` | 需求 / 契约 / 排期 / 裁定 / 调研真源（独立仓，**无远端**）。索引 = `Docs/README.md` |
| `Plobi-Harmony-App/` | **本仓**——鸿蒙 App |
