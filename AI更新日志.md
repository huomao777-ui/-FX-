# AI更新日志

## 说明

- 本文件用于记录 AI 代理对项目所做的实际代码、场景、配置、规范修改。
- 记录位置固定在项目根目录，后续每次完成一轮有效更新后追加新条目。
- 记录目标是帮助快速回看“改了什么、为什么改、影响到哪里”，不代替 git 提交历史。
- 每条更新建议同时写明一个可直接使用的 git 提交名，以及一个递增版本号，方便在不能即时提交 git 时先保留稳定命名。

## v0.2.0 2026-06-25 减仓/补仓/一键平仓弹窗实现

### 建议 Git 提交名

- `feat: 实现减仓弹窗、补仓弹窗、一键平仓弹窗控制器与按钮连接`

### 本轮更新范围

- `界面/场景/外汇应用/FxReducePositionPanelController.gd` **(新增)**
- `界面/场景/外汇应用/FxAddPositionPanelController.gd` **(新增)**
- `界面/场景/外汇应用/FxCloseAllPanelController.gd` **(新增)**
- `界面/场景/外汇应用/FxDomesticAppRootController.gd`
- `界面/场景/外汇应用/FxCurrencyPanelController.gd`
- `界面/场景/外汇应用/国内炒汇.tscn`

### 主要修改

- 新增三个弹窗控制器脚本，遵循外汇应用编码风格规范（中文公开方法、snake_case私有方法、类型标注、字典安全访问、信号通信）。
- **FxReducePositionPanelController**（减仓弹窗）：显示当前持仓信息/浮动盈亏/开仓价现价/杠杆，通过滑块选择减仓手数，实时计算预计回收保证金、剩余仓位、强平线变化。发射 `reduce_confirmed` 信号。
- **FxAddPositionPanelController**（补仓弹窗）：类似布局，显示新增保证金、补仓后总仓位、点差率/点差成本、强平线变化。发射 `add_confirmed` 信号。
- **FxCloseAllPanelController**（一键平仓弹窗）：显示仓位概览、预估盈亏（含点差+滑点成本）、预计成交价、释放保证金。发射 `close_all_confirmed` 信号。
- **FxDomesticAppRootController** 扩展：从轻量主控升级为跨模块调度器——缓存三个弹窗和货币面板控制器引用；连接下方按钮的 pressed 事件到对应弹窗；连接弹窗确认信号到货币面板控制器的回调。
- **FxCurrencyPanelController** 新增三个中文公开方法：`处理减仓`（更新手数/保证金）、`处理补仓`（合并新开仓）、`处理一键平仓`（清除持仓标记）。
- 弹窗数据来源：优先从 TradingSystem/MarketEngine 获取实时行情和账户数据，回退到slot的mock数据；合约参数从 `trading_config.json` 读取。

### 已知说明

- 当前减仓/补仓/一键平仓为 UI 模拟层操作，后续接入真实的 TradingSystem 开/平仓 API 后只需替换 FxCurrencyPanelController 中的处理函数。
- `FxCloseAllPanelController` 中的平仓点差成本计算遵循 `trading_config.json` 中 platform.spread_rate + base_slippage_rate 的配置。
- 当槽位 mock_lots <= 0 时，三个按钮均被保护性拦截（push_warning），不打开弹窗。

## v0.2.1 2026-07-14 项目专属 skill 与流程回灌
### 建议 Git 提交名
- `chore: 建立项目专属 skill 并固化场景安全、日志与 Git 流程`

### 本轮更新范围
- `.codex/skills/new-century-fx-warrior/SKILL.md` **(新增)**
- `.codex/skills/new-century-fx-warrior/references/scene-safety.md` **(新增)**
- `.codex/skills/new-century-fx-warrior/references/ui-architecture.md` **(新增)**
- `.codex/skills/new-century-fx-warrior/references/project-layout.md` **(新增)**
- `.codex/skills/new-century-fx-warrior/references/git-workflow.md` **(新增)**
- `.codex/skills/new-century-fx-warrior/references/continuous-improvement.md` **(新增)**
- `AI更新日志.md`

### 主要修改
- 建立项目专属 skill，统一收束根目录中的 Godot 场景修改规范、UI 节点解耦规范、项目结构说明与 Git 流程约束。
- 将 `scene-resource / ui-script / repo-structure / git-publish / error-followup` 五类任务显式分类，要求先按任务类型加载对应 reference。
- 把 Godot 文本资源的高风险规则固化为硬约束：禁止整文件重写 `.tscn`，禁止在乱码终端输出上继续补丁，出现解析错误后必须立即进入 recovery mode。
- 新增 continuous-improvement reference，要求每次用户反馈报错或流程失误后，都要把可复用的经验回灌进 skill，避免重复犯错。
- 将 `AI更新日志.md` 的实时更新和“稳定小步优先 Git 提交/推送”写成默认流程，而不是可选建议。

### 已知说明
- 本轮先落 skill 与日志规则，没有继续扩散修改高风险场景文件。
- Git 尚未在本轮执行提交或推送；后续在仓库恢复到稳定状态后，应按 skill 中的节奏尽快做小步提交。

- 补充规则：编程任务默认按“确认需求 -> 实现思路 -> 验证方式 -> 是否需要 Git -> Git 是否成功”这一顺序沟通；非编程任务不强制套用同样结构。
