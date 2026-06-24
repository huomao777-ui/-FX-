extends Control
class_name FxCurrencyPanelController

signal slot_selected(slot: Dictionary)
signal open_requested(slot: Dictionary)

const OPEN_TEXT_COLOR := Color(0.97, 0.82, 0.36, 1.0)
const NORMAL_TEXT_COLOR := Color(0.98, 0.98, 0.98, 1.0)
const EMPTY_TEXT_COLOR := Color(0.72, 0.76, 0.84, 1.0)
const SELECTED_BORDER_COLOR := Color(0.34, 0.83, 1.0, 1.0)
const IDLE_BORDER_COLOR := Color(0.12, 0.16, 0.22, 0.92)
const DELETE_TRIGGER_RATIO := 0.40
const DELETE_REVEAL_RATIO := 0.20
const DRAG_START_DISTANCE := 8.0
const HEADER_SNAP_RATIO := 0.35
const DELETE_BUTTON_NAME := "减号按钮"
const SLOT_LIST_BOTTOM_PADDING := 8.0
const ROW_WRAPPER_PREFIX := "货币框行_"

@export var 界面配置路径: String = "res://资源/数据/市场/fx_ui_config.json"
@export var 上下换位触发距离: float = 34.0
@export var 上下换位延迟秒数: float = 0.12
@export var 上下换位补间秒数: float = 0.18

var _currency_catalog: Dictionary = {}
var _pair_slots: Array[Dictionary] = []
var _selected_slot_index: int = 0
var _pending_currency_slot_index: int = -1
var _pending_currency_side: String = ""
var _dynamic_slot_counter: int = 2

var _app_root: Node = null
var _chart_controller: Node = null
var _open_account_panel: Node = null
var _currency_picker_panel: Panel = null
var _slot_header_panel: Panel = null
var _slot_scroll_container: ScrollContainer = null
var _slot_list_container: Control = null
var _slot_template_panel: Panel = null
var _slot_template_prototype: Panel = null
var _currency_background_panel: Panel = null

var _panel_base_styles: Dictionary = {}
var _row_wrappers: Dictionary = {}
var _delete_buttons: Dictionary = {}
var _delete_button_layouts: Dictionary = {}
var _drag_contexts: Dictionary = {}
var _slide_offsets: Dictionary = {}
var _header_dragging: bool = false
var _header_drag_start_mouse_y: float = 0.0
var _header_drag_start_top: float = 0.0
var _header_rest_top: float = 0.0
var _header_snap_top: float = 0.0
var _header_height: float = 0.0
var _header_to_list_gap: float = 0.0
var _list_bottom_rest: float = 0.0
var _background_top_rest: float = 0.0
var _background_bottom_rest: float = 0.0
var _background_to_header_gap: float = 0.0
var _swap_timers: Dictionary = {}
var _swap_request_tokens: Dictionary = {}

func _ready() -> void:
	_app_root = get_parent()
	_load_ui_config()
	_cache_nodes()
	_connect_slot_panels()
	_connect_currency_picker_buttons()
	_connect_header_drag()
	_connect_open_button()
	_cache_header_layout_metrics()
	_apply_header_layout(_header_rest_top)
	_ensure_trailing_placeholder_slot()
	_refresh_slot_container_size()
	_select_slot(clampi(_find_first_existing_slot(), 0, max(_pair_slots.size() - 1, 0)))

func _input(event: InputEvent) -> void:
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
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if _currency_picker_panel != null and _currency_picker_panel.visible:
		if _get_control_global_rect(_currency_picker_panel).has_point(mouse_event.global_position):
			return
		_close_currency_picker()
		get_viewport().set_input_as_handled()

func get_selected_slot() -> Dictionary:
	if _selected_slot_index < 0 or _selected_slot_index >= _pair_slots.size():
		return {}
	return (_pair_slots[_selected_slot_index] as Dictionary).duplicate(true)

func mark_selected_slot_open(open_data: Dictionary = {}) -> void:
	if _selected_slot_index < 0 or _selected_slot_index >= _pair_slots.size():
		return
	var opening_panel_name: String = str(_pair_slots[_selected_slot_index].get("panel_name", ""))
	for key in open_data.keys():
		_pair_slots[_selected_slot_index][key] = open_data[key]
	_pair_slots[_selected_slot_index]["display_open_position"] = true
	_pair_slots[_selected_slot_index]["configured"] = true
	_move_selected_open_slot_to_top_group()
	_reorder_slot_nodes_to_match_data()
	_refresh_slot_views()
	_select_slot(_find_slot_index_by_panel_name(opening_panel_name))

func _load_ui_config() -> void:
	_currency_catalog.clear()
	_pair_slots.clear()
	var file: FileAccess = FileAccess.open(界面配置路径, FileAccess.READ)
	if file == null:
		push_warning("FxCurrencyPanelController: 无法打开界面配置 " + 界面配置路径)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("FxCurrencyPanelController: 界面配置 JSON 格式错误")
		return
	var config: Dictionary = parsed as Dictionary
	for entry in config.get("currencies", []) as Array:
		if not (entry is Dictionary):
			continue
		var item: Dictionary = (entry as Dictionary).duplicate(true)
		var code: String = str(item.get("code", ""))
		if not code.is_empty():
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
	if _pair_slots.is_empty():
		_pair_slots.append(_new_empty_slot("货币种类框1"))

