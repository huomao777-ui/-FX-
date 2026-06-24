extends Panel
class_name FxOpenAccountPanelController

const OPEN_TEXT_COLOR := Color(0.97, 0.82, 0.36, 1.0)
const NORMAL_TEXT_COLOR := Color(0.96, 0.98, 1.0, 1.0)
const YEAR_DAYS := 365.0
const OPEN_PANEL_Z_INDEX := 300

@export var 界面配置路径: String = "res://资源/数据/市场/fx_ui_config.json"
@export var 交易配置路径: String = "res://资源/数据/交易/trading_config.json"
@export var 选中按钮底色: Color = Color(0.86, 0.67, 0.23, 0.98)
@export var 选中按钮边框色: Color = Color(0.99, 0.88, 0.55, 1.0)
@export var 选中按钮文字色: Color = Color(0.18, 0.44, 0.78, 1.0)

var _slot_owner: Node = null
var _slot: Dictionary = {}
var _currency_catalog: Dictionary = {}
var _currency_icon_textures: Dictionary = {}
var _open_panel_config: Dictionary = {}
var _trading_config: Dictionary = {}
var _selected_lots: float = 1.0
var _selected_leverage: int = 10
var _selected_direction_text: String = "做多"
var _confirm_panel: Panel = null
var _trading_system: Node = null
var _button_base_styles: Dictionary = {}

func _ready() -> void:
	# 开户面板是浮层，必须压过货币框的选中/左滑行，避免当前选中的币对盖住弹窗。
	z_as_relative = false
	z_index = OPEN_PANEL_Z_INDEX
	_load_config()
	_cache_currency_icons_from_scene()
	_cache_nodes()
	_connect_controls()
	visible = false
	if _confirm_panel != null:
		_confirm_panel.z_as_relative = false
		_confirm_panel.z_index = OPEN_PANEL_Z_INDEX + 1
		_confirm_panel.visible = false
	_refresh_content()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if get_global_rect().has_point(mouse_event.global_position):
		return
	if _confirm_panel != null and _confirm_panel.visible and _confirm_panel.get_global_rect().has_point(mouse_event.global_position):
		return
	close_panel()
	get_viewport().set_input_as_handled()

func open_for_slot(slot: Dictionary, slot_owner: Node) -> void:
	_slot = slot.duplicate(true)
	_slot_owner = slot_owner
	z_as_relative = false
	z_index = OPEN_PANEL_Z_INDEX
	visible = true
	if _confirm_panel != null:
		_confirm_panel.z_as_relative = false
		_confirm_panel.z_index = OPEN_PANEL_Z_INDEX + 1
		_confirm_panel.visible = true
	_refresh_content()

func close_panel() -> void:
	visible = false
	if _confirm_panel != null:
		_confirm_panel.visible = false

func _load_config() -> void:
	_currency_catalog.clear()
	var file: FileAccess = FileAccess.open(界面配置路径, FileAccess.READ)
	if file == null:
		_load_trading_config()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_load_trading_config()
		return
	var config: Dictionary = parsed as Dictionary
	_open_panel_config = (config.get("open_panel", {}) as Dictionary).duplicate(true)
	_selected_lots = float(_open_panel_config.get("default_lots", 1.0))
	_selected_leverage = int(_open_panel_config.get("default_leverage", 10))
	for entry in config.get("currencies", []) as Array:
		if entry is Dictionary:
			var item: Dictionary = entry as Dictionary
			_currency_catalog[str(item.get("code", ""))] = item
	_load_trading_config()

