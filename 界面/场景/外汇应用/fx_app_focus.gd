extends Control

const KLineChartLayerScript = preload("res://界面/场景/外汇应用/FxKLineChartLayer.gd")

const OPEN_TEXT_COLOR := Color(0.97, 0.82, 0.36, 1.0)
const NORMAL_TEXT_COLOR := Color(0.98, 0.98, 0.98, 1.0)
const EMPTY_TEXT_COLOR := Color(0.72, 0.76, 0.84, 1.0)
const SELECTED_BORDER_COLOR := Color(0.34, 0.83, 1.0, 1.0)
const IDLE_BORDER_COLOR := Color(0.12, 0.16, 0.22, 0.92)
const DELETE_TRIGGER_RATIO := 0.40
const DELETE_REVEAL_RATIO := 0.20
const DRAG_START_DISTANCE := 8.0
const ROW_WRAPPER_PREFIX := "货币框行_"
const DELETE_BUTTON_NAME := "减号按钮"
const HEADER_SNAP_RATIO := 0.35
const SLOT_LIST_BOTTOM_PADDING := 8.0
const ACTION_PANEL_Z_INDEX := 20

@export var 默认显示货币代码: String = "USD"
@export var 进入时启用汇率专注时间: bool = true
@export var 进入时启用盯盘耗电: bool = true
@export var 离开时恢复普通状态: bool = true
@export var 界面配置路径: String = "res://资源/数据/市场/fx_ui_config.json"

var _chart_layer: FxKLineChartLayer = null
var _market_engine: Node = null
var _trading_system: Node = null

var _chart_canvas: Control = null
var _chart_pair_label: Label = null
var _position_panel: Panel = null
var _adjust_position_panel: Panel = null
var _confirm_open_panel: Panel = null
var _currency_picker_panel: Panel = null
var _currency_root: Control = null
var _currency_background_panel: Panel = null
var _slot_header_panel: Panel = null
var _slot_scroll_container: ScrollContainer = null
var _slot_list_container: Control = null
var _slot_template_panel: Panel = null
var _slot_template_prototype: Panel = null
var _delete_button_prototype: BaseButton = null

var _selected_slot_index: int = 0
var _pending_currency_slot_index: int = -1
var _pending_currency_side: String = ""
var _dynamic_slot_counter: int = 2

var _base_currency_code: String = "XMY"
var _currency_catalog: Dictionary = {}
var _pair_slots: Array[Dictionary] = []
var _panel_base_styles: Dictionary = {}
var _row_wrappers: Dictionary = {}
var _delete_buttons: Dictionary = {}
var _delete_button_layouts: Dictionary = {}
var _slide_offsets: Dictionary = {}
var _drag_contexts: Dictionary = {}
var _header_rest_top: float = 0.0
var _header_snap_top: float = 0.0
var _header_height: float = 0.0
var _header_to_list_gap: float = 0.0
var _list_bottom_rest: float = 0.0
var _header_dragging: bool = false
var _header_drag_start_mouse_y: float = 0.0
var _header_drag_start_top: float = 0.0
var _background_top_rest: float = 0.0
var _background_bottom_rest: float = 0.0
var _background_to_header_gap: float = 0.0

func _ready() -> void:
	_load_ui_config()
	_cache_nodes()
	_setup_kline_chart()
	_connect_timeframe_buttons()
	_connect_market_signals()
	_connect_slot_panels()
	_connect_currency_picker_buttons()
	_connect_header_drag()
	_apply_header_layout(_header_rest_top)
	_ensure_trailing_placeholder_slot()
	_refresh_slot_container_size()
	_select_slot(clampi(_find_first_existing_slot(), 0, max(_pair_slots.size() - 1, 0)))
	if not _has_game_data_manager():
		return
	if 进入时启用汇率专注时间 and GameDataManager.时间 != null:
		GameDataManager.时间.进入汇率专注时间流动()
	if 进入时启用盯盘耗电 and GameDataManager.手机 != null:
		GameDataManager.手机.进入汇率盯盘使用状态()

func _exit_tree() -> void:
	if not 离开时恢复普通状态:
		return
	if not _has_game_data_manager():
		return
	if GameDataManager.时间 != null:
		GameDataManager.时间.进入普通时间流动()
	if GameDataManager.手机 != null:
		GameDataManager.手机.进入普通手机使用状态()

func _unhandled_input(event: InputEvent) -> void:
	if _header_dragging:
		if event is InputEventMouseMotion:
			var drag_motion := event as InputEventMouseMotion
			_update_header_drag(drag_motion.global_position.y)
		elif event is InputEventMouseButton:
			var drag_button := event as InputEventMouseButton
			if drag_button.button_index == MOUSE_BUTTON_LEFT and not drag_button.pressed:
				_header_dragging = false
				_finish_header_drag()
				get_viewport().set_input_as_handled()
				return
	if _currency_picker_panel == null or not _currency_picker_panel.visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var picker_rect := Rect2(_currency_picker_panel.global_position, _currency_picker_panel.size)
	if picker_rect.has_point(mouse_event.global_position):
		return
	_close_currency_picker()

func _load_ui_config() -> void:
	_currency_catalog.clear()
	_pair_slots.clear()
	var file: FileAccess = FileAccess.open(界面配置路径, FileAccess.READ)
	if file == null:
		push_warning("fx_app_focus: 无法打开界面配置 " + 界面配置路径)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("fx_app_focus: 界面配置 JSON 格式错误 " + 界面配置路径)
		return
	var config: Dictionary = parsed as Dictionary
	_base_currency_code = str(config.get("base_currency_code", "XMY"))
	默认显示货币代码 = str(config.get("default_chart_currency_code", 默认显示货币代码))

	for entry in config.get("currencies", []) as Array:
		if not (entry is Dictionary):
			continue
		var item: Dictionary = (entry as Dictionary).duplicate(true)
		var code: String = str(item.get("code", ""))
		if code.is_empty():
			continue
		_currency_catalog[code] = item

	for entry in config.get("pair_slots", []) as Array:
		if not (entry is Dictionary):
			continue
		var slot: Dictionary = (entry as Dictionary).duplicate(true)
		slot["panel_name"] = str(slot.get("panel_name", ""))
		slot["left_code"] = str(slot.get("left_code", ""))
		slot["right_code"] = str(slot.get("right_code", ""))
		slot["configured"] = bool(slot.get("configured", false))
		_pair_slots.append(slot)

