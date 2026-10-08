# Plobi Harmony App

> WP-H2-APP-V0 · 独立 git 仓（Mac `/Users/ciel/Projects/Plobi/Plobi-Harmony-App`、Windows
> `D:\Projects\Plobi\Plobi-Harmony-App` 各一份；分支 **`main`**，2026-10-03 实测，旧文档写的 `master` 已过时；
> ~~`git remote -v` 为空 = 无远端~~ **2026-10-06 实测：本仓有远端 `origin` = `github.com/deyu-deng/Plobi-Harmony-App.git`，`main` 跟踪 `origin/main`，且有两次 `update by push` 记录（10-03 / 10-04）**——「无远端」与「只 commit 不 push」两句都已不是事实，是否继续推由用户定（`Docs/DECISIONS.md` §4 #15）。与 `Code` 仓解耦。两机真源口径未定（裁定 52.7）。
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

> ✅ **2026-10-07 WP-APP-HANDSET 落地（DevEcode 实现 + Qoder 只读复核）：设备面切换与配对链路已进代码，但一次也没在设备上跑通过。**
> 做到的：请求路径整体换到 `/api/handset/*`；`SettingsPage` 从手填钥匙改成 6 位码配对（`PairingApi`）；
> 令牌头收敛到 `HttpKit.ets:11` 全仓单点；鉴权失败与 WS 握手失败统一引导「重新配对」。
> 与后端源码逐条对上：`POST /api/handset/pair/redeem` 的 body `{code, deviceName}` 与响应
> `{deviceId, token, scopes}`、401/429+`Retry-After` 见 `Code/plobi_cli/dashboard_auth/pairing_api.py:54-128`；
> 免凭证白名单见 `public_paths.py:65`；头名见 `headers.py:13`；设备令牌认的路由清单见 `pairing.py:66-86`。
> **没做到的（都不许当成已完成）**：① 配对→拉清单→批一条**从未真机走过**——2026-10-07 本机实测后端 8787
> 无人监听、`devices.json = {}`、`PLOBI_LAN` 默认关，这条链路客观上还没被验证过；② 工程里**没有可执行的测试入口**
> （`entry/src/test/` 缺 `List.test.ets` 聚合，`entry/src/ohosTest/` 是空目录，构建日志明写
> `not found resModel json file in .../ohosTest/module.json5`），所以 `entry/src/test/` 下 10 个测试文件
> **一次都没跑过**，只被静态检查扫到；③ WS 握手能否带自定义头仍未实测。
> ④ `/api/handset/agents` 是**本仓自取的路径**——后端 `pairing.py:66-86` 里没注册、全仓 grep 0 命中，
> 桌面补这个口之前聊天拉列表必然失败（已按用户裁定保留预切，并在 `Docs/specs/handset-app.md` §8 向桌面侧立案）。
> 另两条仍待核：WS 正文字段名、提醒 `triggerTimeInSeconds` 的单位。


1. **配对**（2026-10-07 已实现，**真机未验**）：首启填桌面 LAN 地址；**钥匙不再手填**——桌面点「新码」出 6 位数字，App 一次
   `POST /api/handset/pair/redeem` 换回**本机专属令牌**，入 Preferences，冷启动自动用
   （2026-10-05 裁定 64 改了这一块，见下面「请求头与钥匙」）
2. **清单**：今日 / 明日 / 待确认 三段；`HH:MM–HH:MM 标题`，`end_at` 空只显示开始并标「未写结束」
3. **批待确认**：点「确认 / 忽略」→ 调 `POST /api/handset/agenda/{id}/{confirm|dismiss}`（路径已于 2026-10-07 换到设备面）
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

## 公开 API（消费）——**本表 2026-10-07 起与代码一致**

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
`/api/handset/agenda`。**本仓代码从 2026-10-07 起打的才是这个前缀**（`WP-APP-HANDSET` 第一刀）——
在此之前它一直打 `/api/agenda*`，在局域网绑定上必然 401。

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
- 聊天那一格还欠一个桌面侧的口子：拿 `sessionId` 要用的 agents 列表，桌面**至今没开设备面口**（交接规格 §8）。
  2026-10-07 起本仓按用户裁定**预切到 `/api/handset/agents`**——这个名字是本仓自取的，后端
  `pairing.py:66-86` 的设备令牌路由里没有它、全仓 grep 也是 0 命中，所以桌面照此实现之前**这一条必然失败**
  （ChatPage 显示既有的「拉取总秘书列表失败，请检查桌面」）。

