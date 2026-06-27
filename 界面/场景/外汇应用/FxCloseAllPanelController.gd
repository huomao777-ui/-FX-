## 描述: 一键平仓弹窗控制器，按当前价格全部平掉选中持仓
## 依赖: 父节点为国内炒汇场景；可选依赖 GameDataManager/TradingSystem、MarketEngine
## 状态: 第一阶段
## 最后更新: 2026-06-25
extends Panel
class_name FxCloseAllPanelController

## 用户确认平仓后发射，父节点监听后执行 TradingSystem.平仓()
signal close_all_confirmed(slot: Dictionary)

const NORMAL_TEXT_COLOR := Color(0.96, 0.98, 1.0, 1.0)
const PROFIT_COLOR := Color(0.2, 0.9019608, 0, 1)
const LOSS_COLOR := Color(0.93, 0.24, 0.18, 0.95)

@export var 界面配置路径: String = "res://资源/数据/市场/fx_ui_config.json"
@export var 交易配置路径: String = "res://资源/数据/交易/trading_config.json"

var _slot: Dictionary = {}
var _slot_owner: Node = null
var _trading_system: Node = null
var _market_engine: Node = null
var _trading_config: Dictionary = {}
var _current_position_lots: float = 0.0
var _current_leverage: int = 1

func _ready() -> void:
	z_as_relative = false
	z_index = 300
	_load_config()
	_trading_system = get_node_or_null("/root/GameDataManager/TradingSystem")
	_market_engine = get_node_or_null("/root/GameDataManager/MarketEngine")
	_connect_controls()
	visible = false

## 打开一键平仓弹窗，传入当前选中的持仓槽位数据
func open_for_slot(slot: Dictionary, slot_owner: Node) -> void:
	_slot = slot.duplicate(true)
	_slot_owner = slot_owner
	_current_position_lots = max(float(_slot.get("mock_lots", 0.0)), 0.0)
	_current_leverage = max(int(_slot.get("mock_leverage", 1)), 1)
	z_as_relative = false
	z_index = 300
	visible = true
	_refresh_content()

func close_panel() -> void:
	visible = false
	_slot_owner = null

func _load_config() -> void:
	var trading_file: FileAccess = FileAccess.open(交易配置路径, FileAccess.READ)
	if trading_file == null:
		return
	var parsed: Variant = JSON.parse_string(trading_file.get_as_text())
	if parsed is Dictionary:
		_trading_config = (parsed as Dictionary).duplicate(true)

func _connect_controls() -> void:
	var cancel_btn: Button = _find_descendant_by_name(self, "再想想") as Button
	if cancel_btn != null and not cancel_btn.pressed.is_connected(close_panel):
		cancel_btn.pressed.connect(close_panel)
	var confirm_btn: Button = _find_descendant_by_name(self, "立即平仓") as Button
	if confirm_btn != null and not confirm_btn.pressed.is_connected(_on_confirm_pressed):
		confirm_btn.pressed.connect(_on_confirm_pressed)

func _refresh_content() -> void:
	if _slot.is_empty():
		return
	_refresh_position_overview()
	_refresh_pnl()
	_refresh_detail_info()

func _refresh_position_overview() -> void:
	var left_code: String = str(_slot.get("left_code", "XMY"))
	var right_code: String = str(_slot.get("right_code", "USD"))
	var direction_text: String = str(_slot.get("direction_text", "做多"))
	var overview_label: Label = _find_descendant_by_name(self, "仓位概览") as Label
	if overview_label != null:
		overview_label.text = "%s/%s  %.2f手 %s" % [left_code, right_code, _current_position_lots, direction_text]

func _refresh_pnl() -> void:
	var floating_pnl: float = _calculate_floating_pnl()
	var close_cost: float = _calculate_close_cost()
	var net_result: float = floating_pnl - close_cost
	var pnl_label: Label = _find_descendant_by_name(self, "盈亏结果") as Label
	if pnl_label != null:
		var formatted: String = _format_number(absf(net_result))
		if net_result >= 0.0:
			pnl_label.text = "+%s XMY" % formatted
			pnl_label.add_theme_color_override("font_color", PROFIT_COLOR)
		else:
			pnl_label.text = "-%s XMY" % formatted
			pnl_label.add_theme_color_override("font_color", LOSS_COLOR)