func _cache_nodes() -> void:
	_chart_controller = _find_descendant_by_name(_app_root, "k线图画布")
	_open_account_panel = _find_descendant_by_name(_app_root, "开户面板")
	_currency_picker_panel = _find_descendant_by_name(_app_root, "货币选择") as Panel
	_currency_background_panel = _find_descendant_by_name(self, "货币背景") as Panel
	_slot_header_panel = _find_descendant_by_name(self, "上方遮挡") as Panel
	# 上下示意图像只是装饰，鼠标事件交给上方遮挡本体处理，避免按住装饰时拖不动。
	_set_display_controls_ignore_mouse(_find_descendant_by_name(self, "上下示意图像"))
	_slot_scroll_container = _find_descendant_by_name(self, "滑动容器") as ScrollContainer
	_slot_list_container = _find_node_by_path_names(self, ["滑动容器", "排列容器"]) as Control
	_slot_template_panel = _find_descendant_by_name(self, "货币种类框2") as Panel
	if _slot_template_panel != null:
		_slot_template_prototype = _slot_template_panel.duplicate(15) as Panel
	if _currency_picker_panel != null:
		_currency_picker_panel.visible = false
		_currency_picker_panel.z_index = 200
	_dynamic_slot_counter = _detect_existing_slot_count()

func _connect_slot_panels() -> void:
	for slot_index in range(_pair_slots.size()):
		_connect_single_slot_panel(slot_index)

func _connect_single_slot_panel(slot_index: int) -> void:
	var panel: Panel = _get_slot_panel(slot_index)
	if panel == null:
		return
	_prepare_slot_row(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_display_controls_ignore_mouse(panel)
	var callback: Callable = _on_slot_panel_gui_input.bind(str(panel.name))
	if not panel.gui_input.is_connected(callback):
		panel.gui_input.connect(callback)
	var left_button: BaseButton = _find_descendant_by_name(panel, "左侧货币选择按钮") as BaseButton
	if left_button != null:
		var left_callback: Callable = _on_left_currency_button_pressed.bind(str(panel.name))
		if not left_button.pressed.is_connected(left_callback):
			left_button.pressed.connect(left_callback)
	var right_button: BaseButton = _find_descendant_by_name(panel, "右侧货币选择按钮") as BaseButton
	if right_button != null:
		var right_callback: Callable = _on_right_currency_button_pressed.bind(str(panel.name))
		if not right_button.pressed.is_connected(right_callback):
			right_button.pressed.connect(right_callback)
	var delete_button: BaseButton = _find_descendant_by_name(panel, DELETE_BUTTON_NAME) as BaseButton
	if delete_button != null:
		delete_button.visible = false
		var delete_callback: Callable = _on_delete_slot_pressed.bind(str(panel.name))
		if not delete_button.pressed.is_connected(delete_callback):
			delete_button.pressed.connect(delete_callback)

func _connect_currency_picker_buttons() -> void:
	if _currency_picker_panel == null:
		return
	for currency_code in _currency_catalog.keys():
		var data: Dictionary = _currency_catalog[currency_code] as Dictionary
		var display_name: String = str(data.get("display_name", ""))
		var button: BaseButton = _find_descendant_by_name(_currency_picker_panel, display_name) as BaseButton
		if button == null:
			continue
		var callback: Callable = _on_currency_option_pressed.bind(str(currency_code))
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)

func _connect_header_drag() -> void:
	if _slot_header_panel == null:
		return
	_slot_header_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _slot_header_panel.gui_input.is_connected(_on_header_panel_gui_input):
		_slot_header_panel.gui_input.connect(_on_header_panel_gui_input)

func _connect_open_button() -> void:
	var one_click_panel: Panel = _find_descendant_by_name(_app_root, "一键开仓") as Panel
	var one_click_button: BaseButton = _find_first_button(one_click_panel)
	if one_click_button != null and not one_click_button.pressed.is_connected(_on_one_click_open_pressed):
		one_click_button.pressed.connect(_on_one_click_open_pressed)

func _on_header_panel_gui_input(event: InputEvent) -> void:
	# 货币列表顶部遮挡：按住上拉后吸附到K线顶部，松手时用缓动弹回/吸附。
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_header_dragging = true
			_header_drag_start_mouse_y = mouse_button.global_position.y
			_header_drag_start_top = _slot_header_panel.position.y
			get_viewport().set_input_as_handled()
			return
		if _header_dragging:
			_header_dragging = false
			_finish_header_drag()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _header_dragging:
		var motion_event := event as InputEventMouseMotion
		_update_header_drag(motion_event.global_position.y)
		get_viewport().set_input_as_handled()

func _update_header_drag(mouse_y: float) -> void:
	var dragged_top: float = _header_drag_start_top + (mouse_y - _header_drag_start_mouse_y)
	_apply_header_layout(clampf(dragged_top, _header_snap_top, _header_rest_top))

