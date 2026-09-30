# Plobi Harmony App

> WP-H2-APP-V0 · 独立 git 仓（本机路径 `/Users/ciel/Projects/Plobi/Plobi-Harmony-App`，分支 `master`，**无远端**），与 `Code` 仓解耦。
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

- **本仓源码发的是旧名**：`const HEADER_TOKEN = 'X-Vaelis-Session-Token'`（`entry/src/main/ets/service/WsChat.ets:7`；`WsUrl.ets:5` 同）
- **后端测试用的是新名**：`X-Plobi-Session-Token`（`Code/tests/plobi/test_app_token.py:20` 写明「dedicated `X-Plobi-Session-Token` header **and the legacy** …」，`:403` 断言平板带这个头过 `/api/ws`）

也就是说后端**可能**同时接受两个名字（新名 + legacy），但**我没有读后端解析请求头的那段代码去证实**，所以这里不下结论。
要收口就先定位后端读取点（从 `test_app_token.py` 的 fixture 反查实现），再决定：是 App 换新名、还是后端明确保留 legacy。
**别在核清之前改任何一边**——改错方向会让平板静默 401。

## 工程落点

- 本仓：`/Users/ciel/Projects/Plobi/Plobi-Harmony-App`（独立仓，无远端）
- 与 `Plobi-Desktop/Code/` **完全隔离**——App 不引用 Code 内任何代码
- 桌面侧改动（H1-API-HARDEN：LAN 绑定 / CORS / version header）由 Code 仓负责；本仓只等它们落地
- 历史文档里的 `D:\Projects\vaelis-harmony-app\` 与 `D:\Projects\Vaelis\Code\` 是**那台已报废的 Windows 机**上的路径，2026-09-27 起不可执行

## 当前状态

- **工程可编译**（Stage 模型文件齐：`AppScope/` · `entry/src/main/ets/` · `module.json5` · `build-profile.json5` · `hvigorfile.ts`）
- **未上真机** —— 无 DevEco 真机/模拟器环境；单测可在 DevEco 中跑（`hvigorw test`），但编译与运行**未在此环境验证过**
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
