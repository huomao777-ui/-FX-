extends Panel
class_name FxKLinePanelController

const KLineChartLayerScript = preload("res://界面/场景/外汇应用/FxKLineChartLayerV3.gd")

## K线面板头部的"开仓日期"与"预计损益"标签，通过 TradingSystem 持仓数据和 MarketEngine 行情驱动刷新

@export var 默认显示货币代码: String = "USD"
@export var 涨颜色: Color = Color(0.93, 0.24, 0.18, 0.95)
@export var 跌颜色: Color = Color(0.14, 0.76, 0.34, 0.95)

@export_group("坐标轴（转发至K线层）")
## 右侧价格轴显示的刻度数量
@export_range(2, 20, 1) var 右侧刻度数量: int = 5
## 底部时间轴默认刻度数量（当周期标签间隔为0时使用）
@export_range(2, 30, 1) var 下方刻度数量: int = 6
## 坐标文字字号
@export_range(8, 24, 1) var 坐标字体大小: int = 13

@export_group("各周期标签间隔（转发至K线层，0=使用默认刻度数量）")
@export_range(0, 120, 1) var 分钟间隔分钟: int = 12
@export_range(0, 48, 1) var 小时间隔小时: int = 6
@export_range(0, 60, 1) var 天间隔天: int = 7
@export_range(0, 60, 1) var 周间隔天: int = 7
@export_range(0, 30, 1) var 月间隔月: int = 6
@export_range(0, 30, 1) var 年间隔年: int = 5

const TURNS_PER_DAY := 5

var _chart_layer: FxKLineChartLayerV3 = null
var _pair_label: Label = null
var _open_date_label: Label = null
var _pnl_label: RichTextLabel = null
var _market_engine: Node = null
var _trading_system: Node = null
var _time_system: Node = null
var _current_left_code: String = ""
var _current_right_code: String = ""
var _last_slot_data: Dictionary = {}
var _timeframe_buttons: Dictionary = {}
var _selected_timeframe_button: String = "一分钟"
var _timeframe_normal_style: StyleBox = null
var _timeframe_hover_style: StyleBox = null
var _timeframe_selected_style: StyleBox = null
var _timeframe_label_normal_color: Color = Color(0.86, 0.91, 0.97, 0.9)
var _timeframe_label_selected_color: Color = Color(0.95, 0.98, 1.0, 0.98)

func _ready() -> void:
	_pair_label = _find_descendant_by_name(self, "货币种类") as Label
	_open_date_label = _find_descendant_by_name(self, "开仓日期") as Label
	_pnl_label = _find_descendant_by_name(self, "预计损益") as RichTextLabel
	_market_engine = get_node_or_null("/root/GameDataManager/MarketEngine")
	_trading_system = get_node_or_null("/root/GameDataManager/TradingSystem")
	_time_system = get_node_or_null("/root/GameDataManager/TimeSystem")
	_setup_kline_chart()
	_connect_timeframe_buttons()
	_connect_market_signals()
	_connect_trading_signals()

func show_pair(left_code: String, right_code: String, pair_text: String = "") -> void:
	if left_code.is_empty() or right_code.is_empty():
		clear_chart()
		return
	var display_text: String = pair_text if not pair_text.is_empty() else left_code + "/" + right_code
	if _pair_label != null:
		_pair_label.text = display_text
	_current_left_code = left_code
	_current_right_code = right_code
	if _chart_layer != null and _chart_layer.has_method("切换货币对"):
		_chart_layer.call("切换货币对", left_code, right_code, display_text)
	_refresh_position_labels()

## 由货币面板控制器在选中槽位更新时调用，传入槽位数据供标签刷新
func update_position_info(left_code: String, right_code: String, slot: Dictionary) -> void:
	_current_left_code = left_code
	_current_right_code = right_code
	_last_slot_data = slot.duplicate(true)
	_refresh_position_labels_from_slot(slot)

func clear_chart() -> void:
	if _pair_label != null:
		_pair_label.text = "XXX/XXX"
	_current_left_code = ""
	_current_right_code = ""
	if _chart_layer != null and _chart_layer.has_method("切换货币对"):
		_chart_layer.call("切换货币对", "", "", "")
	_clear_position_labels()

func set_liquidation_line(price: float, label_text: String = "") -> void:
	if _chart_layer != null and _chart_layer.has_method("设置强平线"):
		_chart_layer.call("设置强平线", price, label_text)

func clear_liquidation_line() -> void:
	set_liquidation_line(0.0, "")

## ===== 标签刷新 =====