func _finish_header_drag() -> void:
	if _slot_header_panel == null:
		return
	var current_top: float = _slot_header_panel.position.y
	var travel_distance: float = maxf(_header_rest_top - _header_snap_top, 0.001)
	var moved_ratio: float = (_header_rest_top - current_top) / travel_distance
	var target_top: float = _header_snap_top if moved_ratio >= HEADER_SNAP_RATIO else _header_rest_top
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_apply_header_layout, current_top, target_top, 0.22)

func _cache_header_layout_metrics() -> void:
	if _slot_header_panel == null or _slot_scroll_container == null:
		return
	_header_rest_top = _slot_header_panel.position.y
	_header_height = _slot_header_panel.size.y
	_header_to_list_gap = _slot_scroll_container.position.y - _slot_header_panel.position.y - _header_height
	_list_bottom_rest = minf(_slot_scroll_container.position.y + _slot_scroll_container.size.y, _get_slot_list_bottom_limit())
	if _currency_background_panel != null:
		_background_top_rest = _currency_background_panel.position.y
		_background_bottom_rest = _currency_background_panel.position.y + _currency_background_panel.size.y
		_background_to_header_gap = _currency_background_panel.position.y - (_header_rest_top + _header_height)
	if _chart_controller is Control:
		var chart_control := _chart_controller as Control
		var chart_top_local: Vector2 = get_global_transform().affine_inverse() * chart_control.global_position
		_header_snap_top = minf(_header_rest_top, chart_top_local.y)
	else:
		_header_snap_top = 0.0

func _apply_header_layout(header_top: float) -> void:
	if _slot_header_panel == null or _slot_scroll_container == null:
		return
	_slot_header_panel.position.y = header_top
	var next_scroll_top: float = header_top + _header_height + _header_to_list_gap
	_slot_scroll_container.position.y = next_scroll_top
	var scroll_bottom_limit: float = minf(_list_bottom_rest, _get_slot_list_bottom_limit())
	_slot_scroll_container.size.y = maxf(scroll_bottom_limit - next_scroll_top, 60.0)
	if _currency_background_panel != null:
		var next_background_top: float = header_top + _header_height + _background_to_header_gap
		_currency_background_panel.position.y = next_background_top
		var background_bottom_limit: float = minf(_background_bottom_rest, scroll_bottom_limit)
		_currency_background_panel.size.y = maxf(background_bottom_limit - next_background_top, 60.0)
	_refresh_slot_container_size()

func _get_slot_list_bottom_limit() -> float:
	# 货币列表上拉后不能盖住下方操作按钮，底部边界按当前可见操作面板动态收紧。
	if _slot_scroll_container == null:
		return _list_bottom_rest
	var default_bottom_limit: float = _slot_scroll_container.position.y + _slot_scroll_container.size.y
	var bottom_limit: float = INF
	for panel_name in ["减仓补仓", "一键开仓", "确认开仓"]:
		var panel: Control = _find_descendant_by_name(_app_root, panel_name) as Control
		if panel == null:
			continue
		var panel_top_local: float = (get_global_transform().affine_inverse() * panel.global_position).y
		bottom_limit = minf(bottom_limit, panel_top_local - SLOT_LIST_BOTTOM_PADDING)
	if is_inf(bottom_limit):
		return default_bottom_limit
	return bottom_limit

func _on_slot_panel_gui_input(event: InputEvent, panel_name: String) -> void:
	var slot_index: int = _find_slot_index_by_panel_name(panel_name)
	if slot_index < 0:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_select_slot(slot_index)
			_begin_slot_drag(panel_name, mouse_button.global_position)
		else:
			_finish_slot_drag(panel_name, mouse_button.global_position)
	elif event is InputEventMouseMotion and _drag_contexts.has(panel_name):
		var mouse_motion := event as InputEventMouseMotion
		_update_slot_drag(panel_name, mouse_motion.global_position)

func _begin_slot_drag(panel_name: String, mouse_position: Vector2) -> void:
	if not _is_slot_drag_enabled(_find_slot_index_by_panel_name(panel_name)):
		return
	_close_revealed_rows(panel_name)
	_drag_contexts[panel_name] = {
		"start_mouse": mouse_position,
		"start_offset": float(_slide_offsets.get(panel_name, 0.0)),
		"dragging": false
	}

func _update_slot_drag(panel_name: String, mouse_position: Vector2) -> void:
	if not _drag_contexts.has(panel_name):
		return
	var context: Dictionary = _drag_contexts.get(panel_name, {}) as Dictionary
	var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
	if wrapper == null:
		return
	var start_mouse: Vector2 = context.get("start_mouse", mouse_position) as Vector2
	var delta: Vector2 = mouse_position - start_mouse
	if absf(delta.x) > DRAG_START_DISTANCE or absf(delta.y) > DRAG_START_DISTANCE:
		context["dragging"] = true
	if absf(delta.y) > absf(delta.x) and absf(delta.y) >= 上下换位触发距离:
		context["mode"] = "vertical"
		_drag_contexts[panel_name] = context
		_schedule_vertical_swap(panel_name, delta.y)
		return
	var slot_index: int = _find_slot_index_by_panel_name(panel_name)
	var max_offset: float = maxf(maxf(wrapper.custom_minimum_size.x, wrapper.size.x), 470.0) * DELETE_TRIGGER_RATIO
	var horizontal_delta: float = -delta.x
	var next_offset: float = clampf(float(context.get("start_offset", 0.0)) + horizontal_delta, 0.0, max_offset)
	if not _is_slot_swipe_enabled(slot_index):
		next_offset = 0.0
	_drag_contexts[panel_name] = context
	_slide_offsets[panel_name] = next_offset
	_apply_slide_visual(panel_name)