func _cache_nodes() -> void:
	_chart_canvas = get_node_or_null("手机进入状态/k线图画布") as Control
	_chart_pair_label = _find_descendant_by_name(_chart_canvas, "货币种类") as Label
	_position_panel = get_node_or_null("手机进入状态/当前持仓订单") as Panel
	_adjust_position_panel = get_node_or_null("手机进入状态/减仓补仓") as Panel
	_confirm_open_panel = get_node_or_null("手机进入状态/确认开仓") as Panel
	_currency_picker_panel = get_node_or_null("手机进入状态/货币选择") as Panel
	_currency_root = get_node_or_null("手机进入状态/货币种类") as Control
	_currency_background_panel = get_node_or_null("手机进入状态/货币种类/货币背景") as Panel
	_slot_header_panel = get_node_or_null("手机进入状态/货币种类/上方遮挡") as Panel
	_slot_scroll_container = get_node_or_null("手机进入状态/货币种类/滑动容器") as ScrollContainer
	_slot_list_container = get_node_or_null("手机进入状态/货币种类/滑动容器/排列容器") as Control
	_slot_template_panel = get_node_or_null("手机进入状态/货币种类/滑动容器/排列容器/货币种类框2") as Panel
	if _slot_template_panel != null:
		_slot_template_prototype = _slot_template_panel.duplicate(15) as Panel
		var template_delete_button: BaseButton = _find_descendant_by_name(_slot_template_panel, DELETE_BUTTON_NAME) as BaseButton
		if template_delete_button != null:
			_delete_button_prototype = template_delete_button.duplicate(15) as BaseButton
	_dynamic_slot_counter = _detect_existing_slot_count()
	_market_engine = get_node_or_null("/root/GameDataManager/MarketEngine")
	_trading_system = get_node_or_null("/root/GameDataManager/TradingSystem")
	if _currency_picker_panel != null:
		_currency_picker_panel.visible = false
		_currency_picker_panel.z_index = 200
	if _adjust_position_panel != null:
		_adjust_position_panel.z_index = ACTION_PANEL_Z_INDEX
	if _confirm_open_panel != null:
		_confirm_open_panel.z_index = ACTION_PANEL_Z_INDEX
	_cache_header_layout_metrics()

func _setup_kline_chart() -> void:
	if _chart_canvas == null:
		push_warning("fx_app_focus: 未找到k线图画布")
		return
	_chart_layer = KLineChartLayerScript.new() as FxKLineChartLayer
	_chart_layer.name = "KLineChartLayer"
	_chart_layer.默认货币代码 = 默认显示货币代码
	_chart_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chart_canvas.add_child(_chart_layer)
	_chart_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chart_layer.offset_left = 0.0
	_chart_layer.offset_top = 0.0
	_chart_layer.offset_right = 0.0
	_chart_layer.offset_bottom = 0.0

func _connect_timeframe_buttons() -> void:
	if _chart_canvas == null:
		return
	for button_name in ["一分钟", "一小时", "一天", "一周", "一月", "一年"]:
		var button: Button = _find_descendant_by_name(_chart_canvas, button_name) as Button
		if button == null:
			continue
		var callback: Callable = _on_timeframe_button_pressed.bind(button_name)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)

func _connect_market_signals() -> void:
	if _market_engine != null and _market_engine.has_signal("汇率变动"):
		var market_callback := Callable(self, "_on_market_rate_changed")
		if not _market_engine.is_connected("汇率变动", market_callback):
			_market_engine.connect("汇率变动", market_callback)
	if _trading_system != null and _trading_system.has_signal("账户变化"):
		var account_callback := Callable(self, "_on_account_changed")
		if not _trading_system.is_connected("账户变化", account_callback):
			_trading_system.connect("账户变化", account_callback)

func _connect_slot_panels() -> void:
	for slot_index in range(_pair_slots.size()):
		_connect_single_slot_panel(slot_index)

func _connect_currency_picker_buttons() -> void:
	if _currency_picker_panel == null:
		return
	for currency_code in _currency_catalog.keys():
		var display_name: String = str((_currency_catalog[currency_code] as Dictionary).get("display_name", ""))
		if display_name.is_empty():
			continue
		var button: BaseButton = _find_descendant_by_name(_currency_picker_panel, display_name) as BaseButton
		if button == null:
			continue
		var callback: Callable = _on_currency_option_pressed.bind(currency_code)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)
	var confirm_button: BaseButton = _find_descendant_by_name(_currency_picker_panel, "确认选择") as BaseButton
	if confirm_button != null and not confirm_button.pressed.is_connected(_close_currency_picker):
		confirm_button.pressed.connect(_close_currency_picker)

func _connect_header_drag() -> void:
	if _slot_header_panel == null:
		return
	_set_display_controls_ignore_mouse(_slot_header_panel)
	_slot_header_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var callback := Callable(self, "_on_header_panel_gui_input")
	if not _slot_header_panel.gui_input.is_connected(callback):
		_slot_header_panel.gui_input.connect(callback)

func _on_header_panel_gui_input(event: InputEvent) -> void:
	if _slot_header_panel == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_header_dragging = true
			_header_drag_start_mouse_y = mouse_event.global_position.y
			_header_drag_start_top = _slot_header_panel.position.y
			return
		if _header_dragging:
			_header_dragging = false
			_finish_header_drag()
		return
	if event is InputEventMouseMotion and _header_dragging:
		var motion_event := event as InputEventMouseMotion
		_update_header_drag(motion_event.global_position.y)

