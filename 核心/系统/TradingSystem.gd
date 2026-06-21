## 描述: 外汇交易系统，管理开仓、平仓、保证金、强平和基础负债
## 依赖: 同级 MarketEngine 提供 XMY 基准汇率
## 状态: 第一阶段
## 最后更新: 2026-06-12
class_name TradingSystem
extends Node

## ===== 信号 =====

signal 持仓开启(持仓快照: Dictionary)
signal 持仓关闭(平仓结果: Dictionary)
signal 账户变化(账户快照: Dictionary)
signal 保证金警告(警告等级: String, 保证金比例: float)
signal 强制平仓(原因: String, 平仓结果: Dictionary)

## ===== 导出配置变量 =====

@export_group("配置")
## 交易配置 JSON 路径
@export var 交易配置路径: String = "res://资源/数据/交易/trading_config.json"
## 是否在 _ready 时自动加载交易配置
@export var 自动加载配置: bool = true
## 开局交易账户现金
@export var 初始现金: float = 10000.0

@export_group("调试")
## 是否输出交易日志
@export var 启用交易日志: bool = true

## ===== 内部变量 =====

var _market_engine: MarketEngine = null
var _positions: Array[TradePosition] = []
var _platform_rules: Dictionary = {}
var _contract_rules: Dictionary = {}
var _margin_rules: Dictionary = {}
var _debt_rules: Dictionary = {}
var _cash_balance: float = 10000.0
var _debt: float = 0.0
var _highest_equity: float = 10000.0
var _next_position_id: int = 1
var _current_turn: int = 0
var _debt_interest_pause_days_left: int = 0

## ===== 生命周期 =====

func _ready() -> void:
	_cash_balance = 初始现金
	_highest_equity = 初始现金
	if 自动加载配置:
		加载交易配置()
	_try_connect_market_engine()
	_try_connect_time_system()
	_emit_account_changed()

## ===== 公共接口：配置 =====

func 加载交易配置(config_path: String = "") -> bool:
	var target_path: String = config_path if not config_path.is_empty() else 交易配置路径
	var file: FileAccess = FileAccess.open(target_path, FileAccess.READ)
	if file == null:
		push_error("TradingSystem: 无法打开交易配置 " + target_path)
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("TradingSystem: 交易配置 JSON 格式错误 " + target_path)
		return false

	var config: Dictionary = parsed as Dictionary
	_contract_rules = config.get("contract", {}) as Dictionary
	_platform_rules = config.get("platforms", {}) as Dictionary
	_margin_rules = config.get("margin", {}) as Dictionary
	_debt_rules = config.get("debt", {}) as Dictionary
	return true

## ===== 公共接口：交易 =====

## direction: TradePosition.Direction.LONG_FOREIGN 表示做多外币；LONG_XMY 表示做多熊猫元
func 开仓(货币代码: String, 方向: int, 手数: float, 杠杆: int, 平台: String = "国内") -> Dictionary:
	if _market_engine == null:
		return _make_error_result("缺少 MarketEngine，无法开仓")
	if not _is_platform_leverage_available(平台, 杠杆):
		return _make_error_result("该平台不支持当前杠杆")

	var current_rate: float = _market_engine.获取汇率(货币代码)
	if current_rate <= 0.0:
		return _make_error_result("货币代码无效或暂无报价")

	var normalized_lots: float = _normalize_lots(手数)
	if normalized_lots <= 0.0:
		return _make_error_result("手数低于最小交易单位")

	var notional_xmy: float = normalized_lots * _get_lot_value_xmy()
	var margin_used: float = notional_xmy / float(max(杠杆, 1))
	var open_cost: float = _calculate_trade_cost(平台, notional_xmy)
	var projected_equity: float = 获取净资产() - open_cost
	var projected_used_margin: float = 获取已用保证金() + margin_used
	if projected_equity <= 0.0 or projected_equity / max(projected_used_margin, 0.01) < 获取时段强平线():
		return _make_error_result("保证金不足，开仓后会进入强平区")

	_cash_balance -= open_cost
	var position: TradePosition = TradePosition.create(
		_next_position_id,
		货币代码,
		_clamp_direction(方向),
		平台,
		杠杆,
		normalized_lots,
		_get_lot_value_xmy(),
		current_rate,
		_current_turn,
		open_cost
	)
	_next_position_id += 1
	_positions.append(position)
	_update_highest_equity()

	var snapshot: Dictionary = _get_position_snapshot(position)
	持仓开启.emit(snapshot)
	_emit_account_changed()
	_log_trade("开仓 " + str(snapshot))
	return {
		"success": true,
		"position": snapshot
	}

func 平仓(持仓编号: int, 原因: String = "手动平仓", 额外滑点率: float = 0.0) -> Dictionary:
	var position: TradePosition = _find_position(持仓编号)
	if position == null:
		return _make_error_result("未找到持仓")
	var result: Dictionary = _close_position(position, 原因, 额外滑点率)
	持仓关闭.emit(result)
	_emit_account_changed()
	return result