func _finish_slot_drag(panel_name: String, _mouse_position: Vector2) -> void:
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
	if str(context.get("mode", "")) == "vertical":
		_cancel_pending_swap(panel_name)
		_reset_panel_slide(panel_name, true)
		return
	var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
	if wrapper == null:
		return
	var final_offset: float = float(_slide_offsets.get(panel_name, 0.0))
	var trigger_width: float = maxf(maxf(wrapper.custom_minimum_size.x, wrapper.size.x), 470.0) * DELETE_TRIGGER_RATIO
	if final_offset >= trigger_width - 1.0 and _can_slot_reveal_delete(_find_slot_index_by_panel_name(panel_name)):
		_reveal_panel_delete(panel_name)
	else:
		_reset_panel_slide(panel_name, true)

func _schedule_vertical_swap(panel_name: String, delta_y: float) -> void:
	var direction: int = 1 if delta_y > 0.0 else -1
	var existing_direction: int = int(_swap_timers.get(panel_name + "_direction", 0))
	if _swap_timers.has(panel_name) and existing_direction == direction:
		return
	_cancel_pending_swap(panel_name)
	_swap_timers[panel_name + "_direction"] = direction
	var request_token: int = int(_swap_request_tokens.get(panel_name, 0)) + 1
	_swap_request_tokens[panel_name] = request_token
	var timer: SceneTreeTimer = get_tree().create_timer(maxf(上下换位延迟秒数, 0.0))
	_swap_timers[panel_name] = timer
	var callback: Callable = _on_vertical_swap_timer_timeout.bind(panel_name, direction, request_token)
	timer.timeout.connect(callback)

func _on_vertical_swap_timer_timeout(panel_name: String, direction: int, request_token: int) -> void:
	if int(_swap_request_tokens.get(panel_name, 0)) != request_token:
		return
	_swap_timers.erase(panel_name)
	_swap_timers.erase(panel_name + "_direction")
	_try_swap_slot_by_vertical_drag(panel_name, direction)

func _try_swap_slot_by_vertical_drag(panel_name: String, direction: int) -> void:
	var source_index: int = _find_slot_index_by_panel_name(panel_name)
	if source_index < 0:
		return
	var target_index: int = source_index + direction
	if not _can_swap_slots(source_index, target_index):
		return
	var selected_panel_name: String = str(_pair_slots[source_index].get("panel_name", ""))
	var source_slot: Dictionary = _pair_slots[source_index]
	_pair_slots[source_index] = _pair_slots[target_index]
	_pair_slots[target_index] = source_slot
	_selected_slot_index = target_index
	_reorder_slot_nodes_to_match_data()
	_refresh_slot_views()
	_refresh_slot_container_size()
	var context: Dictionary = _drag_contexts.get(panel_name, {}) as Dictionary
	context["start_mouse"] = get_viewport().get_mouse_position()
	_drag_contexts[selected_panel_name] = context

func _can_swap_slots(source_index: int, target_index: int) -> bool:
	if source_index < 0 or source_index >= _pair_slots.size() or target_index < 0 or target_index >= _pair_slots.size():
		return false
	# 排序只允许同组交换：已开户组内部可换位，未开户/待配置组内部可换位，不能跨过组边界。
	return _slot_has_open_position_display(_pair_slots[source_index]) == _slot_has_open_position_display(_pair_slots[target_index])

func _cancel_pending_swap(panel_name: String) -> void:
	_swap_timers.erase(panel_name)
	_swap_timers.erase(panel_name + "_direction")
	_swap_request_tokens[panel_name] = int(_swap_request_tokens.get(panel_name, 0)) + 1

func _apply_slide_visual(panel_name: String) -> void:
	var slot_index: int = _find_slot_index_by_panel_name(panel_name)
	var panel: Panel = _get_slot_panel(slot_index)
	var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
	if panel == null or wrapper == null:
		return
	# 减号按钮放在行容器背后，货币框左移时露出，按钮自身不跟随货币框移动。
	panel.position.x = -float(_slide_offsets.get(panel_name, 0.0))
	var delete_button: BaseButton = _delete_buttons.get(panel_name, null) as BaseButton
	if delete_button != null:
		delete_button.visible = _can_slot_reveal_delete(slot_index)

func _on_left_currency_button_pressed(panel_name: String) -> void:
	_open_currency_picker(_find_slot_index_by_panel_name(panel_name), "left_code")