func _update_header_drag(mouse_y: float) -> void:
	var dragged_top: float = _header_drag_start_top + (mouse_y - _header_drag_start_mouse_y)
	var clamped_top: float = clampf(dragged_top, _header_snap_top, _header_rest_top)
	_apply_header_layout(clamped_top)

func _finish_header_drag() -> void:
	if _slot_header_panel == null:
		return
	var current_top: float = _slot_header_panel.position.y
	var travel_distance: float = max(_header_rest_top - _header_snap_top, 0.001)
	var moved_ratio: float = (_header_rest_top - current_top) / travel_distance
	var target_top: float = _header_snap_top if moved_ratio >= HEADER_SNAP_RATIO else _header_rest_top
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_apply_header_layout, current_top, target_top, 0.22)

func _cache_header_layout_metrics() -> void:
	if _currency_root == null or _slot_header_panel == null or _slot_scroll_container == null or _chart_canvas == null:
		return
	_header_rest_top = _slot_header_panel.position.y
	_header_height = _slot_header_panel.size.y
	if _currency_background_panel != null:
		_background_top_rest = _currency_background_panel.position.y
		_background_bottom_rest = _currency_background_panel.position.y + _currency_background_panel.size.y
		_background_to_header_gap = _currency_background_panel.position.y - (_header_rest_top + _header_height)
	_header_to_list_gap = _slot_scroll_container.position.y - _slot_header_panel.position.y - _header_height
	_list_bottom_rest = min(_slot_scroll_container.position.y + _slot_scroll_container.size.y, _get_slot_list_bottom_limit())
	var chart_top_local: Vector2 = _currency_root.get_global_transform().affine_inverse() * _chart_canvas.global_position
	_header_snap_top = min(_header_rest_top, chart_top_local.y)

func _apply_header_layout(header_top: float) -> void:
	if _slot_header_panel == null or _slot_scroll_container == null:
		return
	_slot_header_panel.position.y = header_top
	var next_scroll_top: float = header_top + _header_height + _header_to_list_gap
	_slot_scroll_container.position.y = next_scroll_top
	var scroll_bottom_limit: float = min(_list_bottom_rest, _get_slot_list_bottom_limit())
	_slot_scroll_container.size.y = max(scroll_bottom_limit - next_scroll_top, 60.0)
	if _currency_background_panel != null:
		var next_background_top: float = header_top + _header_height + _background_to_header_gap
		_currency_background_panel.position.y = next_background_top
		var background_bottom_limit: float = min(_background_bottom_rest, scroll_bottom_limit)
		_currency_background_panel.size.y = max(background_bottom_limit - next_background_top, 60.0)
	_refresh_slot_container_size()

func _get_slot_list_bottom_limit() -> float:
	if _currency_root == null or _slot_scroll_container == null:
		return _list_bottom_rest
	var default_bottom_limit: float = _slot_scroll_container.position.y + _slot_scroll_container.size.y
	var bottom_limit: float = INF
	for panel in [_adjust_position_panel, _confirm_open_panel]:
		if panel == null:
			continue
		var panel_top_local: float = (_currency_root.get_global_transform().affine_inverse() * panel.global_position).y
		bottom_limit = min(bottom_limit, panel_top_local - SLOT_LIST_BOTTOM_PADDING)
	if is_inf(bottom_limit):
		return default_bottom_limit
	return bottom_limit

func _on_timeframe_button_pressed(button_name: String) -> void:
	if _chart_layer == null:
		return
	_chart_layer.设置周期(button_name)

func _on_market_rate_changed(_currency_code: String, _rate_snapshot: Dictionary) -> void:
	_refresh_slot_views()
	_refresh_position_panel()

func _on_account_changed(_account_snapshot: Dictionary) -> void:
	_refresh_slot_views()
	_refresh_position_panel()

func _on_slot_panel_gui_input(event: InputEvent, panel_name: String) -> void:
	var slot_index: int = _find_slot_index_by_panel_name(panel_name)
	if slot_index < 0:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			if _currency_picker_panel != null and _currency_picker_panel.visible:
				var picker_rect := Rect2(_currency_picker_panel.global_position, _currency_picker_panel.size)
				if not picker_rect.has_point(mouse_event.global_position):
					_close_currency_picker()
				return
			_select_slot(slot_index)
			_begin_slot_drag(panel_name, mouse_event.global_position.x)
			return
		_finish_slot_drag(panel_name, mouse_event.global_position.x)
		return
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		_update_slot_drag(panel_name, motion_event.global_position.x)

func _on_left_currency_button_pressed(panel_name: String) -> void:
	var slot_index: int = _find_slot_index_by_panel_name(panel_name)
	if slot_index < 0:
		return
	_select_slot(slot_index)
	_open_currency_picker(slot_index, "left_code")

func _on_right_currency_button_pressed(panel_name: String) -> void:
	var slot_index: int = _find_slot_index_by_panel_name(panel_name)
	if slot_index < 0:
		return
	_select_slot(slot_index)
	_open_currency_picker(slot_index, "right_code")

func _on_delete_slot_pressed(panel_name: String) -> void:
	_delete_slot(panel_name)

func _open_currency_picker(slot_index: int, side_key: String) -> void:
	if _currency_picker_panel == null:
		return
	_pending_currency_slot_index = slot_index
	_pending_currency_side = side_key
	_currency_picker_panel.visible = true
	_currency_picker_panel.z_index = 200

func _close_currency_picker() -> void:
	if _currency_picker_panel == null:
		return
	_currency_picker_panel.visible = false
	_pending_currency_slot_index = -1
	_pending_currency_side = ""

