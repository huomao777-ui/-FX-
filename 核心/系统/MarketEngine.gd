## 描述: 汇率市场引擎，负责加载货币配置并按回合推进 RMB 基准汇率
## 依赖: CurrencyState、MarketMath，可作为 GameDataManager 子节点运行
## 状态: 第一阶段
## 最后更新: 2026-06-12
class_name MarketEngine
extends Node

## ===== 信号 =====

## 单个货币汇率变化后发射，rate 表示 1 RMB 可兑换多少该外币
signal 汇率变动(货币代码: String, 汇率快照: Dictionary)
## 每轮市场推进完成后发射
signal 市场回合完成(总回合: int, 时段索引: int, 汇率列表: Dictionary)
## 每日清晨完成公允价值更新后发射
signal 公允价值更新(日数: int, 汇率列表: Dictionary)
## 配置加载完成后发射
signal 市场配置加载完成(货币数量: int)

## ===== 导出配置变量 =====

@export_group("配置")
## 货币配置 JSON 路径
@export var 货币配置路径: String = "res://资源/数据/市场/currency_config.json"
## 是否在 _ready 时自动加载配置
@export var 自动加载配置: bool = true
## 是否自动连接同级 TimeSystem 的回合推进信号
@export var 自动连接时间系统: bool = true
## 随机种子；0 表示使用随机种子
@export var 随机种子: int = 20260612

@export_group("调试")
## 是否输出关键市场日志
@export var 启用市场日志: bool = true

## ===== 内部变量 =====

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rmb_interest_rate: float = 0.015
var _currency_states: Dictionary = {}
var _currency_order: Array[String] = []
var _total_market_turns: int = 0
var _total_market_days: int = 0

## ===== 生命周期 =====

func _ready() -> void:
	_setup_rng()
	if 自动加载配置:
		加载市场配置()
	if 自动连接时间系统:
		_try_connect_time_system()

## ===== 公共接口：配置与推进 =====

func 加载市场配置(config_path: String = "") -> bool:
	var target_path: String = config_path if not config_path.is_empty() else 货币配置路径
	var file: FileAccess = FileAccess.open(target_path, FileAccess.READ)
	if file == null:
		push_error("MarketEngine: 无法打开货币配置 " + target_path)
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("MarketEngine: 货币配置 JSON 格式错误 " + target_path)
		return false

	var parsed_data: Dictionary = parsed as Dictionary
	_load_from_config(parsed_data)
	市场配置加载完成.emit(_currency_order.size())
	_log_market_state("加载市场配置")
	return true

func 推进市场回合(总回合: int = -1, 时段索引: int = -1, 时段名称: String = "") -> void:
	if _currency_states.is_empty():
		return

	_total_market_turns += 1
	var is_new_day_open: bool = 时段索引 == 0
	if is_new_day_open:
		_total_market_days += 1
		_update_daily_fair_values()

	for code in _currency_order:
		var state: CurrencyState = _currency_states[code]
		MarketMath.update_pressure_and_tsb(state)
		MarketMath.update_emotion(state, _rng.randfn(0.0, 1.0))
		MarketMath.try_extreme_emotion_reversal(state, _rng)
		var delta_data: Dictionary = MarketMath.calculate_turn_rate_delta(state, _rng.randfn(0.0, 1.0))
		state.current_rate = max(state.current_rate + float(delta_data.get("total_delta", 0.0)), 0.000001)
		MarketMath.apply_circuit_breaker(state)
		汇率变动.emit(code, 获取汇率快照(code))

	市场回合完成.emit(总回合 if 总回合 >= 0 else _total_market_turns, 时段索引, 获取全部汇率快照())
	if 启用市场日志:
		print("MarketEngine: 推进市场回合 ", 时段名称, " #", _total_market_turns)

func 模拟市场回合(回合数: int = 20) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	for i in range(max(回合数, 0)):
		推进市场回合(_total_market_turns + 1, i % 5, "模拟")
		samples.append(获取全部汇率快照())
	return samples

## ===== 公共接口：查询 =====

func 获取汇率(货币代码: String) -> float:
	var state: CurrencyState = _currency_states.get(货币代码, null) as CurrencyState
	if state == null:
		return 0.0
	return state.current_rate