func _on_right_currency_button_pressed(panel_name: String) -> void:
	_open_currency_picker(_find_slot_index_by_panel_name(panel_name), "right_code")

func _on_delete_slot_pressed(panel_name: String) -> void:
	_delete_slot(panel_name)

func _open_currency_picker(slot_index: int, side_key: String) -> void:
	if slot_index < 0 or _currency_picker_panel == null:
		return
	_pending_currency_slot_index = slot_index
	_pending_currency_side = side_key
	_select_slot(slot_index)
	_currency_picker_panel.visible = true

func _close_currency_picker() -> void:
	_pending_currency_slot_index = -1
	_pending_currency_side = ""
	if _currency_picker_panel != null:
		_currency_picker_panel.visible = false

func _on_currency_option_pressed(currency_code: String) -> void:
	if _pending_currency_slot_index < 0 or _pending_currency_slot_index >= _pair_slots.size():
		return
	var target_slot_index: int = _pending_currency_slot_index
	var slot: Dictionary = _pair_slots[_pending_currency_slot_index]
	var other_side: String = "right_code" if _pending_currency_side == "left_code" else "left_code"
	if str(slot.get(_pending_currency_side, "")) == currency_code:
		slot[_pending_currency_side] = ""
	elif str(slot.get(other_side, "")) == currency_code:
		slot[other_side] = str(slot.get(_pending_currency_side, ""))
		slot[_pending_currency_side] = currency_code
	else:
		slot[_pending_currency_side] = currency_code
	slot["configured"] = _slot_is_configured(slot)
	_pair_slots[_pending_currency_slot_index] = slot
	_close_currency_picker()
	# 选择货币后继续选中当前操作的货币框，不再被刷新流程带回第一个框。
	_after_slot_configuration_changed(target_slot_index)

func _on_one_click_open_pressed() -> void:
	var slot: Dictionary = get_selected_slot()
	if not _slot_is_configured(slot) or _slot_has_open_position_display(slot):
		return
	if _open_account_panel != null and _open_account_panel.has_method("open_for_slot"):
		_open_account_panel.call("open_for_slot", slot, self)
	open_requested.emit(slot)

func _after_slot_configuration_changed(slot_index: int) -> void:
	_refresh_slot_views()
	_ensure_trailing_placeholder_slot()
	_select_slot(slot_index)
	_refresh_slot_container_size()

func _refresh_slot_views() -> void:
	for slot_index in range(_pair_slots.size()):
		_refresh_single_slot(slot_index)

func _refresh_single_slot(slot_index: int) -> void:
	var panel: Panel = _get_slot_panel(slot_index)
	if panel == null:
		return
	var slot: Dictionary = _pair_slots[slot_index]
	var pair_label: Label = _get_pair_text_label(panel)
	var left_code: String = str(slot.get("left_code", ""))
	var right_code: String = str(slot.get("right_code", ""))
	var configured: bool = _slot_is_configured(slot)
	var has_position: bool = _slot_has_open_position_display(slot)
	if pair_label != null:
		# 货币框英文简写必须跟随选择结果刷新，不能只切图标。
		pair_label.text = _get_pair_label(slot)
		pair_label.add_theme_color_override("font_color", OPEN_TEXT_COLOR if has_position else (NORMAL_TEXT_COLOR if configured else EMPTY_TEXT_COLOR))
	var rate_label: Label = _find_descendant_by_name(panel, "实时汇率") as Label
	if rate_label != null:
		rate_label.text = _format_rate_or_placeholder(_get_slot_rate(slot)) if configured else "--"
		rate_label.add_theme_color_override("font_color", OPEN_TEXT_COLOR if has_position else NORMAL_TEXT_COLOR)
	_update_slot_icons(panel, left_code, right_code)
	_apply_panel_style(panel, slot_index == _selected_slot_index)
	_layout_slot_row(str(panel.name))

func _select_slot(slot_index: int) -> void:
	if _pair_slots.is_empty():
		return
	_selected_slot_index = clampi(slot_index, 0, _pair_slots.size() - 1)
	_refresh_slot_views()
	var slot: Dictionary = get_selected_slot()
	if _slot_is_configured(slot):
		if _chart_controller != null and _chart_controller.has_method("show_pair"):
			_chart_controller.call("show_pair", str(slot.get("left_code", "")), str(slot.get("right_code", "")), _get_pair_label(slot))
		if _chart_controller != null and _chart_controller.has_method("set_liquidation_line") and _slot_has_open_position_display(slot):
			var liquidation_rate: float = float(slot.get("liquidation_rate", 0.0))
			if liquidation_rate <= 0.0:
				liquidation_rate = _get_slot_rate(slot) * 0.82
			_chart_controller.call("set_liquidation_line", liquidation_rate, "强平线 " + _format_rate_or_placeholder(liquidation_rate))
		elif _chart_controller != null and _chart_controller.has_method("clear_liquidation_line"):
			_chart_controller.call("clear_liquidation_line")
	else:
		if _chart_controller != null and _chart_controller.has_method("clear_chart"):
			_chart_controller.call("clear_chart")
		if _chart_controller != null and _chart_controller.has_method("clear_liquidation_line"):
			_chart_controller.call("clear_liquidation_line")
	_refresh_action_panels(_slot_is_configured(slot), _slot_has_open_position_display(slot))
	_refresh_position_panel(slot)
	slot_selected.emit(slot)