func _refresh_detail_info() -> void:
	var left_code: String = str(_slot.get("left_code", "XMY"))
	var right_code: String = str(_slot.get("right_code", "USD"))
	var entry_rate: float = float(_slot.get("mock_entry_rate", 0.0))
	var current_rate: float = _get_current_pair_rate(left_code, right_code)
	var price_label: Label = _find_descendant_by_name(self, "成交价格") as Label
	if price_label != null:
		price_label.text = "预计成交价: %.4f" % current_rate
	var margin_per_lot: float = _get_margin_per_lot()
	var total_margin: float = margin_per_lot * _current_position_lots
	var margin_label: Label = _find_descendant_by_name(self, "释放保证金") as Label
	if margin_label != null:
		margin_label.text = "释放保证金: %s XMY" % _format_number(total_margin)

func _calculate_floating_pnl() -> float:
	var left_code: String = str(_slot.get("left_code", "XMY"))
	var right_code: String = str(_slot.get("right_code", "USD"))
	var entry_rate: float = float(_slot.get("mock_entry_rate", 0.0))
	var current_rate: float = _get_current_pair_rate(left_code, right_code)
	if entry_rate <= 0.0 or current_rate <= 0.0:
		return float(_slot.get("mock_floating_pnl", 0.0))
	if _current_position_lots <= 0.0:
		return 0.0
	var notional: float = _get_notional_per_lot() * _current_position_lots
	var rate_change: float = (current_rate - entry_rate) / max(entry_rate, 0.000001)
	var direction_sign: float = 1.0 if str(_slot.get("direction_text", "做多")) == "做多" else -1.0
	return notional * rate_change * direction_sign

func _calculate_close_cost() -> float:
	var notional: float = _get_notional_per_lot() * _current_position_lots
	var spread_rate_val: float = _get_platform_spread_rate()
	var slippage_rate_val: float = _get_base_slippage_rate()
	return notional * (spread_rate_val + slippage_rate_val)

func _get_current_pair_rate(left_code: String, right_code: String) -> float:
	var left_rate: float = _get_rate_against_xmy(left_code)
	var right_rate: float = _get_rate_against_xmy(right_code)
	if left_rate <= 0.0 or right_rate <= 0.0:
		return float(_slot.get("mock_entry_rate", 0.0))
	return right_rate / left_rate

func _get_rate_against_xmy(code: String) -> float:
	if code == "XMY":
		return 1.0
	if _market_engine != null and _market_engine.has_method("获取汇率"):
		var rate: float = float(_market_engine.call("获取汇率", code))
		if rate > 0.0:
			return rate
	return 0.0

func _get_notional_per_lot() -> float:
	var contract_rules: Dictionary = _trading_config.get("contract", {}) as Dictionary
	return float(contract_rules.get("lot_value_xmy", 100000.0))

func _get_margin_per_lot() -> float:
	return _get_notional_per_lot() / float(max(_current_leverage, 1))

func _get_platform_spread_rate() -> float:
	var platform_rules: Dictionary = _trading_config.get("platforms", {}) as Dictionary
	var platform_name: String = "国内"
	return float(platform_rules.get(platform_name, {}).get("spread_rate", 0.0005))

func _get_base_slippage_rate() -> float:
	var platform_rules: Dictionary = _trading_config.get("platforms", {}) as Dictionary
	var platform_name: String = "国内"
	return float(platform_rules.get(platform_name, {}).get("base_slippage_rate", 0.00008))

func _on_confirm_pressed() -> void:
	if _slot_owner == null:
		return
	close_all_confirmed.emit(_slot)
	close_panel()

func _format_number(value: float) -> String:
	var rounded: int = int(round(value))
	var text: String = str(rounded)
	var result: String = ""
	var count: int = 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[i] + result
		count += 1
	return result

func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found: Node = _find_descendant_by_name(child, target_name)
		if found != null:
			return found
	return null