## 工程落点

- 本仓在两台上各有一份副本：Mac `/Users/ciel/Projects/Plobi/Plobi-Harmony-App`、Windows `D:\Projects\Plobi\Plobi-Harmony-App`。
  **当前分支是 `main`**（本 README 顶部与 `Docs/README.md` 原先写的 `master` 已不符，2026-10-03 实测）。
  两机真源口径未定（裁定 52.7），改之前先问在哪台写。
- 与 `Plobi-Desktop/Code/` **完全隔离**——App 不引用 Code 内任何代码
- 桌面侧改动（H1-API-HARDEN：LAN 绑定 / CORS / version header）由 Code 仓负责；本仓只等它们落地
- 历史文档里的 `D:\Projects\vaelis-harmony-app\` 与 `D:\Projects\Vaelis\Code\` 是**那台已报废的 Windows 机**上的路径，2026-09-27 起不可执行

## 当前状态

- **出包链路通了**（2026-10-07）：`hvigor assembleHap` 全绿，`:entry:default@PackageHap` 不再报
  **`spawn java ENOENT`**，产物落在 `entry/build/default/outputs/default/`（`entry-default.hap` /
  `entry-default-unsigned.hap`）与 `build/outputs/default/Plobi-Harmony-App-default-unsigned.app`。
  Qoder 用文档里那条命令行**干净重跑过一次**（`--no-daemon`，1min59s，33 任务）确认不是 IDE 独享的现象。
  **根因没查清**——本 WP 的代码改动里没有任何 java 相关配置，所以这条只能记成「不再复现」，不能记成「已解决」；
  原先那条「下一步该查 hvigor 怎么找 java」的待办**撤掉**。
- **包还不能装**：`build-profile.json5:3` 是 `"signingConfigs": []`，构建日志明写
  `WARN: Will skip sign 'hos_hap'. No signingConfigs profile is configured`——unsigned HAP 装不上真机，
  这一步需要开发者证书/自动签名，**不在本 WP 范围**。
- **仍未上真机，一次也没有**：设备上跑起来还没验过——这一条不许因为"编译通过"或"代码已对齐契约"就升级。
  401 的根因早在桌面那侧修掉并实测过（2026-10-04，真实局域网绑定上带钥匙读清单/day/pending = 200；
  见 `Docs/specs/handset-app.md`），**设备侧那三件事已就位但没有一件被真机验证**：
  ① 请求换到 `/api/handset/agenda*`；② 配对界面换设备令牌（裁定 68 之后这是进门唯一通道）；③ 出包。
  **现在挡在验收前面的两格**：桌面后端得开 LAN 绑定（2026-10-07 本机实测 `PLOBI_LAN` 未开、8787 无人监听、
  `devices.json = {}`），以及上面那条签名。
- **测试没有可执行的入口**：`entry/src/test/` 下十个 `.test.ets` 都只写了 `export default function xxxTest()`，
  **缺聚合用的 `List.test.ets`**；`entry/src/ohosTest/` 是空目录（构建日志：`not found resModel json file in
  .../ohosTest/module.json5`），`entry/build-profile.json5` 也只声明了 `default` 与 `ohosTest` 两个 target。
  所以「单测全绿」这句**从来没有证据**，新加的用例也一样没跑过——补这一格要在能真机/模拟器执行的前提下来，
  别只把一个跑不通的聚合文件签进去当作完成。
- 本机命令入口（这套路径只在 `Cycle` 上成立）：
  `node "D:\Software\DevEco Studio\tools\hvigor\bin\hvigorw.js" assembleHap --mode module -p product=default`，
  环境变量 `DEVECO_SDK_HOME=D:\Software\DevEco Studio\sdk`。
- 以上各条已登记进 Docs（`Docs` `2e98b5a`，按裁定 73 只取自己的行）：`PROGRESS.md` 表尾一行、
  `ROADMAP.md` §1.2 鸿蒙构建那一行与 §4 的 `WP-APP-HANDSET` 那一行、`specs/handset-app.md` §6 与 §8；
  本仓的认领登记在 `Docs/reference/agent-register.md`。**别把这份 README 当成已验收**——Wave H 未合①还压着
  签名与 `PLOBI_LAN` 两格

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