## 从 TradingSystem 账户快照中查找当前货币对的持仓，刷新标签
## 若 TradingSystem 无数据则回退到 _last_slot_data（由 update_position_info 缓存的槽位数据），
## 避免行情变动或回合推进时标签被意外清空。
func _refresh_position_labels() -> void:
	if _current_left_code.is_empty() or _current_right_code.is_empty():
		_clear_position_labels()
		return
	var currency_code: String = _current_left_code
	var position: Dictionary = _find_position_for_currency(currency_code)
	if not position.is_empty():
		var floating_pnl: float = float(position.get("floating_pnl", 0.0))
		_set_pnl_label(floating_pnl)
		_set_open_date_label(int(position.get("opened_turn", 0)))
		return
	# TradingSystem 无持仓 → 回退到 slot 缓存数据
	if not _last_slot_data.is_empty():
		_refresh_position_labels_from_slot(_last_slot_data)
		return
	_clear_position_labels()

## 从 slot 数据（含 mock_lots/entry_rate）刷新标签，当 TradingSystem 不可用时作为备选
func _refresh_position_labels_from_slot(slot: Dictionary) -> void:
	if _current_left_code.is_empty() or _current_right_code.is_empty():
		_clear_position_labels()
		return
	var mock_lots: float = float(slot.get("mock_lots", 0.0))
	if mock_lots <= 0.0:
		_clear_position_labels()
		return
	var entry_rate: float = float(slot.get("mock_entry_rate", 0.0))
	var current_rate: float = _get_pair_rate(_current_left_code, _current_right_code)
	if entry_rate <= 0.0 or current_rate <= 0.0:
		# 有持仓但取不到汇率时显示持仓数据但不显示具体盈亏
		if _pnl_label != null:
			_pnl_label.text = "预计损益：[color=white]--[/color]"
		if _open_date_label != null:
			_open_date_label.text = "开仓日期： --"
		return
	var direction_sign: float = 1.0 if str(slot.get("direction_text", "做多")) == "做多" else -1.0
	var notional: float = _get_notional_per_lot() * mock_lots
	var rate_change: float = (current_rate - entry_rate) / max(entry_rate, 0.000001)
	var floating_pnl: float = notional * rate_change * direction_sign
	_set_pnl_label(floating_pnl)
	if _open_date_label != null:
		_open_date_label.text = "开仓日期： --"

func _clear_position_labels() -> void:
	if _open_date_label != null:
		_open_date_label.text = "开仓日期： --"
	if _pnl_label != null:
		_pnl_label.text = "[color=white]预计损益：[/color][color=white]--[/color]"

func _set_pnl_label(pnl_value: float) -> void:
	if _pnl_label == null:
		return
	var formatted: String = _format_number(absf(pnl_value))
	if pnl_value >= 0.0:
		_pnl_label.text = "[color=white]预计损益：[/color][color=#ee4444]+%s熊猫元[/color]" % formatted
	else:
		_pnl_label.text = "[color=white]预计损益：[/color][color=#22cc44]-%s熊猫元[/color]" % formatted

## 将 opened_turn 转为可读的日期文本
func _set_open_date_label(opened_turn: int) -> void:
	if _open_date_label == null:
		return
	if _time_system == null or not _time_system.has_method("获取当前日期数据"):
		_open_date_label.text = "开仓日期： 第%d回合" % opened_turn
		return
	var current_date: Dictionary = _time_system.call("获取当前日期数据") as Dictionary
	if current_date.is_empty():
		_open_date_label.text = "开仓日期： 第%d回合" % opened_turn
		return
	var current_turn: int = int(current_date.get("total_turns", 0))
	var turns_ago: int = max(current_turn - opened_turn, 0)
	var days_ago: int = int(turns_ago / TURNS_PER_DAY)
	var current_year: int = int(current_date.get("year", 2026))
	var current_month: int = int(current_date.get("month", 1))
	var current_day: int = int(current_date.get("day", 1))
	# 从当前日期向前推 days_ago 天（简化计算）
	var open_day: int = max(current_day - days_ago, 1)
	var open_month: int = current_month
	var open_year: int = current_year
	while open_day < 1:
		open_month -= 1
		if open_month < 1:
			open_month = 12
			open_year -= 1
		open_day += _get_days_in_month(open_year, open_month)
	_open_date_label.text = "开仓日期： %d年%d月%d日" % [open_year, open_month, open_day]

## ===== 辅助 =====

## 从 TradingSystem 账户快照中查找指定货币的持仓
func _find_position_for_currency(currency_code: String) -> Dictionary:
	if _trading_system == null or not _trading_system.has_method("获取账户快照"):
		return {}
	var snapshot: Dictionary = _trading_system.call("获取账户快照") as Dictionary
	if snapshot.is_empty():
		return {}
	var positions: Array = snapshot.get("positions", []) as Array
	for pos in positions:
		if not (pos is Dictionary):
			continue
		var pos_dict: Dictionary = pos as Dictionary
		if str(pos_dict.get("currency_code", "")) == currency_code:
			return pos_dict
	return {}

