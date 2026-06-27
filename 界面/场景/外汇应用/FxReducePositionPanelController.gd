## 描述: 减仓弹窗控制器，在当前持仓货币对中减少手数
## 依赖: 父节点为国内炒汇场景；可选依赖 GameDataManager/TradingSystem、MarketEngine
## 状态: 第一阶段
## 最后更新: 2026-06-25
extends Panel
class_name FxReducePositionPanelController

## 用户确认减仓后发射，父节点监听后执行实际交易操作
signal reduce_confirmed(slot: Dictionary, reduce_lots: float)

const NORMAL_TEXT_COLOR := Color(0.96, 0.98, 1.0, 1.0)
const PROFIT_COLOR := Color(0.2, 0.9019608, 0, 1)
const LOSS_COLOR := Color(0.93, 0.24, 0.18, 0.95)
const YEAR_DAYS := 365.0

@export var 界面配置路径: String = "res://资源/数据/市场/fx_ui_config.json"
@export var 交易配置路径: String = "res://资源/数据/交易/trading_config.json"

var _slot: Dictionary = {}
var _slot_owner: Node = null
var _trading_system: Node = null
var _market_engine: Node = null
var _currency_catalog: Dictionary = {}
var _trading_config: Dictionary = {}
var _selected_reduce_lots: float = 1.0
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

## 打开减仓弹窗，传入当前选中的槽位数据
func open_for_slot(slot: Dictionary, slot_owner: Node) -> void:
	_slot = slot.duplicate(true)
	_slot_owner = slot_owner
	_current_position_lots = max(float(_slot.get("mock_lots", 0.0)), 0.01)
	_current_leverage = max(int(_slot.get("mock_leverage", 1)), 1)
	_selected_reduce_lots = min(1.0, _current_position_lots)
	var slider: HSlider = _find_descendant_by_name(self, "手数滑块") as HSlider
	if slider != null:
		slider.max_value = _current_position_lots
		slider.value = _selected_reduce_lots
	z_as_relative = false
	z_index = 300
	visible = true
	_refresh_content()

func close_panel() -> void:
	visible = false
	_slot_owner = null