func _on_currency_option_pressed(currency_code: String) -> void:
	if _pending_currency_slot_index < 0 or _pending_currency_slot_index >= _pair_slots.size():
		return
	if _pending_currency_side.is_empty():
		return
	var target_slot_index: int = _pending_currency_slot_index
	var slot: Dictionary = _pair_slots[_pending_currency_slot_index]
	var current_code: String = str(slot.get(_pending_currency_side, ""))
	if currency_code == current_code:
		slot[_pending_currency_side] = ""
		slot["configured"] = false
		_pair_slots[_pending_currency_slot_index] = slot
		_close_currency_picker()
		_after_slot_configuration_changed(target_slot_index)
		return
	var other_key: String = "right_code" if _pending_currency_side == "left_code" else "left_code"
	if currency_code == str(slot.get(other_key, "")):
		slot[other_key] = current_code
		slot[_pending_currency_side] = currency_code
		slot["configured"] = str(slot.get("left_code", "")) != "" and str(slot.get("right_code", "")) != "" and str(slot.get("left_code", "")) != str(slot.get("right_code", ""))
		_pair_slots[_pending_currency_slot_index] = slot
		_close_currency_picker()
		_after_slot_configuration_changed(target_slot_index)
		return
	slot[_pending_currency_side] = currency_code
	slot["configured"] = str(slot.get("left_code", "")) != "" and str(slot.get("right_code", "")) != "" and str(slot.get("left_code", "")) != str(slot.get("right_code", ""))
	_pair_slots[_pending_currency_slot_index] = slot
	_close_currency_picker()
	_after_slot_configuration_changed(target_slot_index)

func _select_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _pair_slots.size():
		return
	_selected_slot_index = slot_index
	_refresh_chart_for_selected_slot()
	_refresh_slot_views()
	_refresh_position_panel()

func _sync_chart_to_slot(slot: Dictionary) -> void:
	var pair_label: String = _get_pair_label(slot)
	if _chart_pair_label != null:
		_chart_pair_label.text = pair_label
	if _chart_layer != null:
		_chart_layer.切换货币对(str(slot.get("left_code", "")), str(slot.get("right_code", "")), pair_label)

func _clear_chart_display() -> void:
	if _chart_pair_label != null:
		_chart_pair_label.text = "XXX/XXX"
	if _chart_layer != null:
		_chart_layer.切换货币对("", "", "")

func _refresh_chart_for_selected_slot() -> void:
	if _selected_slot_index < 0 or _selected_slot_index >= _pair_slots.size():
		_clear_chart_display()
		return
	var slot: Dictionary = _pair_slots[_selected_slot_index]
	if bool(slot.get("configured", false)):
		_sync_chart_to_slot(slot)
	else:
		_clear_chart_display()

func _after_slot_configuration_changed(slot_index: int) -> void:
	_ensure_trailing_placeholder_slot()
	_selected_slot_index = clampi(slot_index, 0, max(_pair_slots.size() - 1, 0))
	_refresh_chart_for_selected_slot()
	_refresh_slot_views()
	_refresh_position_panel()

func _refresh_slot_views() -> void:
	for slot_index in range(_pair_slots.size()):
		_refresh_single_slot(slot_index)

func _refresh_single_slot(slot_index: int) -> void:
	var panel: Panel = _get_slot_panel(slot_index)
	if panel == null:
		return
	var slot: Dictionary = _pair_slots[slot_index]
	var configured: bool = bool(slot.get("configured", false))
	var has_position: bool = _slot_has_open_position_display(slot)
	var is_selected: bool = slot_index == _selected_slot_index
	var pair_label: Label = _get_pair_text_label(slot_index, panel)
	var rate_label: Label = _find_descendant_by_name(panel, "实时汇率") as Label

	if pair_label != null:
		pair_label.text = _get_pair_label(slot)
		pair_label.modulate = OPEN_TEXT_COLOR if has_position else (NORMAL_TEXT_COLOR if configured else EMPTY_TEXT_COLOR)
	if rate_label != null:
		rate_label.text = _format_rate_or_placeholder(_get_slot_rate(slot))
		rate_label.modulate = OPEN_TEXT_COLOR if has_position else (NORMAL_TEXT_COLOR if configured else EMPTY_TEXT_COLOR)

	_apply_panel_style(panel, is_selected)
	_update_slot_icons(slot_index, slot)
	_update_delete_button_state(panel.name)

func _refresh_position_panel() -> void:
	if _position_panel == null or _pair_slots.is_empty():
		return
	var slot: Dictionary = _pair_slots[_selected_slot_index]
	var positions: Array[Dictionary] = _get_slot_positions(slot)
	var has_position: bool = _slot_has_open_position_display(slot)

	_refresh_action_panels(bool(slot.get("configured", false)), has_position)

	var pair_code_label: Label = _find_descendant_by_name(_position_panel, "货币种类") as Label
	var position_label: Label = _find_descendant_by_name(_position_panel, "持仓数") as Label
	var entry_label: Label = _find_descendant_by_name(_position_panel, "买入汇率") as Label
	var current_label: Label = _find_descendant_by_name(_position_panel, "当前汇率") as Label
	var leverage_label: Label = _find_descendant_by_name(_position_panel, "杠杆倍率") as Label
	var overnight_label: Label = _find_descendant_by_name(_position_panel, "隔夜利息") as Label

	if pair_code_label != null:
		pair_code_label.text = _get_pair_label(slot)

	if positions.is_empty():
		if has_position:
			if position_label != null:
				position_label.text = "当前持仓：%.2f手 已开仓" % float(slot.get("mock_lots", 1.0))
			if entry_label != null:
				entry_label.text = "买入汇率：" + _format_rate_or_placeholder(float(slot.get("mock_entry_rate", _get_slot_rate(slot))))
			if current_label != null:
				current_label.text = "当前汇率：" + _format_rate_or_placeholder(_get_slot_rate(slot))
			if leverage_label != null:
				leverage_label.text = "杠杆倍率：%d倍" % int(slot.get("mock_leverage", 1))
			if overnight_label != null:
				overnight_label.text = "隔夜利息：" + str(slot.get("mock_overnight_interest_text", "待接入"))
			return
		if position_label != null:
			position_label.text = "当前持仓：暂无"
		if entry_label != null:
			entry_label.text = "买入汇率：--"
		if current_label != null:
			current_label.text = "当前汇率：" + _format_rate_or_placeholder(_get_slot_rate(slot))
		if leverage_label != null:
			leverage_label.text = "杠杆倍率：--"
		if overnight_label != null:
			overnight_label.text = "隔夜利息：待接入"
		return

	var total_lots: float = 0.0
	var weighted_entry_sum: float = 0.0
	var current_rate: float = float(positions[0].get("current_rate", 0.0))
	var max_leverage: int = 0
	var direction_text: String = _get_direction_text(int(positions[0].get("direction", 0)))
	var mixed_direction: bool = false
	for position in positions:
		var lots: float = float(position.get("lots", 0.0))
		total_lots += lots
		weighted_entry_sum += float(position.get("entry_rate", 0.0)) * lots
		max_leverage = max(max_leverage, int(position.get("leverage", 0)))
		if _get_direction_text(int(position.get("direction", 0))) != direction_text:
			mixed_direction = true
	var avg_entry: float = weighted_entry_sum / max(total_lots, 0.000001)
	if position_label != null:
		position_label.text = "当前持仓：%.2f手 %s" % [total_lots, "双向" if mixed_direction else direction_text]
	if entry_label != null:
		entry_label.text = "买入汇率：" + _format_rate_or_placeholder(avg_entry)
	if current_label != null:
		current_label.text = "当前汇率：" + _format_rate_or_placeholder(current_rate)
	if leverage_label != null:
		leverage_label.text = "杠杆倍率：%d倍" % max(max_leverage, 1)
	if overnight_label != null:
		overnight_label.text = "隔夜利息：待接入"