func _refresh_action_panels(is_configured: bool, has_position: bool) -> void:
	var adjust_panel: Panel = _find_descendant_by_name(_app_root, "减仓补仓") as Panel
	var one_click_panel: Panel = _find_descendant_by_name(_app_root, "一键开仓") as Panel
	var confirm_panel: Panel = _find_descendant_by_name(_app_root, "确认开仓") as Panel
	if adjust_panel != null:
		adjust_panel.visible = is_configured and has_position
	if one_click_panel != null:
		one_click_panel.visible = is_configured and not has_position
	if confirm_panel != null and _open_account_panel != null:
		confirm_panel.visible = _open_account_panel.visible

func _refresh_position_panel(slot: Dictionary) -> void:
	var position_panel: Panel = _find_descendant_by_name(_app_root, "当前持仓订单") as Panel
	if position_panel == null:
		return
	var pair_label: Label = _find_descendant_by_name(position_panel, "货币种类") as Label
	var lots_label: Label = _find_descendant_by_name(position_panel, "持仓数") as Label
	var entry_label: Label = _find_descendant_by_name(position_panel, "买入汇率") as Label
	var current_label: Label = _find_descendant_by_name(position_panel, "当前汇率") as Label
	var leverage_label: Label = _find_descendant_by_name(position_panel, "杠杆倍率") as Label
	var overnight_label: Label = _find_descendant_by_name(position_panel, "隔夜利息") as Label
	var configured: bool = _slot_is_configured(slot)
	var has_position: bool = _slot_has_open_position_display(slot)
	if pair_label != null:
		pair_label.text = _get_pair_label(slot) if configured else "XXX/XXX"
	if not has_position:
		# 未开仓/空白币对必须恢复成默认占位，避免上一张订单卡的信息残留。
		if lots_label != null:
			lots_label.text = "当前持仓：暂无"
		if entry_label != null:
			entry_label.text = "买入汇率：--"
		if current_label != null:
			current_label.text = "当前汇率：--"
		if leverage_label != null:
			leverage_label.text = "--倍杠杆"
		if overnight_label != null:
			overnight_label.text = "隔夜利息：--"
		return
	var lots: float = float(slot.get("mock_lots", 0.0))
	var direction_text: String = str(slot.get("direction_text", "做多"))
	var leverage: int = int(slot.get("mock_leverage", 0))
	var entry_rate: float = float(slot.get("mock_entry_rate", 0.0))
	if entry_rate <= 0.0:
		entry_rate = _get_slot_rate(slot)
	var current_rate: float = _get_slot_rate(slot)
	if lots_label != null:
		lots_label.text = "当前持仓：%s手 %s" % [_format_lots(lots), direction_text]
	if entry_label != null:
		entry_label.text = "买入汇率：%s" % _format_rate_or_placeholder(entry_rate)
	if current_label != null:
		current_label.text = "当前汇率：%s" % _format_rate_or_placeholder(current_rate)
	if leverage_label != null:
		leverage_label.text = "%d倍杠杆" % leverage if leverage > 0 else "--倍杠杆"
	if overnight_label != null:
		var overnight_text: String = str(slot.get("mock_overnight_interest_text", ""))
		overnight_label.text = "隔夜利息：%s" % (overnight_text if not overnight_text.is_empty() else "--")

func _ensure_trailing_placeholder_slot() -> void:
	if _has_any_unconfigured_slot():
		return
	_append_placeholder_slot()

func _append_placeholder_slot() -> void:
	if _slot_list_container == null or _slot_template_prototype == null:
		return
	_dynamic_slot_counter += 1
	var panel_name: String = "货币种类框" + str(_dynamic_slot_counter)
	var new_panel: Panel = _slot_template_prototype.duplicate(15) as Panel
	new_panel.name = panel_name
	new_panel.visible = true
	_slot_list_container.add_child(new_panel)
	var slot: Dictionary = _new_empty_slot(panel_name)
	_pair_slots.append(slot)
	_connect_single_slot_panel(_pair_slots.size() - 1)
	_reorder_slot_nodes_to_match_data()
	_refresh_single_slot(_pair_slots.size() - 1)

func _delete_slot(panel_name: String) -> void:
	var slot_index: int = _find_slot_index_by_panel_name(panel_name)
	if slot_index < 0 or _slot_has_open_position_display(_pair_slots[slot_index]):
		return
	var panel: Panel = _get_slot_panel(slot_index)
	var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
	_pair_slots.remove_at(slot_index)
	if wrapper != null:
		wrapper.queue_free()
		_row_wrappers.erase(panel_name)
		_delete_buttons.erase(panel_name)
		_delete_button_layouts.erase(panel_name)
	elif panel != null:
		panel.queue_free()
	if _pair_slots.is_empty():
		_pair_slots.append(_new_empty_slot("货币种类框1"))
	_refresh_slot_views()
	_ensure_trailing_placeholder_slot()
	_select_slot(clampi(slot_index, 0, _pair_slots.size() - 1))
	_refresh_slot_container_size()