func _load_config() -> void:
	_currency_catalog.clear()
	var file: FileAccess = FileAccess.open(界面配置路径, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var config: Dictionary = parsed as Dictionary
	var raw_list: Array = config.get("currencies", []) as Array
	var catalog: Dictionary = {}
	for entry in raw_list:
		if entry is Dictionary:
			var item: Dictionary = entry as Dictionary
			catalog[str(item.get("code", ""))] = item
	_currency_catalog = catalog
	var trading_file: FileAccess = FileAccess.open(交易配置路径, FileAccess.READ)
	if trading_file == null:
		return
	var trading_parsed: Variant = JSON.parse_string(trading_file.get_as_text())
	if trading_parsed is Dictionary:
		_trading_config = (trading_parsed as Dictionary).duplicate(true)

func _connect_controls() -> void:
	var slider: HSlider = _find_descendant_by_name(self, "手数滑块") as HSlider
	if slider != null and not slider.value_changed.is_connected(_on_slider_changed):
		slider.value_changed.connect(_on_slider_changed)
	var minus_btn: Button = _find_descendant_by_name(self, "减号按钮") as Button
	if minus_btn != null and not minus_btn.pressed.is_connected(_on_minus_pressed):
		minus_btn.pressed.connect(_on_minus_pressed)
	var plus_btn: Button = _find_descendant_by_name(self, "加号按钮") as Button
	if plus_btn != null and not plus_btn.pressed.is_connected(_on_plus_pressed):
		plus_btn.pressed.connect(_on_plus_pressed)
	var cancel_btn: Button = _find_descendant_by_name(self, "取消") as Button
	if cancel_btn != null and not cancel_btn.pressed.is_connected(close_panel):
		cancel_btn.pressed.connect(close_panel)
	var confirm_btn: Button = _find_descendant_by_name(self, "确认减仓") as Button
	if confirm_btn != null and not confirm_btn.pressed.is_connected(_on_confirm_pressed):
		confirm_btn.pressed.connect(_on_confirm_pressed)

func _refresh_content() -> void:
	if _slot.is_empty():
		return
	_refresh_position_info()
	_refresh_numbers()
	_refresh_liquidation_change()

func _refresh_position_info() -> void:
	var left_code: String = str(_slot.get("left_code", "XMY"))
	var right_code: String = str(_slot.get("right_code", "USD"))
	var direction_text: String = str(_slot.get("direction_text", "做多"))
	var position_info_label: Label = _find_descendant_by_name(self, "仓位信息") as Label
	if position_info_label != null:
		position_info_label.text = "%s/%s  %.2f手 %s" % [left_code, right_code, _current_position_lots, direction_text]
	var floating_pnl: float = _calculate_floating_pnl()
	var floating_label: Label = _find_descendant_by_name(self, "浮盈信息") as Label
	if floating_label != null:
		if floating_pnl >= 0.0:
			floating_label.text = "+%s" % _format_number(floating_pnl)
			floating_label.add_theme_color_override("font_color", PROFIT_COLOR)
		else:
			floating_label.text = "%s" % _format_number(floating_pnl)
			floating_label.add_theme_color_override("font_color", LOSS_COLOR)
	var detail_label: Label = _find_descendant_by_name(self, "持仓明细") as Label
	if detail_label != null:
		var entry_rate: float = float(_slot.get("mock_entry_rate", 0.0))
		var current_rate: float = _get_current_pair_rate(left_code, right_code)
		detail_label.text = "开仓价 %.4f    现价 %.4f    杠杆 %d倍" % [entry_rate, current_rate, _current_leverage]

func _refresh_numbers() -> void:
	var lots_label: Label = _find_descendant_by_name(self, "手数值") as Label
	if lots_label != null:
		lots_label.text = "本次减仓: %.2f 手" % _selected_reduce_lots
	var margin_per_lot: float = _get_margin_per_lot()
	var released_margin: float = margin_per_lot * _selected_reduce_lots
	var recover_label: Label = _find_descendant_by_name(self, "预计回收") as Label
	if recover_label != null:
		recover_label.text = "预计回收保证金: %s XMY" % _format_number(released_margin)
	var remaining: float = max(_current_position_lots - _selected_reduce_lots, 0.0)
	var remaining_label: Label = _find_descendant_by_name(self, "减仓后剩余") as Label
	if remaining_label != null:
		remaining_label.text = "剩余仓位: %.2f 手" % remaining

func _refresh_liquidation_change() -> void:
	var left_code: String = str(_slot.get("left_code", "XMY"))
	var right_code: String = str(_slot.get("right_code", "USD"))
	var current_rate: float = _get_current_pair_rate(left_code, right_code)
	var current_liquidation: float = _estimate_liquidation_rate(_current_position_lots, current_rate)
	var new_lots: float = max(_current_position_lots - _selected_reduce_lots, 0.01)
	var new_liquidation: float = _estimate_liquidation_rate(new_lots, current_rate)
	var label: Label = _find_descendant_by_name(self, "强平线变化") as Label
	if label != null:
		var arrow: String = "⬇" if new_liquidation < current_liquidation else "⬆"
		label.text = "强平线变化: %.4f -> %.4f%s" % [current_liquidation, new_liquidation, arrow]

func _estimate_liquidation_rate(lots: float, current_rate: float) -> float:
	var safe_rate: float = max(current_rate, 0.000001)
	var account_snapshot: Dictionary = _get_account_snapshot()
	if account_snapshot.is_empty():
		return safe_rate * (0.82 if str(_slot.get("direction_text", "做多")) == "做多" else 1.18)
	var total_equity: float = float(account_snapshot.get("equity", 0.0))
	var total_used_margin: float = float(account_snapshot.get("used_margin", 0.0))
	var liquidation_ratio: float = _get_period_liquidation_ratio()
	var margin_per_lot: float = _get_margin_per_lot()
	var new_margin: float = margin_per_lot * lots
	var pnl_needed: float = liquidation_ratio * new_margin - total_equity
	var notional_per_lot: float = _get_notional_per_lot()
	var total_notional: float = notional_per_lot * lots
	if total_notional <= 0.0:
		return safe_rate * (0.82 if str(_slot.get("direction_text", "做多")) == "做多" else 1.18)
	var rate_shift: float = pnl_needed / total_notional
	if str(_slot.get("direction_text", "做多")) == "做多":
		return safe_rate * (1.0 + rate_shift)
	return safe_rate * (1.0 - rate_shift)

func _calculate_floating_pnl() -> float:
	var left_code: String = str(_slot.get("left_code", "XMY"))
	var right_code: String = str(_slot.get("right_code", "USD"))
	var entry_rate: float = float(_slot.get("mock_entry_rate", 0.0))
	var current_rate: float = _get_current_pair_rate(left_code, right_code)
	if entry_rate <= 0.0 or current_rate <= 0.0:
		return float(_slot.get("mock_floating_pnl", 0.0))
	var notional: float = _get_notional_per_lot() * _current_position_lots
	var rate_change: float = (current_rate - entry_rate) / max(entry_rate, 0.000001)
	var direction_sign: float = 1.0 if str(_slot.get("direction_text", "做多")) == "做多" else -1.0
	return notional * rate_change * direction_sign

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
	if _currency_catalog.has(code):
		return float(_currency_catalog[code].get("annual_rate", 0.0)) * 100.0
	return 0.0

func _get_notional_per_lot() -> float:
	var contract_rules: Dictionary = _trading_config.get("contract", {}) as Dictionary
	return float(contract_rules.get("lot_value_xmy", 100000.0))

func _get_margin_per_lot() -> float:
	return _get_notional_per_lot() / float(max(_current_leverage, 1))

func _get_period_liquidation_ratio() -> float:
	if _trading_system != null and _trading_system.has_method("获取时段强平线"):
		return float(_trading_system.call("获取时段强平线"))
	var margin_rules: Dictionary = _trading_config.get("margin", {}) as Dictionary
	return float(margin_rules.get("period_liquidation_ratio", 0.50))

func _get_account_snapshot() -> Dictionary:
	if _trading_system != null and _trading_system.has_method("获取账户快照"):
		return _trading_system.call("获取账户快照") as Dictionary
	return {}

func _on_slider_changed(value: float) -> void:
	_selected_reduce_lots = snappedf(value, 0.01)
	_selected_reduce_lots = clampf(_selected_reduce_lots, 0.01, _current_position_lots)
	_refresh_content()

func _on_minus_pressed() -> void:
	_selected_reduce_lots = max(snappedf(_selected_reduce_lots - 0.01, 0.01), 0.01)
	_sync_slider()
	_refresh_content()

func _on_plus_pressed() -> void:
	_selected_reduce_lots = min(snappedf(_selected_reduce_lots + 0.01, 0.01), _current_position_lots)
	_sync_slider()
	_refresh_content()

func _sync_slider() -> void:
	var slider: HSlider = _find_descendant_by_name(self, "手数滑块") as HSlider
	if slider != null and not is_equal_approx(slider.value, _selected_reduce_lots):
		slider.value = _selected_reduce_lots

func _on_confirm_pressed() -> void:
	if _selected_reduce_lots <= 0.0 or _slot_owner == null:
		return
	reduce_confirmed.emit(_slot, _selected_reduce_lots)
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