func _get_pair_rate(left_code: String, right_code: String) -> float:
	var left_rate: float = _get_rate_against_xmy(left_code)
	var right_rate: float = _get_rate_against_xmy(right_code)
	if left_rate <= 0.0 or right_rate <= 0.0:
		return 0.0
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
	if _trading_system != null and _trading_system.has_method("获取账户快照"):
		var snapshot: Dictionary = _trading_system.call("获取账户快照") as Dictionary
		var positions: Array = snapshot.get("positions", []) as Array
		if not positions.is_empty() and positions[0] is Dictionary:
			var first_pos: Dictionary = positions[0] as Dictionary
			var lots: float = max(float(first_pos.get("lots", 0.01)), 0.01)
			var notional_total: float = float(first_pos.get("notional_xmy", 100000.0))
			return notional_total / lots
	return 100000.0

func _get_days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0 else 28
		_:
			return 30

## ===== 信号连接 =====

func _connect_market_signals() -> void:
	if _market_engine == null or not _market_engine.has_signal("汇率变动"):
		return
	var callback := Callable(self, "_on_market_rate_changed")
	if not _market_engine.is_connected("汇率变动", callback):
		_market_engine.connect("汇率变动", callback)

func _connect_trading_signals() -> void:
	if _trading_system == null or not _trading_system.has_signal("账户变化"):
		return
	var callback := Callable(self, "_on_account_changed")
	if not _trading_system.is_connected("账户变化", callback):
		_trading_system.connect("账户变化", callback)

## ===== 信号回调 =====

func _on_market_rate_changed(_currency_code: String, _rate_snapshot: Dictionary) -> void:
	# 汇率变动时刷新预计损益（若当前有持仓）
	if not _current_left_code.is_empty() and not _current_right_code.is_empty():
		_refresh_position_labels()

func _on_account_changed(_snapshot: Dictionary) -> void:
	# 账户变化（开/平仓）时刷新持仓信息
	if not _current_left_code.is_empty() and not _current_right_code.is_empty():
		_refresh_position_labels()

func _on_timeframe_button_pressed(button_name: String) -> void:
	_selected_timeframe_button = button_name
	_apply_timeframe_button_styles()
	if _chart_layer != null and _chart_layer.has_method("设置周期"):
		_chart_layer.call("设置周期", button_name)

## ===== K线图层设置 =====

func _setup_kline_chart() -> void:
	_chart_layer = KLineChartLayerScript.new() as FxKLineChartLayerV3
	_chart_layer.name = "KLineChartLayer"
	_chart_layer.默认货币代码 = 默认显示货币代码
	_chart_layer.右侧刻度数量 = 右侧刻度数量
	_chart_layer.下方刻度数量 = 下方刻度数量
	_chart_layer.分钟间隔分钟 = 分钟间隔分钟
	_chart_layer.小时间隔小时 = 小时间隔小时
	_chart_layer.天间隔天 = 天间隔天
	_chart_layer.周间隔天 = 周间隔天
	_chart_layer.月间隔月 = 月间隔月
	_chart_layer.年间隔年 = 年间隔年
	_chart_layer.坐标字体大小 = 坐标字体大小
	_chart_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chart_layer)
	_chart_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chart_layer.offset_left = 0.0
	_chart_layer.offset_top = 0.0
	_chart_layer.offset_right = 0.0
	_chart_layer.offset_bottom = 0.0

func _connect_timeframe_buttons() -> void:
	for button_name in ["一分钟", "一小时", "一天", "一周", "一月", "一年"]:
		var button: Button = _find_descendant_by_name(self, button_name) as Button
		if button == null:
			continue
		_timeframe_buttons[button_name] = button
		if _timeframe_normal_style == null:
			_timeframe_normal_style = button.get_theme_stylebox("normal")
			_timeframe_hover_style = button.get_theme_stylebox("hover")
			_timeframe_selected_style = button.get_theme_stylebox("pressed")
			var label: Label = button.get_node_or_null("Label") as Label
			if label != null:
				_timeframe_label_normal_color = label.get_theme_color("font_color")
		var callback: Callable = _on_timeframe_button_pressed.bind(button_name)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)
	_apply_timeframe_button_styles()

func _apply_timeframe_button_styles() -> void:
	for button_name in _timeframe_buttons.keys():
		var button: Button = _timeframe_buttons[button_name] as Button
		if button == null:
			continue
		var is_selected: bool = button_name == _selected_timeframe_button
		button.add_theme_stylebox_override("normal", _timeframe_selected_style if is_selected else _timeframe_normal_style)
		button.add_theme_stylebox_override("pressed", _timeframe_selected_style if is_selected else _timeframe_hover_style)
		button.add_theme_stylebox_override("hover", _timeframe_selected_style if is_selected else _timeframe_hover_style)
		var label: Label = button.get_node_or_null("Label") as Label
		if label != null:
			label.add_theme_color_override("font_color", _timeframe_label_selected_color if is_selected else _timeframe_label_normal_color)

## ===== 工具 =====

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