func _prepare_slot_row(panel: Panel) -> void:
	if _slot_list_container == null or panel == null:
		return
	var panel_name: String = str(panel.name)
	var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
	if wrapper == null:
		wrapper = Control.new()
		wrapper.name = ROW_WRAPPER_PREFIX + panel_name
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var original_index: int = panel.get_index()
		_slot_list_container.remove_child(panel)
		_slot_list_container.add_child(wrapper)
		_slot_list_container.move_child(wrapper, original_index)
		wrapper.add_child(panel)
		_row_wrappers[panel_name] = wrapper
	_ensure_delete_button(wrapper, panel_name)
	_layout_slot_row(panel_name)

func _ensure_delete_button(wrapper: Control, panel_name: String) -> void:
	var panel: Panel = _get_slot_panel(_find_slot_index_by_panel_name(panel_name))
	if wrapper == null or panel == null:
		return
	var delete_button: BaseButton = _find_descendant_by_name(panel, DELETE_BUTTON_NAME) as BaseButton
	if delete_button == null:
		delete_button = wrapper.get_node_or_null(DELETE_BUTTON_NAME) as BaseButton
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
		var layout: Dictionary = _delete_button_layouts.get(panel_name, {}) as Dictionary
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
		row_size.x = maxf(panel.size.x, 470.0)
	if row_size.y <= 0.0:
		row_size.y = maxf(panel.size.y, 91.0)
	wrapper.custom_minimum_size = row_size
	wrapper.size = row_size
	panel.size = row_size
	panel.offset_right = row_size.x
	panel.offset_bottom = row_size.y
	if delete_button != null and _delete_button_layouts.has(panel_name):
		var layout: Dictionary = _delete_button_layouts.get(panel_name, {}) as Dictionary
		delete_button.position = layout.get("position", delete_button.position)
		delete_button.size = layout.get("size", delete_button.size)
		delete_button.scale = layout.get("scale", delete_button.scale)
		delete_button.rotation = float(layout.get("rotation", delete_button.rotation))
	_apply_slide_visual(panel_name)

func _reveal_panel_delete(panel_name: String) -> void:
	var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
	if wrapper == null:
		return
	var settle_offset: float = maxf(maxf(wrapper.custom_minimum_size.x, wrapper.size.x), 470.0) * DELETE_REVEAL_RATIO
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
		var name_string: String = str(panel_name)
		if name_string == except_panel_name:
			continue
		_reset_panel_slide(name_string, true)

func _move_selected_open_slot_to_top_group() -> void:
	if _selected_slot_index < 0 or _selected_slot_index >= _pair_slots.size():
		return
	var slot: Dictionary = _pair_slots[_selected_slot_index]
	_pair_slots.remove_at(_selected_slot_index)
	var insert_index: int = 0
	while insert_index < _pair_slots.size() and _slot_has_open_position_display(_pair_slots[insert_index]):
		insert_index += 1
	_pair_slots.insert(insert_index, slot)
	_selected_slot_index = insert_index

func _reorder_slot_nodes_to_match_data() -> void:
	# 开仓后数据会置顶到“已开仓组”末尾，VBoxContainer 的显示顺序也必须同步。
	if _slot_list_container == null:
		return
	for slot_index in range(_pair_slots.size()):
		var panel_name: String = str(_pair_slots[slot_index].get("panel_name", ""))
		var panel: Panel = _get_slot_panel(slot_index)
		if panel != null and not _row_wrappers.has(panel_name):
			_prepare_slot_row(panel)
		var wrapper: Control = _row_wrappers.get(panel_name, null) as Control
		if wrapper != null and wrapper.get_parent() == _slot_list_container:
			_slot_list_container.move_child(wrapper, slot_index)

func _get_slot_rate(slot: Dictionary) -> float:
	var left_rate: float = _get_rate_against_base(str(slot.get("left_code", "")))
	var right_rate: float = _get_rate_against_base(str(slot.get("right_code", "")))
	if left_rate <= 0.0 or right_rate <= 0.0:
		return 0.0
	return right_rate / left_rate

func _get_rate_against_base(currency_code: String) -> float:
	if currency_code == "XMY":
		return 1.0
	var market_engine: Node = get_node_or_null("/root/GameDataManager/MarketEngine")
	if market_engine != null and market_engine.has_method("获取汇率"):
		return float(market_engine.call("获取汇率", currency_code))
	return 0.0

func _get_pair_label(slot: Dictionary) -> String:
	var left_code: String = str(slot.get("left_code", ""))
	var right_code: String = str(slot.get("right_code", ""))
	return (left_code if not left_code.is_empty() else "xxx") + "/" + (right_code if not right_code.is_empty() else "xxx")

func _format_rate_or_placeholder(rate: float) -> String:
	return "%.4f" % rate if rate > 0.0 else "--"