func _load_trading_config() -> void:
	_trading_config.clear()
	var file: FileAccess = FileAccess.open(交易配置路径, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_trading_config = (parsed as Dictionary).duplicate(true)

func _cache_nodes() -> void:
	var app_root: Node = get_parent()
	_confirm_panel = _find_descendant_by_name(app_root, "确认开仓") as Panel
	_trading_system = get_node_or_null("/root/GameDataManager/TradingSystem")

func _connect_controls() -> void:
	var slider: HSlider = _find_descendant_by_name(self, "手数滑块") as HSlider
	if slider != null:
		slider.value = _selected_lots
		if not slider.value_changed.is_connected(_on_lots_slider_changed):
			slider.value_changed.connect(_on_lots_slider_changed)
	var minus_button: Button = _find_descendant_by_name(self, "减号按钮") as Button
	if minus_button != null and not minus_button.pressed.is_connected(_on_lot_minus_pressed):
		minus_button.pressed.connect(_on_lot_minus_pressed)
	var plus_button: Button = _find_descendant_by_name(self, "加号按钮") as Button
	if plus_button != null and not plus_button.pressed.is_connected(_on_lot_plus_pressed):
		plus_button.pressed.connect(_on_lot_plus_pressed)
	var long_button: Button = _find_descendant_by_name(self, "做多") as Button
	if long_button != null and not long_button.pressed.is_connected(_on_direction_long_pressed):
		long_button.pressed.connect(_on_direction_long_pressed)
	var short_button: Button = _find_descendant_by_name(self, "做空") as Button
	if short_button != null and not short_button.pressed.is_connected(_on_direction_short_pressed):
		short_button.pressed.connect(_on_direction_short_pressed)
	for leverage in [1, 2, 5, 10, 25, 50]:
		var button: Button = _find_descendant_by_name(self, str(leverage) + "倍") as Button
		if button != null:
			var callback: Callable = _on_leverage_pressed.bind(leverage)
			if not button.pressed.is_connected(callback):
				button.pressed.connect(callback)
	var confirm_button: BaseButton = _find_first_button(_confirm_panel)
	if confirm_button != null and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)

func _refresh_content() -> void:
	var left_code: String = str(_slot.get("left_code", "XMY"))
	var right_code: String = str(_slot.get("right_code", "USD"))
	_set_currency_card(_find_descendant_by_name(self, "左侧货币") as Panel, left_code)
	_set_currency_card(_find_descendant_by_name(self, "右侧货币") as Panel, right_code)
	var subtitle: Label = _find_descendant_by_name(self, "副标题") as Label
	if subtitle != null:
		subtitle.text = left_code + "/" + right_code
	var left_rate_label: Label = _find_descendant_by_name(self, "左侧利息") as Label
	if left_rate_label != null:
		left_rate_label.text = left_code + " 年化利率: %.2f%%" % (_get_currency_annual_rate(left_code) * 100.0)
	var right_rate_label: Label = _find_descendant_by_name(self, "右侧利息") as Label
	if right_rate_label != null:
		right_rate_label.text = right_code + " 年化利率: %.2f%%" % (_get_currency_annual_rate(right_code) * 100.0)
	var diff_label: Label = _find_descendant_by_name(self, "隔夜利差") as Label
	if diff_label != null:
		diff_label.text = "隔夜利差合计(每夜): %s 熊猫元" % _format_signed_xmy(_calculate_overnight_xmy(left_code, right_code))
	_refresh_numbers()
	_refresh_button_states()

func _refresh_numbers() -> void:
	var lots_label: Label = _find_descendant_by_name(self, "手数值") as Label
	if lots_label != null:
		lots_label.text = "当前手数: %.2f 手" % _selected_lots
	var margin_label: Label = _find_descendant_by_name(self, "预付保证金") as Label
	if margin_label != null:
		margin_label.text = "预付保证金: %s XMY" % _format_number(_calculate_margin_xmy())
	var liquidation_label: Label = _find_descendant_by_name(self, "强平线") as Label
	if liquidation_label != null:
		var liquidation_rate: float = _estimate_liquidation_rate()
		liquidation_label.text = "强制平仓线: %s" % _format_rate_or_placeholder(liquidation_rate)
	var spread_rate_label: Label = _find_descendant_by_name(self, "点差率") as Label
	if spread_rate_label != null:
		spread_rate_label.text = "点差率: %.2f%%" % (_get_platform_spread_rate() * 100.0)
	var spread_cost_label: Label = _find_descendant_by_name(self, "点差成本") as Label
	if spread_cost_label != null:
		spread_cost_label.text = "预计点差成本: %s XMY" % _format_number(_calculate_spread_cost_xmy())