func 平掉全部持仓(原因: String = "全部平仓", 额外滑点率: float = 0.0) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var closing_positions: Array = _positions.duplicate()
	for position in closing_positions:
		results.append(_close_position(position, 原因, 额外滑点率))
	_emit_account_changed()
	return results

func 检查实时强平() -> void:
	if _positions.is_empty():
		return
	var margin_ratio: float = 获取保证金比例()
	if margin_ratio >= 获取实时强平线():
		if margin_ratio < 获取时段强平线():
			保证金警告.emit("时段强平风险", margin_ratio)
		return
	var results: Array[Dictionary] = 平掉全部持仓("实时强平", 获取实时强平惩罚滑点())
	for result in results:
		强制平仓.emit("实时强平", result)

func 检查时段强平() -> void:
	if _positions.is_empty():
		return
	var margin_ratio: float = 获取保证金比例()
	if margin_ratio >= 获取时段强平线():
		return
	var results: Array[Dictionary] = 平掉全部持仓("时段强平", 获取时段强平惩罚滑点())
	for result in results:
		强制平仓.emit("时段强平", result)

## ===== 公共接口：查询 =====

func 获取现金() -> float:
	return _cash_balance

func 获取负债() -> float:
	return _debt

func 获取浮动盈亏() -> float:
	var total: float = 0.0
	for position in _positions:
		total += position.calculate_floating_pnl(_get_position_market_rate(position))
	return total

func 获取净资产() -> float:
	return _cash_balance + 获取浮动盈亏() - _debt

func 获取已用保证金() -> float:
	var total: float = 0.0
	for position in _positions:
		total += position.margin_used
	return total

func 获取保证金比例() -> float:
	var used_margin: float = 获取已用保证金()
	if used_margin <= 0.0:
		return 999.0
	return 获取净资产() / used_margin

func 获取账户快照() -> Dictionary:
	var position_snapshots: Array[Dictionary] = []
	for position in _positions:
		position_snapshots.append(_get_position_snapshot(position))
	return {
		"cash": _cash_balance,
		"debt": _debt,
		"floating_pnl": 获取浮动盈亏(),
		"equity": 获取净资产(),
		"used_margin": 获取已用保证金(),
		"margin_ratio": 获取保证金比例(),
		"highest_equity": _highest_equity,
		"positions": position_snapshots
	}

func 获取实时强平线() -> float:
	return float(_margin_rules.get("realtime_liquidation_ratio", 0.20))

func 获取时段强平线() -> float:
	return float(_margin_rules.get("period_liquidation_ratio", 0.50))

func 获取实时强平惩罚滑点() -> float:
	return float(_margin_rules.get("realtime_liquidation_slippage_penalty", 0.002))

func 获取时段强平惩罚滑点() -> float:
	return float(_margin_rules.get("period_liquidation_slippage_penalty", 0.001))

## ===== 公共接口：结算与存档 =====

func 处理每日负债利息() -> void:
	if _debt <= 0.0:
		return
	if 获取净资产() < float(_debt_rules.get("interest_pause_equity_threshold", 5000.0)):
		_debt_interest_pause_days_left = max(_debt_interest_pause_days_left, int(_debt_rules.get("interest_pause_days", 30)))
	if _debt_interest_pause_days_left > 0:
		_debt_interest_pause_days_left -= 1
		return
	var daily_interest_rate: float = float(_debt_rules.get("annual_interest_rate", 0.10)) / 365.0
	_debt += _debt * daily_interest_rate
	_apply_debt_cap()
	_emit_account_changed()

func 收集存档数据() -> Dictionary:
	var positions_data: Array[Dictionary] = []
	for position in _positions:
		positions_data.append(position.collect_save_data())
	return {
		"cash_balance": _cash_balance,
		"debt": _debt,
		"highest_equity": _highest_equity,
		"next_position_id": _next_position_id,
		"current_turn": _current_turn,
		"debt_interest_pause_days_left": _debt_interest_pause_days_left,
		"positions": positions_data
	}

func 恢复存档数据(data: Dictionary) -> void:
	if data.is_empty():
		return
	_cash_balance = float(data.get("cash_balance", _cash_balance))
	_debt = max(float(data.get("debt", _debt)), 0.0)
	_highest_equity = max(float(data.get("highest_equity", _highest_equity)), 0.0)
	_next_position_id = max(int(data.get("next_position_id", _next_position_id)), 1)
	_current_turn = max(int(data.get("current_turn", _current_turn)), 0)
	_debt_interest_pause_days_left = max(int(data.get("debt_interest_pause_days_left", _debt_interest_pause_days_left)), 0)
	_positions.clear()
	var positions_data: Array = data.get("positions", []) as Array
	for item in positions_data:
		if not (item is Dictionary):
			continue
		var position: TradePosition = TradePosition.new()
		position.restore_save_data(item as Dictionary)
		_positions.append(position)
	_emit_account_changed()

## ===== 私有方法 =====

func _try_connect_market_engine() -> void:
	_market_engine = get_node_or_null("../MarketEngine") as MarketEngine
	if _market_engine == null:
		return
	if not _market_engine.汇率变动.is_connected(_on_market_rate_changed):
		_market_engine.汇率变动.connect(_on_market_rate_changed)