func _update_slot_icons(slot_index: int, slot: Dictionary) -> void:
	if slot_index == 0:
		_set_icon_visibility(_find_descendant_by_name(_get_slot_panel(slot_index), "左侧货币图"), str(slot.get("left_code", "")), true)
		_set_icon_visibility(_find_descendant_by_name(_get_slot_panel(slot_index), "右侧货币图"), str(slot.get("right_code", "")), true)
		return
	var panel: Panel = _get_slot_panel(slot_index)
	_set_icon_visibility(_find_descendant_by_name(panel, "左侧货币选择按钮"), str(slot.get("left_code", "")), false)
	_set_icon_visibility(_find_descendant_by_name(panel, "右侧货币选择按钮"), str(slot.get("right_code", "")), false)

func _set_icon_visibility(root: Node, code: String, use_right_suffix: bool) -> void:
	if root == null:
		return
	if root is CanvasItem:
		var root_canvas: CanvasItem = root as CanvasItem
		root_canvas.modulate = Color.WHITE
		root_canvas.self_modulate = Color.WHITE
	for currency_code in _currency_catalog.keys():
		var node_name: String = currency_code
		if use_right_suffix and root.name == "右侧货币图":
			node_name = "XMY2" if currency_code == "XMY" else currency_code + "2"
		var sprite: CanvasItem = _find_descendant_by_name(root, node_name) as CanvasItem
		if sprite == null:
			continue
		sprite.visible = currency_code == code
		sprite.modulate = Color.WHITE
		sprite.self_modulate = Color.WHITE

func _apply_panel_style(panel: Panel, is_selected: bool) -> void:
	var style: StyleBoxFlat = _panel_base_styles.get(panel.get_path(), null) as StyleBoxFlat
	if style == null:
		return
	var themed_style := style.duplicate() as StyleBoxFlat
	if themed_style == null:
		return
	themed_style.border_width_left = 3
	themed_style.border_width_top = 3
	themed_style.border_width_right = 3
	themed_style.border_width_bottom = 3
	themed_style.border_color = SELECTED_BORDER_COLOR if is_selected else IDLE_BORDER_COLOR
	panel.add_theme_stylebox_override("panel", themed_style)

func _slot_has_open_position_display(slot: Dictionary) -> bool:
	return bool(slot.get("display_open_position", false)) or not _get_slot_positions(slot).is_empty()

func _get_slot_positions(slot: Dictionary) -> Array[Dictionary]:
	var positions: Array[Dictionary] = []
	if _trading_system == null or not bool(slot.get("configured", false)):
		return positions
	var account_snapshot: Dictionary = _trading_system.call("获取账户快照")
	var account_positions: Array = account_snapshot.get("positions", []) as Array
	for item in account_positions:
		if not (item is Dictionary):
			continue
		var position: Dictionary = item as Dictionary
		if _position_matches_slot(position, slot):
			positions.append(position)
	return positions

func _position_matches_slot(position: Dictionary, slot: Dictionary) -> bool:
	var left_code: String = str(slot.get("left_code", ""))
	var right_code: String = str(slot.get("right_code", ""))
	var currency_code: String = str(position.get("currency_code", ""))
	return (left_code == _base_currency_code and right_code == currency_code) or (right_code == _base_currency_code and left_code == currency_code)

func _refresh_action_panels(is_configured: bool, has_position: bool) -> void:
	if _adjust_position_panel != null:
		_adjust_position_panel.visible = has_position
	if _confirm_open_panel != null:
		_confirm_open_panel.visible = is_configured and not has_position

func _get_slot_rate(slot: Dictionary) -> float:
	var left_code: String = str(slot.get("left_code", ""))
	var right_code: String = str(slot.get("right_code", ""))
	if left_code.is_empty() or right_code.is_empty() or left_code == right_code:
		return 0.0
	var left_rate: float = _get_rate_against_base(left_code)
	var right_rate: float = _get_rate_against_base(right_code)
	if left_rate <= 0.0 or right_rate <= 0.0:
		return 0.0
	return right_rate / left_rate