func _format_lots(lots: float) -> String:
	if is_equal_approx(lots, roundf(lots)):
		return str(int(roundf(lots)))
	return "%.2f" % lots

func _slot_is_configured(slot: Dictionary) -> bool:
	return not str(slot.get("left_code", "")).is_empty() and not str(slot.get("right_code", "")).is_empty()

func _slot_has_open_position_display(slot: Dictionary) -> bool:
	return bool(slot.get("display_open_position", false))

func _can_slot_reveal_delete(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _pair_slots.size() and _slot_is_configured(_pair_slots[slot_index]) and not _slot_has_open_position_display(_pair_slots[slot_index])

func _is_slot_swipe_enabled(slot_index: int) -> bool:
	# 所有货币框都可以尝试左滑；只有完整且未开仓的框会停住露出减号，其它会自动弹回。
	return slot_index >= 0 and slot_index < _pair_slots.size() and not _slot_has_open_position_display(_pair_slots[slot_index])

func _is_slot_drag_enabled(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _pair_slots.size()

func _has_any_unconfigured_slot() -> bool:
	for slot in _pair_slots:
		if not _slot_is_configured(slot):
			return true
	return false

func _new_empty_slot(panel_name: String) -> Dictionary:
	return {"panel_name": panel_name, "left_code": "", "right_code": "", "configured": false}

func _detect_existing_slot_count() -> int:
	var count: int = 0
	if _slot_list_container == null:
		return count
	for child in _slot_list_container.get_children():
		if child is Panel and str(child.name).begins_with("货币种类框"):
			count += 1
	return max(count, _pair_slots.size())

func _find_first_existing_slot() -> int:
	return 0 if not _pair_slots.is_empty() else -1

func _find_slot_index_by_panel_name(panel_name: String) -> int:
	for i in range(_pair_slots.size()):
		if str(_pair_slots[i].get("panel_name", "")) == panel_name:
			return i
	return -1

func _get_slot_panel(slot_index: int) -> Panel:
	if slot_index < 0 or slot_index >= _pair_slots.size():
		return null
	var panel_name: String = str(_pair_slots[slot_index].get("panel_name", ""))
	var found: Node = _find_descendant_by_name(_slot_list_container, panel_name)
	return found as Panel

func _get_pair_text_label(panel: Panel) -> Label:
	var explicit_label: Label = _find_descendant_by_name(panel, "货币对文字") as Label
	if explicit_label != null:
		return explicit_label
	return _find_label_by_name(panel, "货币对")

func _find_label_by_name(root: Node, target_name: String) -> Label:
	if root == null:
		return null
	if root is Label and root.name == target_name:
		return root as Label
	for child in root.get_children():
		var found: Label = _find_label_by_name(child, target_name)
		if found != null:
			return found
	return null

func _update_slot_icons(panel: Panel, left_code: String, right_code: String) -> void:
	_set_icon_visibility(_find_descendant_by_name(panel, "左侧货币图"), left_code, false)
	_set_icon_visibility(_find_descendant_by_name(panel, "右侧货币图"), right_code, true)
	_set_icon_visibility(_find_descendant_by_name(panel, "左侧货币选择按钮"), left_code, false)
	_set_icon_visibility(_find_descendant_by_name(panel, "右侧货币选择按钮"), right_code, false)

func _set_icon_visibility(root: Node, code: String, use_right_suffix: bool) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is CanvasItem:
			var item := child as CanvasItem
			var child_name: String = str(child.name)
			if use_right_suffix and child_name.ends_with("2"):
				child_name = child_name.trim_suffix("2")
			item.visible = not code.is_empty() and child_name == code

func _apply_panel_style(panel: Panel, is_selected: bool) -> void:
	if panel == null:
		return
	if not _panel_base_styles.has(panel.name):
		var base_style: StyleBox = panel.get_theme_stylebox("panel")
		_panel_base_styles[panel.name] = base_style.duplicate() if base_style != null else StyleBoxFlat.new()
	var style: StyleBoxFlat = (_panel_base_styles[panel.name] as StyleBox).duplicate() as StyleBoxFlat
	style.border_color = SELECTED_BORDER_COLOR if is_selected else IDLE_BORDER_COLOR
	var width: int = 3 if is_selected else 1
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	panel.add_theme_stylebox_override("panel", style)

func _refresh_slot_container_size() -> void:
	if _slot_list_container == null:
		return
	var row_height: float = 96.0
	if _slot_template_panel != null:
		row_height = maxf(_slot_template_panel.custom_minimum_size.y + 8.0, row_height)
	_slot_list_container.custom_minimum_size.y = maxf((_pair_slots.size() + 3) * row_height, 600.0)

func _set_display_controls_ignore_mouse(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is Control and not child is BaseButton:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_display_controls_ignore_mouse(child)

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

func _find_node_by_path_names(root: Node, names: Array[String]) -> Node:
	var current: Node = root
	for node_name in names:
		if current == null:
			return null
		current = current.get_node_or_null(node_name)
	return current

func _get_control_global_rect(control: Control) -> Rect2:
	if control == null:
		return Rect2()
	return control.get_global_rect()

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