func _set_currency_card(panel: Panel, code: String) -> void:
	if panel == null:
		return
	var data: Dictionary = _currency_catalog.get(code, {}) as Dictionary
	var code_label: Label = _find_descendant_by_name(panel, "简称") as Label
	var name_label: Label = _find_descendant_by_name(panel, "名称") as Label
	var icon_rect: TextureRect = _find_descendant_by_name(panel, "图标") as TextureRect
	if code_label != null:
		code_label.text = code
	if name_label != null:
		name_label.text = str(data.get("display_name", code))
	if icon_rect != null and _currency_icon_textures.has(code):
		icon_rect.texture = _currency_icon_textures[code] as Texture2D
	_apply_currency_panel_color(panel, data)

func _cache_currency_icons_from_scene() -> void:
	# 开户面板图标跟随币种变化，图标资源从场景已有货币按钮/贴图采样，避免代码写死贴图路径。
	_currency_icon_textures.clear()
	var app_root: Node = get_parent()
	for code in _currency_catalog.keys():
		var sprite: Sprite2D = _find_descendant_by_name(app_root, str(code)) as Sprite2D
		if sprite != null and sprite.texture != null:
			_currency_icon_textures[str(code)] = sprite.texture

func _apply_currency_panel_color(panel: Panel, data: Dictionary) -> void:
	# 背景色读取 fx_ui_config.json 的 panel_color，后续调色只改配置文件。
	var color_values: Array = data.get("panel_color", []) as Array
	if color_values.size() < 3:
		return
	var panel_color := Color(
		float(color_values[0]),
		float(color_values[1]),
		float(color_values[2]),
		float(color_values[3]) if color_values.size() > 3 else 0.95
	)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var base_style: StyleBox = panel.get_theme_stylebox("panel")
	if base_style is StyleBoxFlat:
		style = (base_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = panel_color
	panel.add_theme_stylebox_override("panel", style)

func _refresh_button_states() -> void:
	_set_button_selected(_find_descendant_by_name(self, "做多") as Button, _selected_direction_text == "做多")
	_set_button_selected(_find_descendant_by_name(self, "做空") as Button, _selected_direction_text == "做空")
	for leverage in [1, 2, 5, 10, 25, 50]:
		_set_button_selected(_find_descendant_by_name(self, str(leverage) + "倍") as Button, _selected_leverage == leverage)

func _set_button_selected(button: Button, selected: bool) -> void:
	if button == null:
		return
	_cache_button_styles(button)
	button.add_theme_color_override("font_color", 选中按钮文字色 if selected else NORMAL_TEXT_COLOR)
	var style_key: String = str(button.get_path())
	var base_styles: Dictionary = _button_base_styles.get(style_key, {}) as Dictionary
	var normal_style: StyleBoxFlat = _make_button_style(base_styles.get("normal", null) as StyleBox, selected)
	var hover_style: StyleBoxFlat = _make_button_style(base_styles.get("hover", null) as StyleBox, selected)
	var pressed_style: StyleBoxFlat = _make_button_style(base_styles.get("pressed", null) as StyleBox, selected)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)

func _cache_button_styles(button: Button) -> void:
	var style_key: String = str(button.get_path())
	if _button_base_styles.has(style_key):
		return
	_button_base_styles[style_key] = {
		"normal": button.get_theme_stylebox("normal"),
		"hover": button.get_theme_stylebox("hover"),
		"pressed": button.get_theme_stylebox("pressed")
	}