func _get_rate_against_base(currency_code: String) -> float:
	if currency_code == _base_currency_code:
		return 1.0
	if _market_engine == null or not _market_engine.has_method("获取汇率"):
		return 0.0
	var rate: float = float(_market_engine.call("获取汇率", currency_code))
	return rate if rate > 0.0 else 0.0

func _get_pair_label(slot: Dictionary) -> String:
	var left_code: String = str(slot.get("left_code", ""))
	var right_code: String = str(slot.get("right_code", ""))
	if left_code.is_empty() and right_code.is_empty():
		return "XXX/XXX"
	if left_code.is_empty():
		return "XXX/" + right_code
	if right_code.is_empty():
		return left_code + "/XXX"
	return left_code + "/" + right_code

func _get_pair_text_label(slot_index: int, panel: Panel) -> Label:
	if slot_index == 0:
		return _find_descendant_by_name(panel, "货币对文字") as Label
	var pair_container: Control = _find_descendant_by_name(panel, "货币对") as Control
	if pair_container == null:
		return null
	for child in pair_container.get_children():
		if child is Label and child.name == "货币对":
			return child as Label
	return null

func _get_available_currency_codes() -> Array[String]:
	var codes: Array[String] = []
	for currency_code in _currency_catalog.keys():
		codes.append(currency_code)
	codes.sort_custom(func(a: String, b: String) -> bool:
		return int((_currency_catalog[a] as Dictionary).get("sort", 99)) < int((_currency_catalog[b] as Dictionary).get("sort", 99))
	)
	return codes

func _cache_panel_base_style(panel: Panel) -> void:
	if panel == null:
		return
	var key: NodePath = panel.get_path()
	if _panel_base_styles.has(key):
		return
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	_panel_base_styles[key] = style.duplicate() as StyleBoxFlat