func _try_connect_time_system() -> void:
	var time_system: Node = get_node_or_null("../TimeSystem")
	if time_system == null:
		return
	if time_system.has_signal("回合推进") and not time_system.回合推进.is_connected(_on_time_system_turn_advanced):
		time_system.回合推进.connect(_on_time_system_turn_advanced)
	if time_system.has_signal("深夜结算开始") and not time_system.深夜结算开始.is_connected(_on_time_system_late_night_settlement):
		time_system.深夜结算开始.connect(_on_time_system_late_night_settlement)

func _on_market_rate_changed(_货币代码: String, _汇率快照: Dictionary) -> void:
	检查实时强平()
	_emit_account_changed()

func _on_time_system_turn_advanced(总回合: int, _时段索引: int, _时段名称: String) -> void:
	_current_turn = 总回合
	检查时段强平()

func _on_time_system_late_night_settlement() -> void:
	处理每日负债利息()

func _close_position(position: TradePosition, reason: String, extra_slippage_rate: float) -> Dictionary:
	var current_rate: float = _get_position_market_rate(position)
	var floating_pnl: float = position.calculate_floating_pnl(current_rate)
	var close_cost: float = _calculate_trade_cost(position.platform, position.notional_xmy, extra_slippage_rate)
	var net_result: float = floating_pnl - close_cost
	_cash_balance += net_result
	_positions.erase(position)
	if _cash_balance < 0.0:
		_debt += absf(_cash_balance)
		_cash_balance = 0.0
		_apply_debt_cap()
	_update_highest_equity()

	var result: Dictionary = {
		"success": true,
		"reason": reason,
		"position_id": position.position_id,
		"currency_code": position.currency_code,
		"entry_rate": position.entry_rate,
		"close_rate": current_rate,
		"floating_pnl": floating_pnl,
		"close_cost": close_cost,
		"net_result": net_result,
		"cash": _cash_balance,
		"debt": _debt
	}
	_log_trade("平仓 " + str(result))
	return result

func _calculate_trade_cost(platform: String, notional_xmy: float, extra_slippage_rate: float = 0.0) -> float:
	var platform_rule: Dictionary = _platform_rules.get(platform, {}) as Dictionary
	var spread_rate: float = float(platform_rule.get("spread_rate", 0.0005))
	var slippage_rate: float = float(platform_rule.get("base_slippage_rate", 0.00008))
	return notional_xmy * (spread_rate + slippage_rate + max(extra_slippage_rate, 0.0))

func _normalize_lots(lots: float) -> float:
	var min_lot: float = float(_contract_rules.get("min_lot", 0.01))
	if lots < min_lot:
		return 0.0
	return floor(lots / min_lot) * min_lot

func _get_lot_value_xmy() -> float:
	return float(_contract_rules.get("lot_value_xmy", _contract_rules.get("lot_value_rmb", 100000.0)))

func _is_platform_leverage_available(platform: String, leverage: int) -> bool:
	var platform_rule: Dictionary = _platform_rules.get(platform, {}) as Dictionary
	var available_leverages: Array = platform_rule.get("available_leverages", []) as Array
	return available_leverages.has(leverage)

func _find_position(position_id: int) -> TradePosition:
	for position in _positions:
		if position.position_id == position_id:
			return position
	return null

func _get_position_market_rate(position: TradePosition) -> float:
	if _market_engine == null:
		return position.entry_rate
	var current_rate: float = _market_engine.获取汇率(position.currency_code)
	return current_rate if current_rate > 0.0 else position.entry_rate

func _get_position_snapshot(position: TradePosition) -> Dictionary:
	var current_rate: float = _get_position_market_rate(position)
	return {
		"position_id": position.position_id,
		"currency_code": position.currency_code,
		"direction": position.direction,
		"platform": position.platform,
		"leverage": position.leverage,
		"lots": position.lots,
		"notional_xmy": position.notional_xmy,
		"margin_used": position.margin_used,
		"entry_rate": position.entry_rate,
		"current_rate": current_rate,
		"floating_pnl": position.calculate_floating_pnl(current_rate),
		"opened_turn": position.opened_turn
	}

func _clamp_direction(direction: int) -> int:
	if direction == TradePosition.Direction.LONG_XMY:
		return TradePosition.Direction.LONG_XMY
	return TradePosition.Direction.LONG_FOREIGN

func _update_highest_equity() -> void:
	_highest_equity = max(_highest_equity, 获取净资产())

func _apply_debt_cap() -> void:
	var debt_cap: float = max(_highest_equity, 1.0) * float(_debt_rules.get("max_debt_multiplier_of_highest_equity", 2.0))
	_debt = min(_debt, debt_cap)

func _emit_account_changed() -> void:
	_update_highest_equity()
	账户变化.emit(获取账户快照())

func _make_error_result(message: String) -> Dictionary:
	return {
		"success": false,
		"error": message
	}

func _log_trade(message: String) -> void:
	if not 启用交易日志:
		return
	print("TradingSystem: ", message)
