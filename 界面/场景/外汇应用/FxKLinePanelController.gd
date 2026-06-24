extends Panel
class_name FxKLinePanelController

const KLineChartLayerScript = preload("res://界面/场景/外汇应用/FxKLineChartLayer.gd")

@export var 默认显示货币代码: String = "USD"

var _chart_layer: FxKLineChartLayer = null
var _pair_label: Label = null
var _market_engine: Node = null

func _ready() -> void:
	_pair_label = _find_descendant_by_name(self, "货币种类") as Label
	_market_engine = get_node_or_null("/root/GameDataManager/MarketEngine")
	_setup_kline_chart()
	_connect_timeframe_buttons()
	_connect_market_signals()

func show_pair(left_code: String, right_code: String, pair_text: String = "") -> void:
	if left_code.is_empty() or right_code.is_empty():
		clear_chart()
		return
	var display_text: String = pair_text if not pair_text.is_empty() else left_code + "/" + right_code
	if _pair_label != null:
		_pair_label.text = display_text
	if _chart_layer != null and _chart_layer.has_method("切换货币对"):
		_chart_layer.call("切换货币对", left_code, right_code, display_text)

func clear_chart() -> void:
	if _pair_label != null:
		_pair_label.text = "XXX/XXX"
	# 空白/未配完整货币框仍保留坐标轴与时间轴，只清掉K线与柱状图。
	if _chart_layer != null and _chart_layer.has_method("切换货币对"):
		_chart_layer.call("切换货币对", "", "", "")

func set_liquidation_line(price: float, label_text: String = "") -> void:
	# 强平线只传给K线层；右侧价格轴由 FxKLineChartLayer 根据K线与强平线动态扩缩。
	if _chart_layer != null and _chart_layer.has_method("设置强平线"):
		_chart_layer.call("设置强平线", price, label_text)

func clear_liquidation_line() -> void:
	set_liquidation_line(0.0, "")

func _setup_kline_chart() -> void:
	_chart_layer = KLineChartLayerScript.new() as FxKLineChartLayer
	_chart_layer.name = "KLineChartLayer"
	_chart_layer.默认货币代码 = 默认显示货币代码
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
		var callback: Callable = _on_timeframe_button_pressed.bind(button_name)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)

func _connect_market_signals() -> void:
	if _market_engine == null or not _market_engine.has_signal("汇率变动"):
		return
	var callback := Callable(self, "_on_market_rate_changed")
	if not _market_engine.is_connected("汇率变动", callback):
		_market_engine.connect("汇率变动", callback)

func _on_timeframe_button_pressed(button_name: String) -> void:
	# 分时/日/周/月按钮沿用K线层原接口，避免按钮只变样式但图表不切换。
	if _chart_layer != null and _chart_layer.has_method("设置周期"):
		_chart_layer.call("设置周期", button_name)

func _on_market_rate_changed(_currency_code: String, _rate_snapshot: Dictionary) -> void:
	# FxKLineChartLayer 自己监听行情信号，这里保留入口，后续如需同步标题/强平线可扩展。
	pass

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
