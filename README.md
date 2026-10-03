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

1. **配对**：首启填桌面 LAN 地址 + 会话令牌，入 Preferences；冷启动自动用
2. **清单**：今日 / 明日 / 待确认 三段；`HH:MM–HH:MM 标题`，`end_at` 空只显示开始并标「未写结束」
3. **批待确认**：点「确认 / 忽略」→ 调 `POST /api/agenda/{id}/{confirm|dismiss}`
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

## 公开 API（消费）

| Method | Path | 说明 |
|---|---|---|
| GET | `/api/agenda?from=&to=` | 已确认事件 + 待确认事件 |
| GET | `/api/agenda/pending` | 仅待确认 |
| POST | `/api/agenda/{id}/confirm` | 确认 |
| POST | `/api/agenda/{id}/dismiss` | 忽略（响应可能 `{deleted:true}`） |

契约真源：[Docs/specs/api.md](../Plobi-Desktop/Docs/specs/api.md)。**App 走桌面同一套公开 API，不另开私口**（裁定 28.2）。

### ⚠️ 请求头名字两边不一致（待核，别照抄任何一边）

- **后端只读新名，没有旧名兼容路径**（2026-10-03 读了实现，不再是推测）：
  `Code/plobi_cli/web_server.py:298` 定 `_SESSION_HEADER_NAME = "X-Plobi-Session-Token"`，`:554` 取这一个头，
  `:561` 兜 `Authorization: Bearer <token>`；`X-Vaelis-*` 在 Code 非测试代码里 **0 处**。
- **LAN 模式下必然拦截**：`should_require_auth` 对非 loopback 一律 True，`--insecure` 已不再放行；
  网关只有一条 `if not _has_valid_session_token(request): raise 401`（`web_server.py:607`）。
  平板只能走 LAN，所以本仓改之前**每个 `/api/agenda*`、`/api/agents`、`/api/ws` 请求都是 401**。
- **方向是改 App**：后端是新契约（`Code/tests/plobi/test_app_token.py:403` 断言平板带新名过 `/api/ws`），
  桌面 `apps/desktop/electron/main.ts:3880` 也发新名。本仓已随 **WP-APP-TOKEN**（commit `092d650`）改成
  `X-Plobi-Session-Token`，并一并修了同样错的 `X-Vaelis-Api-Version` → `X-Plobi-Api-Version`
  （后端名见 `web_server.py:330`）。
- **仍未验的那一半**：401 是否真消失要**装上设备才知道**——见下面「当前状态」，HAP 还没出过货。

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
- **仍未上真机**：设备上跑起来、以及「401 是否真消失」都还没验过——这一条不许因为"编译通过"就升级。
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
