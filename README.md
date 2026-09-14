# Vaelis HarmonyOS App

> WP-H2-APP-V0 · 独立仓 `vaelis-harmony-app`，与 Code 仓解耦。
> 鸿蒙 NEXT 平板：今日/明日清单 + 课前提醒 + 批待确认。

## 这是什么

ArkTS Stage 模型工程，对应 Vaelis 系统的**手机面**（[`Docs/GRILL_FREEZE.md`](../Vaelis/Docs/GRILL_FREEZE.md) 人机面 · 终极手机）。

> 调研见 [`Docs/RESEARCH-HARMONY-APP.md`](../Vaelis/Docs/RESEARCH-HARMONY-APP.md)。
> 任务书见 [`Docs/AGENT-TASK-H2-APP-V0.md`](../Vaelis/Docs/AGENT-TASK-H2-APP-V0.md)。

## 能力（H2 切片）

1. **配对**：首启填桌面 LAN 地址 + `X-Vaelis-Session-Token`，入 Preferences；冷启动自动用
2. **清单**：今日 / 明日 / 待确认 三段；`HH:MM–HH:MM 标题`，`end_at` 空只显示开始并标「未写结束」
3. **批待确认**：点「确认 / 忽略」→ 调 `POST /api/agenda/{id}/{confirm|dismiss}`
4. **本地提醒**：每次同步后重排，触发 = `start_at − 15min`，上限 30 条/包（系统限制 1700002）
5. **离线**：先渲染缓存 + 标「上次同步 HH:MM」；桌面关闭不白屏
6. **冷启动 < 3s**：先 cache 后 network
7. **权限**：`INTERNET` / `PUBLISH_AGENT_REMINDER` / `NOTIFICATION_CONTROLLER`
8. **测试**：纯逻辑单测跑在 `entry/src/test/`

## 栈

- ArkTS Stage 模型（API 12+）
- `@ohos.reminderAgentManager` ← 官方后台代理提醒（H0 调研时写作 `backgroundReminderManager`，**官方包名是 `reminderAgentManager`**，本仓库用官方命名）
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

头：`X-Vaelis-Session-Token: <token>`（token 不写日志、不进 URL）。

详见 `Docs/API.md`（Code 仓）—— App 不另开私口（裁定 28.2）。

## 工程落点

- 独立仓 `vaelis-harmony-app`（本目录）
- 与 `D:\Projects\Vaelis\Code\` 完全隔离——App 不引用 Code 内任何代码
- 桌面侧改动（H1-API-HARDEN）由 Code 仓 Agent 负责；本仓库只等 LAN/CORS/version header 落地

## 当前状态

- **工程可编译**（Stage 模型文件齐：`AppScope/` · `entry/src/main/ets/` · `module.json5` · `build-profile.json5` · `hvigorfile.ts`）
- **未上真机** —— 本会话无 DevEco 真机/模拟器；单测可在 DevEco 中跑（`hvigorw test`），但未在此环境验证编译与运行
- PROGRESS 已写清「工程可编译 / 未上真机」（任务书 §8）

## 怎么用 DevEco 打开

```
1. DevEco Studio → Open → 选 D:\Projects\vaelis-harmony-app\
2. 等 ohpm 装依赖
3. 配置签名（自动签名 or 自备 .p12）
4. 真机/模拟器：选 ≥ API 12 的设备
5. Run EntryAbility
```

## 目录结构

```
vaelis-harmony-app/
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
│       │   │   ├── service/        # Cache, AgendaApi, ReminderService
│       │   │   ├── utils/          # TimeFormat, ReminderCalculator
│       │   │   ├── components/     # EventCard
│       │   │   └── pages/          # Index, SettingsPage
│       │   └── resources/base/...
│       ├── test/                   # 纯逻辑单测
│       └── mock/                   # （空，待后续）
├── build-profile.json5
├── hvigorfile.ts
├── oh-package.json5
└── package.json
```

## 与 Vaelis 其它仓库的关系

| 仓库 | 角色 |
|---|---|
| `D:\Projects\Vaelis\Code\` | 桌面后端 / Electron / Python，本仓库不引用 |
| `D:\Projects\Vaelis\Docs\` | 契约真源 + 任务书 + 调研 |
| `D:\Projects\vaelis-harmony-app\` | **本仓库**——鸿蒙 App |
