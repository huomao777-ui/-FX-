## 描述: 单笔外汇持仓数据
## 依赖: TradingSystem 创建和维护
## 状态: 第一阶段
## 最后更新: 2026-06-12
class_name TradePosition
extends RefCounted

enum Direction {
	LONG_RMB = 1,
	LONG_FOREIGN = -1
}

var position_id: int = 0
var currency_code: String = ""
var direction: int = Direction.LONG_FOREIGN
var platform: String = "国内"
var leverage: int = 1
var lots: float = 0.01
var notional_rmb: float = 1000.0
var margin_used: float = 1000.0
var entry_rate: float = 1.0
var open_cost: float = 0.0
var opened_turn: int = 0

static func create(
	new_position_id: int,
	new_currency_code: String,
	new_direction: int,
	new_platform: String,
	new_leverage: int,
	new_lots: float,
	lot_value_rmb: float,
	current_rate: float,
	current_turn: int,
	cost: float
) -> TradePosition:
	var position: TradePosition = TradePosition.new()
	position.position_id = new_position_id
	position.currency_code = new_currency_code
	position.direction = new_direction
	position.platform = new_platform
	position.leverage = max(new_leverage, 1)
	position.lots = max(new_lots, 0.0)
	position.notional_rmb = position.lots * lot_value_rmb
	position.margin_used = position.notional_rmb / float(position.leverage)
	position.entry_rate = max(current_rate, 0.000001)
	position.opened_turn = current_turn
	position.open_cost = max(cost, 0.0)
	return position

func calculate_floating_pnl(current_rate: float) -> float:
	var safe_entry_rate: float = max(entry_rate, 0.000001)
	var rate_change: float = (current_rate - safe_entry_rate) / safe_entry_rate
	return notional_rmb * rate_change * float(direction)

func collect_save_data() -> Dictionary:
	return {
		"position_id": position_id,
		"currency_code": currency_code,
		"direction": direction,
		"platform": platform,
		"leverage": leverage,
		"lots": lots,
		"notional_rmb": notional_rmb,
		"margin_used": margin_used,
		"entry_rate": entry_rate,
		"open_cost": open_cost,
		"opened_turn": opened_turn
	}

func restore_save_data(data: Dictionary) -> void:
	position_id = int(data.get("position_id", position_id))
	currency_code = str(data.get("currency_code", currency_code))
	direction = int(data.get("direction", direction))
	platform = str(data.get("platform", platform))
	leverage = max(int(data.get("leverage", leverage)), 1)
	lots = max(float(data.get("lots", lots)), 0.0)
	notional_rmb = max(float(data.get("notional_rmb", notional_rmb)), 0.0)
	margin_used = max(float(data.get("margin_used", margin_used)), 0.0)
	entry_rate = max(float(data.get("entry_rate", entry_rate)), 0.000001)
	open_cost = max(float(data.get("open_cost", open_cost)), 0.0)
	opened_turn = max(int(data.get("opened_turn", opened_turn)), 0)