func 获取汇率快照(货币代码: String) -> Dictionary:
	var state: CurrencyState = _currency_states.get(货币代码, null) as CurrencyState
	if state == null:
		return {}
	return {
		"code": state.code,
		"display_name": state.display_name,
		"reference_currency": state.reference_currency,
		"rate": state.current_rate,
		"fair_value": state.fair_value,
		"equilibrium_rate": state.equilibrium_rate,
		"emotion": state.emotion,
		"TSB_t": state.structural_trade_bias_smooth,
		"ERP": state.exchange_rate_pressure,
		"effective_volatility": state.effective_volatility,
		"daily_cumulative_change": state.daily_cumulative_change,
		"suspended_today": state.suspended_today,
		"volatility_profile": state.volatility_profile,
		"intervention_tendency": state.intervention_tendency
	}

func 获取全部汇率快照() -> Dictionary:
	var result: Dictionary = {}
	for code in _currency_order:
		result[code] = 获取汇率快照(code)
	return result

func 获取货币代码列表() -> Array[String]:
	return _currency_order.duplicate()

func 获取人民币利率() -> float:
	return _rmb_interest_rate

## ===== 存档接口 =====

func 收集存档数据() -> Dictionary:
	var states: Dictionary = {}
	for code in _currency_order:
		var state: CurrencyState = _currency_states[code]
		states[code] = state.collect_save_data()
	return {
		"total_market_turns": _total_market_turns,
		"total_market_days": _total_market_days,
		"rmb_interest_rate": _rmb_interest_rate,
		"states": states
	}

func 恢复存档数据(data: Dictionary) -> void:
	if data.is_empty():
		return
	_total_market_turns = max(int(data.get("total_market_turns", _total_market_turns)), 0)
	_total_market_days = max(int(data.get("total_market_days", _total_market_days)), 0)
	_rmb_interest_rate = float(data.get("rmb_interest_rate", _rmb_interest_rate))
	var states: Dictionary = data.get("states", {})
	for code in states.keys():
		var state: CurrencyState = _currency_states.get(str(code), null) as CurrencyState
		if state != null:
			state.restore_save_data(states[code])

## ===== 私有方法 =====

func _setup_rng() -> void:
	if 随机种子 == 0:
		_rng.randomize()
	else:
		_rng.seed = 随机种子

func _load_from_config(config: Dictionary) -> void:
	_currency_states.clear()
	_currency_order.clear()

	var base_currency: Dictionary = config.get("base_currency", {})
	_rmb_interest_rate = float(base_currency.get("interest_rate", _rmb_interest_rate))

	var currency_configs: Array = config.get("currencies", []) as Array
	for item in currency_configs:
		if not (item is Dictionary):
			continue
		var item_data: Dictionary = item as Dictionary
		var state: CurrencyState = CurrencyState.from_config(item_data, _rmb_interest_rate)
		if state.code.is_empty():
			continue
		_currency_states[state.code] = state
		_currency_order.append(state.code)

func _try_connect_time_system() -> void:
	var time_system: Node = get_node_or_null("../TimeSystem")
	if time_system == null:
		return
	if time_system.has_signal("回合推进") and not time_system.回合推进.is_connected(_on_time_system_turn_advanced):
		time_system.回合推进.connect(_on_time_system_turn_advanced)

func _on_time_system_turn_advanced(总回合: int, 时段索引: int, 时段名称: String) -> void:
	推进市场回合(总回合, 时段索引, 时段名称)

func _update_daily_fair_values() -> void:
	for code in _currency_order:
		var state: CurrencyState = _currency_states[code]
		state.begin_new_day()
		MarketMath.update_pressure_and_tsb(state)
		MarketMath.update_fair_value(state, _rng.randfn(0.0, 1.0))
		MarketMath.update_equilibrium_rate_if_needed(state, _total_market_days)
	公允价值更新.emit(_total_market_days, 获取全部汇率快照())

func _log_market_state(reason: String) -> void:
	if not 启用市场日志:
		return
	print("MarketEngine: ", reason, " | 货币数量=", _currency_order.size(), " | RMB利率=", _rmb_interest_rate)