func _make_button_style(base_style: StyleBox, selected: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if base_style is StyleBoxFlat:
		style = (base_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	if selected:
		style.bg_color = 选中按钮底色
		style.border_color = 选中按钮边框色
		style.border_width_left = max(style.border_width_left, 2)
		style.border_width_top = max(style.border_width_top, 2)
		style.border_width_right = max(style.border_width_right, 2)
		style.border_width_bottom = max(style.border_width_bottom, 2)
		style.corner_radius_top_left = max(style.corner_radius_top_left, 14)
		style.corner_radius_top_right = max(style.corner_radius_top_right, 14)
		style.corner_radius_bottom_right = max(style.corner_radius_bottom_right, 14)
		style.corner_radius_bottom_left = max(style.corner_radius_bottom_left, 14)
	return style

func _on_lots_slider_changed(value: float) -> void:
	_set_lots(value)

func _on_lot_minus_pressed() -> void:
	_set_lots(_selected_lots - 0.01)

func _on_lot_plus_pressed() -> void:
	_set_lots(_selected_lots + 0.01)

func _set_lots(value: float) -> void:
	var lot_step: float = _get_lot_step()
	_selected_lots = maxf(snappedf(value, lot_step), lot_step)
	var slider: HSlider = _find_descendant_by_name(self, "手数滑块") as HSlider
	if slider != null and not is_equal_approx(slider.value, _selected_lots):
		slider.value = _selected_lots
	_refresh_content()

func _on_direction_long_pressed() -> void:
	_selected_direction_text = "做多"
	_refresh_content()

func _on_direction_short_pressed() -> void:
	_selected_direction_text = "做空"
	_refresh_content()

func _on_leverage_pressed(leverage: int) -> void:
	_selected_leverage = leverage
	_refresh_content()

func _on_confirm_pressed() -> void:
	if _slot_owner != null and _slot_owner.has_method("mark_selected_slot_open"):
		_slot_owner.call("mark_selected_slot_open", {
			"mock_lots": _selected_lots,
			"mock_leverage": _selected_leverage,
			"direction_text": _selected_direction_text,
			"liquidation_rate": _estimate_liquidation_rate(),
			"mock_margin_xmy": _calculate_margin_xmy(),
			"mock_spread_cost_xmy": _calculate_spread_cost_xmy(),
			"mock_overnight_interest_text": _format_signed_xmy(_calculate_overnight_xmy(
				str(_slot.get("left_code", "")),
				str(_slot.get("right_code", ""))
			)) + "元"
		})
	close_panel()

func _estimate_liquidation_rate() -> float:
	# 优先使用 TradingSystem 的账户快照/强平阈值；拿不到时才回退到近似估算，避免UI和交易系统脱节。
	var left_code: String = str(_slot.get("left_code", ""))
	var right_code: String = str(_slot.get("right_code", ""))
	var current_rate: float = _get_pair_rate(left_code, right_code)
	if current_rate <= 0.0:
		current_rate = float(_slot.get("mock_entry_rate", 0.0))
	if current_rate <= 0.0:
		return 0.0
	var account_snapshot: Dictionary = _get_account_snapshot()
	if account_snapshot.is_empty():
		return current_rate * (0.82 if _selected_direction_text == "做多" else 1.18)
	var current_equity: float = float(account_snapshot.get("equity", 0.0))
	var current_used_margin: float = float(account_snapshot.get("used_margin", 0.0))
	var added_margin: float = _calculate_margin_xmy()
	var target_equity: float = _get_period_liquidation_ratio() * (current_used_margin + added_margin)
	var pnl_needed: float = target_equity - current_equity
	var notional_xmy: float = _calculate_notional_xmy()
	if current_equity <= 0.0 or notional_xmy <= 0.0:
		return current_rate * (0.82 if _selected_direction_text == "做多" else 1.18)
	var rate_shift_ratio: float = pnl_needed / notional_xmy
	var liquidation_rate: float = current_rate
	if _selected_direction_text == "做多":
		liquidation_rate = current_rate * (1.0 + rate_shift_ratio)
	else:
		liquidation_rate = current_rate * (1.0 - rate_shift_ratio)
	return liquidation_rate if liquidation_rate > 0.0 else 0.0

func _calculate_margin_xmy() -> float:
	return _calculate_notional_xmy() / float(max(_selected_leverage, 1))

func _calculate_notional_xmy() -> float:
	return _selected_lots * _get_lot_value_xmy()

func _calculate_spread_cost_xmy() -> float:
	return _calculate_notional_xmy() * _get_platform_spread_rate()

func _get_lot_value_xmy() -> float:
	var contract_rule: Dictionary = _get_trading_config_section("contract")
	return float(contract_rule.get("lot_value_xmy", contract_rule.get("lot_value_rmb", 100000.0)))

func _get_lot_step() -> float:
	var contract_rule: Dictionary = _get_trading_config_section("contract")
	return max(float(contract_rule.get("min_lot", 0.01)), 0.01)

func _get_platform_spread_rate() -> float:
	var platform_rule: Dictionary = _get_platform_rule()
	return float(platform_rule.get("spread_rate", 0.0005))

func _get_platform_rule() -> Dictionary:
	var platforms: Dictionary = _get_trading_config_section("platforms")
	var platform_name: String = str(_open_panel_config.get("platform", "国内"))
	return platforms.get(platform_name, {}) as Dictionary

func _get_trading_config_section(section_name: String) -> Dictionary:
	return _trading_config.get(section_name, {}) as Dictionary

func _get_period_liquidation_ratio() -> float:
	if _trading_system != null and _trading_system.has_method("获取时段强平线"):
		return float(_trading_system.call("获取时段强平线"))
	var margin_rule: Dictionary = _get_trading_config_section("margin")
	return float(margin_rule.get("period_liquidation_ratio", 0.50))

func _get_account_snapshot() -> Dictionary:
	if _trading_system != null and _trading_system.has_method("获取账户快照"):
		return _trading_system.call("获取账户快照") as Dictionary
	return {}

func _get_pair_rate(left_code: String, right_code: String) -> float:
	var left_rate: float = _get_rate_against_base(left_code)
	var right_rate: float = _get_rate_against_base(right_code)
	if left_rate <= 0.0 or right_rate <= 0.0:
		return _get_default_pair_rate(left_code, right_code)
	return right_rate / left_rate

func _get_rate_against_base(currency_code: String) -> float:
	if currency_code == "XMY":
		return 1.0
	var market_engine: Node = get_node_or_null("/root/GameDataManager/MarketEngine")
	if market_engine != null and market_engine.has_method("获取汇率"):
		var rate: float = float(market_engine.call("获取汇率", currency_code))
		if rate > 0.0:
			return rate
	return _get_default_rate_against_base(currency_code)

func _get_default_pair_rate(left_code: String, right_code: String) -> float:
	var left_rate: float = _get_default_rate_against_base(left_code)
	var right_rate: float = _get_default_rate_against_base(right_code)
	if left_rate <= 0.0 or right_rate <= 0.0:
		return 0.0
	return right_rate / left_rate

func _get_default_rate_against_base(currency_code: String) -> float:
	# 只作为沙盒/编辑器里没有 MarketEngine 时的显示回退；运行时优先使用真实行情系统。
	match currency_code:
		"XMY":
			return 1.0
		"YHB":
			return 20.0
		"USD":
			return 0.14
		"EUR":
			return 0.13
		"GBP":
			return 0.11
		"DSB":
			return 0.21
		"FYB":
			return 0.19
		_:
			return 0.0

func _calculate_overnight_xmy(left_code: String, right_code: String) -> float:
	# 做多=买入左侧货币、卖出右侧货币；隔夜利差按“持有货币利率 - 融资货币利率”计算。
	var long_side_diff: float = _get_currency_annual_rate(left_code) - _get_currency_annual_rate(right_code)
	var direction_sign: float = 1.0 if _selected_direction_text == "做多" else -1.0
	return long_side_diff * direction_sign / YEAR_DAYS * _calculate_notional_xmy()

func _get_currency_annual_rate(currency_code: String) -> float:
	var data: Dictionary = _currency_catalog.get(currency_code, {}) as Dictionary
	return float(data.get("annual_rate", 0.0))

func _format_signed_xmy(value: float) -> String:
	if absf(value) < 0.01:
		return "--"
	return ("%+.2f" % value)

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

func _format_rate_or_placeholder(rate: float) -> String:
	return "%.4f" % rate if rate > 0.0 else "--"

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

func _find_first_button(root: Node) -> BaseButton:
	if root == null:
		return null
	if root is BaseButton:
		return root as BaseButton
	for child in root.get_children():
		var found: BaseButton = _find_first_button(child)
		if found != null:
			return found
	return null