func _set_display_controls_ignore_mouse(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is BaseButton:
			continue
		if child is Control:
			var control_child: Control = child as Control
			control_child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_display_controls_ignore_mouse(child)

func _get_direction_text(direction: int) -> String:
	return "做多熊猫元" if direction == TradePosition.Direction.LONG_XMY else "做多外币"

func _format_rate_or_placeholder(rate: float) -> String:
	if rate <= 0.0:
		return "--"
	return "%.4f" % rate if rate >= 1.0 else "%.5f" % rate

func _get_slot_panel(slot_index: int) -> Panel:
	if slot_index < 0 or slot_index >= _pair_slots.size():
		return null
	return _find_descendant_by_name(self, str(_pair_slots[slot_index].get("panel_name", ""))) as Panel

func _connect_single_slot_panel(slot_index: int) -> void:
	var panel: Panel = _get_slot_panel(slot_index)
	if panel == null:
		return
	_prepare_slot_row(panel)
	_cache_panel_base_style(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_display_controls_ignore_mouse(panel)
	var callback: Callable = _on_slot_panel_gui_input.bind(panel.name)
	if not panel.gui_input.is_connected(callback):
		panel.gui_input.connect(callback)
	var left_button: BaseButton = _find_descendant_by_name(panel, "左侧货币选择按钮") as BaseButton
	if left_button != null:
		var left_callback: Callable = _on_left_currency_button_pressed.bind(panel.name)
		if not left_button.pressed.is_connected(left_callback):
			left_button.pressed.connect(left_callback)
		left_button.mouse_filter = Control.MOUSE_FILTER_STOP
	var right_button: BaseButton = _find_descendant_by_name(panel, "右侧货币选择按钮") as BaseButton
	if right_button != null:
		var right_callback: Callable = _on_right_currency_button_pressed.bind(panel.name)
		if not right_button.pressed.is_connected(right_callback):
			right_button.pressed.connect(right_callback)
		right_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_panel_slide(panel.name, false)

func _ensure_trailing_placeholder_slot() -> void:
	if _pair_slots.is_empty():
		_append_placeholder_slot()
		return
	if _has_any_unconfigured_slot():
		return
	var last_slot: Dictionary = _pair_slots[_pair_slots.size() - 1]
	if not bool(last_slot.get("configured", false)):
		return
	_append_placeholder_slot()

func _append_placeholder_slot() -> void:
	if _slot_template_prototype == null or _slot_list_container == null:
		return
	_dynamic_slot_counter += 1
	var panel_name: String = "货币种类框%d" % _dynamic_slot_counter
	var cloned_panel := _slot_template_prototype.duplicate(15) as Panel
	if cloned_panel == null:
		return
	cloned_panel.name = panel_name
	_slot_list_container.add_child(cloned_panel)
	_slot_list_container.move_child(cloned_panel, _slot_list_container.get_child_count() - 1)
	var slot: Dictionary = {
		"panel_name": panel_name,
		"left_code": "",
		"right_code": "",
		"configured": false
	}
	_pair_slots.append(slot)
	_connect_single_slot_panel(_pair_slots.size() - 1)
	_refresh_single_slot(_pair_slots.size() - 1)
	_refresh_slot_container_size()

func _detect_existing_slot_count() -> int:
	var max_index: int = 2
	for slot in _pair_slots:
		var panel_name: String = str(slot.get("panel_name", ""))
		if panel_name.begins_with("货币种类框"):
			var suffix: String = panel_name.trim_prefix("货币种类框")
			if suffix.is_valid_int():
				max_index = max(max_index, int(suffix))
	return max_index

func _has_any_unconfigured_slot() -> bool:
	for slot in _pair_slots:
		if not bool(slot.get("configured", false)):
			return true
	return false

func _prepare_slot_row(panel: Panel) -> void:
	if panel == null or _slot_list_container == null:
		return
	var wrapper_name: String = ROW_WRAPPER_PREFIX + panel.name
	var wrapper: Control = panel.get_parent() as Control
	if wrapper != null and wrapper.name == wrapper_name:
		_row_wrappers[panel.name] = wrapper
		_ensure_delete_button(wrapper, panel.name)
		_layout_slot_row(panel.name)
		return
	var original_parent: Node = panel.get_parent()
	if original_parent == null:
		return
	var insert_index: int = panel.get_index()
	original_parent.remove_child(panel)
	var row_wrapper := Control.new()
	row_wrapper.name = wrapper_name
	row_wrapper.custom_minimum_size = panel.custom_minimum_size
	row_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_wrapper.clip_contents = true
	row_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	original_parent.add_child(row_wrapper)
	original_parent.move_child(row_wrapper, insert_index)
	row_wrapper.add_child(panel)
	panel.position = Vector2.ZERO
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = panel.custom_minimum_size.x
	panel.offset_bottom = panel.custom_minimum_size.y
	_row_wrappers[panel.name] = row_wrapper
	_ensure_delete_button(row_wrapper, panel.name)
	_layout_slot_row(panel.name)
	_refresh_slot_container_size()

func _ensure_delete_button(wrapper: Control, panel_name: String) -> void:
	var panel: Panel = _get_slot_panel(_find_slot_index_by_panel_name(panel_name))
	if wrapper == null or panel == null:
		return
	var delete_button: BaseButton = _find_descendant_by_name(panel, DELETE_BUTTON_NAME) as BaseButton
	if delete_button == null:
		delete_button = wrapper.get_node_or_null(DELETE_BUTTON_NAME) as BaseButton
	if delete_button == null and _delete_button_prototype != null:
		delete_button = _delete_button_prototype.duplicate(15) as BaseButton
		if delete_button != null:
			wrapper.add_child(delete_button)
	if delete_button == null:
		return
	if not _delete_button_layouts.has(panel_name):
		_delete_button_layouts[panel_name] = {
			"position": delete_button.position,
			"size": delete_button.size,
			"scale": delete_button.scale,
			"rotation": delete_button.rotation
		}
	if delete_button.get_parent() != wrapper:
		var layout: Dictionary = _delete_button_layouts.get(panel_name, {})
		var old_parent: Node = delete_button.get_parent()
		if old_parent != null:
			old_parent.remove_child(delete_button)
		wrapper.add_child(delete_button)
		delete_button.position = layout.get("position", delete_button.position)
		delete_button.size = layout.get("size", delete_button.size)
		delete_button.scale = layout.get("scale", delete_button.scale)
		delete_button.rotation = float(layout.get("rotation", delete_button.rotation))
	if delete_button.get_index() > 0:
		wrapper.move_child(delete_button, 0)
	panel.z_index = 1
	delete_button.z_index = 0
	delete_button.visible = false
	delete_button.mouse_filter = Control.MOUSE_FILTER_STOP
	var delete_callback: Callable = _on_delete_slot_pressed.bind(panel_name)
	if not delete_button.pressed.is_connected(delete_callback):
		delete_button.pressed.connect(delete_callback)
	_delete_buttons[panel_name] = delete_button

func _layout_slot_row(panel_name: String) -> void:
	var panel: Panel = _get_slot_panel(_find_slot_index_by_panel_name(panel_name))
	var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
	var delete_button: BaseButton = _delete_buttons.get(panel_name, null) as BaseButton
	if panel == null or wrapper == null:
		return
	var row_size: Vector2 = panel.custom_minimum_size
	if row_size.x <= 0.0:
		row_size.x = max(panel.size.x, 470.0)
	if row_size.y <= 0.0:
		row_size.y = max(panel.size.y, 91.0)
	wrapper.custom_minimum_size = row_size
	wrapper.size = row_size
	panel.size = row_size
	panel.offset_right = row_size.x
	panel.offset_bottom = row_size.y
	if delete_button != null and _delete_button_layouts.has(panel_name):
		var layout: Dictionary = _delete_button_layouts.get(panel_name, {})
		delete_button.position = layout.get("position", delete_button.position)
		delete_button.size = layout.get("size", delete_button.size)
		delete_button.scale = layout.get("scale", delete_button.scale)
		delete_button.rotation = float(layout.get("rotation", delete_button.rotation))
	_apply_slide_visual(panel_name)
	_refresh_slot_container_size()

func _begin_slot_drag(panel_name: String, mouse_x: float) -> void:
	var slot_index: int = _find_slot_index_by_panel_name(panel_name)
	if not _is_slot_swipe_enabled(slot_index):
		return
	_close_revealed_rows(panel_name)
	_drag_contexts[panel_name] = {
		"start_mouse_x": mouse_x,
		"start_offset": float(_slide_offsets.get(panel_name, 0.0)),
		"dragging": false
	}

func _update_slot_drag(panel_name: String, mouse_x: float) -> void:
	if not _drag_contexts.has(panel_name):
		return
	var context: Dictionary = _drag_contexts[panel_name]
	var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
	if wrapper == null:
		return
	var delta: float = float(context.get("start_mouse_x", mouse_x)) - mouse_x
	var max_offset: float = max(wrapper.custom_minimum_size.x, wrapper.size.x, 470.0) * DELETE_TRIGGER_RATIO
	var next_offset: float = clampf(float(context.get("start_offset", 0.0)) + delta, 0.0, max_offset)
	if not bool(context.get("dragging", false)) and absf(delta) >= DRAG_START_DISTANCE:
		context["dragging"] = true
	if bool(context.get("dragging", false)):
		_slide_offsets[panel_name] = next_offset
		_apply_slide_visual(panel_name)
	_drag_contexts[panel_name] = context

func _finish_slot_drag(panel_name: String, mouse_x: float) -> void:
	if not _drag_contexts.has(panel_name):
		var tap_index: int = _find_slot_index_by_panel_name(panel_name)
		if tap_index >= 0:
			_select_slot(tap_index)
		return
	var context: Dictionary = _drag_contexts[panel_name]
	_drag_contexts.erase(panel_name)
	if not bool(context.get("dragging", false)):
		var slot_index: int = _find_slot_index_by_panel_name(panel_name)
		if slot_index >= 0:
			_select_slot(slot_index)
		return
	var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
	if wrapper == null:
		return
	var final_offset: float = float(_slide_offsets.get(panel_name, 0.0))
	var trigger_width: float = max(wrapper.custom_minimum_size.x, wrapper.size.x, 470.0) * DELETE_TRIGGER_RATIO
	if final_offset >= trigger_width - 1.0 and _can_slot_reveal_delete(_find_slot_index_by_panel_name(panel_name)):
		_reveal_panel_delete(panel_name)
	else:
		_reset_panel_slide(panel_name, true)

func _apply_slide_visual(panel_name: String) -> void:
	var panel: Panel = _get_slot_panel(_find_slot_index_by_panel_name(panel_name))
	var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
	var delete_button: BaseButton = _delete_buttons.get(panel_name, null) as BaseButton
	if panel == null or wrapper == null:
		return
	var offset: float = float(_slide_offsets.get(panel_name, 0.0))
	panel.position.x = -offset
	if delete_button != null:
		delete_button.visible = _can_slot_reveal_delete(_find_slot_index_by_panel_name(panel_name))

func _update_delete_button_state(panel_name: String) -> void:
	var delete_button: BaseButton = _delete_buttons.get(panel_name, null) as BaseButton
	if delete_button == null:
		return
	delete_button.visible = _can_slot_reveal_delete(_find_slot_index_by_panel_name(panel_name))

func _reveal_panel_delete(panel_name: String) -> void:
	var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
	if wrapper == null:
		return
	var settle_offset: float = max(wrapper.custom_minimum_size.x, wrapper.size.x, 470.0) * DELETE_REVEAL_RATIO
	_tween_panel_slide(panel_name, settle_offset)

func _reset_panel_slide(panel_name: String, animated: bool) -> void:
	if animated:
		_tween_panel_slide(panel_name, 0.0)
		return
	_slide_offsets[panel_name] = 0.0
	_apply_slide_visual(panel_name)

func _tween_panel_slide(panel_name: String, target_offset: float) -> void:
	var panel: Panel = _get_slot_panel(_find_slot_index_by_panel_name(panel_name))
	if panel == null:
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_panel_slide_offset.bind(panel_name), float(_slide_offsets.get(panel_name, 0.0)), target_offset, 0.18)

func _set_panel_slide_offset(value: float, panel_name: String) -> void:
	_slide_offsets[panel_name] = value
	_apply_slide_visual(panel_name)

func _close_revealed_rows(except_panel_name: String = "") -> void:
	for panel_name in _slide_offsets.keys():
		if panel_name == except_panel_name:
			continue
		if float(_slide_offsets.get(panel_name, 0.0)) > 0.5:
			_reset_panel_slide(panel_name, true)

func _delete_slot(panel_name: String) -> void:
	var slot_index: int = _find_slot_index_by_panel_name(panel_name)
	if not _can_slot_reveal_delete(slot_index):
		return
	var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
	if wrapper != null:
		wrapper.queue_free()
	_pair_slots.remove_at(slot_index)
	_row_wrappers.erase(panel_name)
	_delete_buttons.erase(panel_name)
	_slide_offsets.erase(panel_name)
	_drag_contexts.erase(panel_name)
	if _selected_slot_index >= _pair_slots.size():
		_selected_slot_index = max(_pair_slots.size() - 1, 0)
	elif _selected_slot_index > slot_index:
		_selected_slot_index -= 1
	_refresh_slot_container_size()
	_refresh_slot_views()
	_refresh_position_panel()
	_ensure_trailing_placeholder_slot()
	_select_slot(clampi(_selected_slot_index, 0, max(_pair_slots.size() - 1, 0)))

func _find_slot_index_by_panel_name(panel_name: String) -> int:
	for index in range(_pair_slots.size()):
		if str(_pair_slots[index].get("panel_name", "")) == panel_name:
			return index
	return -1

func _is_slot_swipe_enabled(slot_index: int) -> bool:
	return slot_index > 0

func _can_slot_reveal_delete(slot_index: int) -> bool:
	if slot_index <= 0 or slot_index >= _pair_slots.size():
		return false
	return bool(_pair_slots[slot_index].get("configured", false))

func _refresh_slot_container_size() -> void:
	if _slot_list_container == null:
		return
	var total_height: float = 0.0
	var max_width: float = 0.0
	var visible_row_count: int = 0
	var last_row_height: float = 0.0
	var separation: float = 0.0
	if _slot_list_container is BoxContainer:
		separation = float((_slot_list_container as BoxContainer).get_theme_constant("separation"))
	for child in _slot_list_container.get_children():
		if not (child is Control):
			continue
		var row: Control = child as Control
		if row.is_queued_for_deletion():
			continue
		var row_size: Vector2 = row.custom_minimum_size
		if row_size.x <= 0.0:
			row_size.x = row.size.x
		if row_size.y <= 0.0:
			row_size.y = row.size.y
		max_width = max(max_width, row_size.x)
		total_height += row_size.y
		last_row_height = row_size.y
		visible_row_count += 1
	if visible_row_count > 1:
		total_height += separation * float(visible_row_count - 1)
	var top_scroll_reserve: float = 0.0
	if _slot_scroll_container != null and visible_row_count > 0:
		top_scroll_reserve = max(_slot_scroll_container.size.y - last_row_height, 0.0)
	_slot_list_container.custom_minimum_size = Vector2(max(max_width, 474.0), max(total_height + top_scroll_reserve, 0.0))
	_slot_list_container.update_minimum_size()
	if _slot_list_container.get_parent() is Control:
		(_slot_list_container.get_parent() as Control).update_minimum_size()

func _find_first_existing_slot() -> int:
	for index in range(_pair_slots.size()):
		if _get_slot_panel(index) != null:
			return index
	return 0

func _has_game_data_manager() -> bool:
	return get_node_or_null("/root/GameDataManager") != null

func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if root.name == target_name:
		return root
	for child in root.get_children():
		var result: Node = _find_descendant_by_name(child, target_name)
		if result != null:
			return result
	return null
