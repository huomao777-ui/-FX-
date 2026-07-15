extends Control
class_name NewsTimePopupCarouselController

signal current_day_changed(current_day: int)
signal current_date_changed(date_data: Dictionary)

const DRAG_START_DISTANCE: float = 8.0
const SNAP_DISTANCE_RATIO: float = 0.28
const SNAP_MIN_DURATION: float = 0.14
const SNAP_MAX_DURATION: float = 0.24
const FUTURE_DRAG_DAMPING: float = 0.18
const FUTURE_DRAG_MAX_RATIO: float = 0.24
const DEFAULT_WEEKDAY_LABELS: Array[String] = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

@export var track_path: NodePath
@export var viewport_path: NodePath
@export var current_time_title_path: NodePath
@export var year_previous_button_path: NodePath
@export var year_next_button_path: NodePath
@export var month_previous_button_path: NodePath
@export var month_next_button_path: NodePath
@export var prefer_game_time: bool = true
@export_range(1, 9999, 1) var display_year: int = 2026
@export_range(1, 12, 1) var display_month: int = 7
@export_range(1, 31, 1) var today_day: int = 12
@export_range(0, 4, 1) var anchor_slot_index: int = 2
@export var front_scale: float = 1.16
@export var near_scale: float = 0.96
@export var far_scale: float = 0.84
@export var front_alpha: float = 1.0
@export var near_alpha: float = 0.9
@export var far_alpha: float = 0.66
@export var active_velocity_threshold: float = 900.0
@export var snap_duration: float = 0.18
@export var title_prefix: String = "<"
@export var title_suffix: String = ">"

var _pointer_down: bool = false
var _dragging: bool = false
var _press_mouse_global_x: float = 0.0
var _drag_offset_x: float = 0.0
var _drag_velocity_x: float = 0.0
var _active_tween: Tween = null
var _focus_refresh_queued: bool = false

var _track: HBoxContainer = null
var _viewport_control: Control = null
var _title_label: Label = null
var _year_previous_button: Button = null
var _year_next_button: Button = null
var _month_previous_button: Button = null
var _month_next_button: Button = null
var _slot_items: Array[Panel] = []
var _template_items: Array[Panel] = []
var _page_span: float = 0.0
var _track_base_x: float = 0.0
var _current_date: Dictionary = {}
var _today_date: Dictionary = {}
var _time_system: Node = null


func _ready() -> void:
	_track = _resolve_track()
	_viewport_control = _resolve_viewport_control()
	_title_label = _resolve_title_label()
	_resolve_buttons()
	_time_system = _resolve_time_system()
	if _track == null:
		push_warning("NewsTimePopupCarouselController: missing track")
		return

	if _viewport_control != null:
		_viewport_control.clip_contents = true
		if not _viewport_control.resized.is_connected(_queue_focus_refresh):
			_viewport_control.resized.connect(_queue_focus_refresh)

	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track_base_x = _track.position.x
	_collect_slots_and_templates()
	if _slot_items.is_empty():
		push_warning("NewsTimePopupCarouselController: no date slot panels found")
		return

	anchor_slot_index = clampi(anchor_slot_index, 0, _slot_items.size() - 1)
	_connect_buttons()
	_connect_time_signal()
	_sync_today_from_source()
	if _current_date.is_empty():
		_current_date = _today_date.duplicate(true)
	_current_date = _clamp_date_not_after_today(_current_date)
	_rebuild_from_current_state(false)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)


func _input(event: InputEvent) -> void:
	if not _pointer_down and not _dragging:
		return

	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_handle_drag_motion(mouse_motion.global_position.x, mouse_motion.relative.x)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var screen_drag: InputEventScreenDrag = event as InputEventScreenDrag
		_handle_drag_motion(screen_drag.position.x, screen_drag.relative.x)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			_finish_drag()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var screen_touch: InputEventScreenTouch = event as InputEventScreenTouch
		if not screen_touch.pressed:
			_finish_drag()
			get_viewport().set_input_as_handled()


func rebuild_from_game_time() -> void:
	_sync_today_from_source()
	_current_date = _clamp_date_not_after_today(_current_date)
	_rebuild_from_current_state(false)


func _collect_slots_and_templates() -> void:
	_slot_items.clear()
	_template_items.clear()
	for child: Node in _track.get_children():
		if child is Panel:
			var slot_item: Panel = child as Panel
			_slot_items.append(slot_item)
			_template_items.append(slot_item.duplicate() as Panel)
			_configure_slot_item(slot_item)


func _configure_slot_item(item: Panel) -> void:
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.pivot_offset = item.size * 0.5
	_disable_child_mouse_filter(item)
	if not item.gui_input.is_connected(_on_item_gui_input):
		item.gui_input.connect(_on_item_gui_input)
	if not item.resized.is_connected(_on_item_resized.bind(item)):
		item.resized.connect(_on_item_resized.bind(item))


func _disable_child_mouse_filter(root: Control) -> void:
	for child: Node in root.get_children():
		if child is Control:
			var child_control: Control = child as Control
			child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_disable_child_mouse_filter(child_control)


func _connect_buttons() -> void:
	if _year_previous_button != null and not _year_previous_button.pressed.is_connected(_on_year_previous_button_pressed):
		_year_previous_button.pressed.connect(_on_year_previous_button_pressed)
	if _year_next_button != null and not _year_next_button.pressed.is_connected(_on_year_next_button_pressed):
		_year_next_button.pressed.connect(_on_year_next_button_pressed)
	if _month_previous_button != null and not _month_previous_button.pressed.is_connected(_on_month_previous_button_pressed):
		_month_previous_button.pressed.connect(_on_month_previous_button_pressed)
	if _month_next_button != null and not _month_next_button.pressed.is_connected(_on_month_next_button_pressed):
		_month_next_button.pressed.connect(_on_month_next_button_pressed)


func _connect_time_signal() -> void:
	if _time_system == null or not _time_system.has_signal("日期变化"):
		return
	var callback: Callable = Callable(self, "_on_game_date_changed")
	if not _time_system.is_connected("日期变化", callback):
		_time_system.connect("日期变化", callback)


func _sync_today_from_source() -> void:
	if prefer_game_time:
		var game_date: Dictionary = _get_game_date()
		if not game_date.is_empty():
			_today_date = _normalize_date(game_date)
			display_year = int(_today_date.get("year", display_year))
			display_month = int(_today_date.get("month", display_month))
			today_day = int(_today_date.get("day", today_day))
			if _current_date.is_empty():
				_current_date = _today_date.duplicate(true)
			return
	_today_date = _normalize_date({
		"year": display_year,
		"month": display_month,
		"day": today_day,
	})
	if _current_date.is_empty():
		_current_date = _today_date.duplicate(true)


func _rebuild_from_current_state(emit_signals: bool = true) -> void:
	_current_date = _clamp_date_not_after_today(_current_date)
	display_year = int(_current_date.get("year", display_year))
	display_month = int(_current_date.get("month", display_month))
	today_day = int(_today_date.get("day", today_day))
	_page_span = _measure_page_span()
	_drag_offset_x = 0.0
	_drag_velocity_x = 0.0
	_apply_track_position(_track_base_x)
	_refresh_slot_content()
	_apply_idle_focus()
	_queue_focus_refresh()
	if emit_signals:
		_emit_current_date_changed()


func _on_item_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_begin_drag(mouse_button.global_position.x)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var screen_touch: InputEventScreenTouch = event as InputEventScreenTouch
		if screen_touch.pressed:
			_begin_drag(screen_touch.position.x)
			get_viewport().set_input_as_handled()


func _on_item_resized(item: Panel) -> void:
	item.pivot_offset = item.size * 0.5
	_page_span = _measure_page_span()
	_apply_track_position(_track_base_x + _drag_offset_x)
	if _dragging:
		_refresh_visual_state(_get_drag_focus_index())
	else:
		_queue_focus_refresh()


func _on_visibility_changed() -> void:
	if visible:
		_queue_focus_refresh()


func _begin_drag(mouse_global_x: float) -> void:
	if _slot_items.size() <= 1:
		return
	_pointer_down = true
	_dragging = false
	_press_mouse_global_x = mouse_global_x
	_drag_offset_x = 0.0
	_drag_velocity_x = 0.0
	_kill_active_tween()


func _handle_drag_motion(mouse_global_x: float, relative_x: float) -> void:
	if not _pointer_down and not _dragging:
		return

	var raw_offset_x: float = mouse_global_x - _press_mouse_global_x
	if not _dragging and absf(raw_offset_x) >= DRAG_START_DISTANCE:
		_dragging = true
	if not _dragging:
		return

	if raw_offset_x < 0.0:
		if _is_future_drag_blocked():
			_drag_offset_x = maxf(raw_offset_x * FUTURE_DRAG_DAMPING, -_page_span * FUTURE_DRAG_MAX_RATIO)
		else:
			_drag_offset_x = clampf(raw_offset_x, -_page_span, 0.0)
	else:
		_drag_offset_x = clampf(raw_offset_x, 0.0, _page_span)

	_drag_velocity_x = relative_x * 60.0
	_apply_track_position(_track_base_x + _drag_offset_x)
	_refresh_visual_state(_get_drag_focus_index())


func _finish_drag() -> void:
	if not _pointer_down and not _dragging:
		return
	_pointer_down = false
	if not _dragging:
		return
	_dragging = false

	var target_step: int = _resolve_snap_step()
	if target_step == 0:
		_animate_to_rest()
		return
	_animate_commit_step(target_step)


func _on_year_previous_button_pressed() -> void:
	_shift_current_by_months(-12)


func _on_year_next_button_pressed() -> void:
	_shift_current_by_months(12)


func _on_month_previous_button_pressed() -> void:
	_shift_current_by_months(-1)


func _on_month_next_button_pressed() -> void:
	_shift_current_by_months(1)


func _shift_current_by_months(month_delta: int) -> void:
	if month_delta == 0:
		return
	_kill_active_tween()
	var target_date: Dictionary = _shift_month(_current_date, month_delta)
	target_date = _clamp_date_not_after_today(target_date)
	if _compare_dates(target_date, _current_date) == 0:
		_animate_to_rest()
		return
	_current_date = target_date
	_rebuild_from_current_state(true)


func _animate_to_rest() -> void:
	_kill_active_tween()
	var start_x: float = _track.position.x
	var target_x: float = _track_base_x
	var duration_value: float = _compute_snap_duration(start_x, target_x)
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUART)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.tween_method(_tween_drag_position, start_x, target_x, duration_value)
	_active_tween.finished.connect(func() -> void:
		_drag_offset_x = 0.0
		_drag_velocity_x = 0.0
		_apply_track_position(_track_base_x)
		_apply_idle_focus()
		_queue_focus_refresh()
		_active_tween = null
	)


func _animate_commit_step(step: int) -> void:
	var direction: int = signi(step)
	if direction == 0:
		_animate_to_rest()
		return

	_kill_active_tween()
	var start_x: float = _track.position.x
	var target_x: float = _track_base_x - float(direction) * _page_span
	var duration_value: float = _compute_snap_duration(start_x, target_x)
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUART)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.tween_method(_tween_drag_position, start_x, target_x, duration_value)
	_active_tween.finished.connect(func() -> void:
		_commit_step(direction)
		_active_tween = null
	)


func _tween_drag_position(current_x: float) -> void:
	_apply_track_position(current_x)
	_refresh_visual_state(float(anchor_slot_index) - ((current_x - _track_base_x) / max(_page_span, 1.0)))


func _commit_step(direction: int) -> void:
	var target_date: Dictionary = _current_date
	if direction > 0:
		target_date = _shift_date(_current_date, 1)
	else:
		target_date = _shift_date(_current_date, -1)

	target_date = _clamp_date_not_after_today(target_date)
	_drag_offset_x = 0.0
	_drag_velocity_x = 0.0
	_apply_track_position(_track_base_x)
	if _compare_dates(target_date, _current_date) != 0:
		_current_date = target_date
		_rebuild_from_current_state(true)
	else:
		_apply_idle_focus()
		_queue_focus_refresh()


func _resolve_snap_step() -> int:
	if _is_future_drag_blocked() and _drag_offset_x < 0.0:
		return 0
	if absf(_drag_velocity_x) >= active_velocity_threshold:
		return 1 if _drag_velocity_x < 0.0 else -1
	if absf(_drag_offset_x) >= _page_span * SNAP_DISTANCE_RATIO:
		return 1 if _drag_offset_x < 0.0 else -1
	return 0


func _is_future_drag_blocked() -> bool:
	var next_date: Dictionary = _shift_date(_current_date, 1)
	return _compare_dates(next_date, _today_date) > 0


func _refresh_slot_content() -> void:
	for index: int in range(_slot_items.size()):
		var offset_from_center: int = index - anchor_slot_index
		var slot_date: Dictionary = _shift_date(_current_date, offset_from_center)
		_apply_date_to_slot(_slot_items[index], slot_date)
	_update_title()


func _apply_date_to_slot(slot_item: Panel, slot_date: Dictionary) -> void:
	var template_index: int = _get_template_index_for_date(slot_date)
	_apply_template_to_item(slot_item, template_index)
	var labels: Array[Label] = _get_card_labels(slot_item)
	if labels.size() < 3:
		return

	var year: int = int(slot_date.get("year", display_year))
	var month: int = int(slot_date.get("month", display_month))
	var day: int = int(slot_date.get("day", 1))
	labels[0].text = _get_week_day_text(year, month, day)
	labels[1].text = str(day)
	labels[2].text = "%02d月" % month


func _get_template_index_for_date(slot_date: Dictionary) -> int:
	if _template_items.is_empty():
		return 0

	var compare_result: int = _compare_dates(slot_date, _today_date)
	if compare_result > 0:
		var future_days: int = max(_days_between(_today_date, slot_date), 1)
		if future_days <= 1:
			return mini(3, _template_items.size() - 1)
		return mini(4, _template_items.size() - 1)
	if compare_result == 0:
		return mini(2, _template_items.size() - 1)

	var past_days: int = abs(_days_between(slot_date, _today_date))
	if past_days <= 1:
		return mini(1, _template_items.size() - 1)
	return 0


func _apply_template_to_item(target_item: Panel, template_index: int) -> void:
	if _template_items.is_empty():
		return
	var clamped_index: int = clampi(template_index, 0, _template_items.size() - 1)
	var template_item: Panel = _template_items[clamped_index]
	var panel_style: Variant = template_item.get("theme_override_styles/panel")
	if panel_style is StyleBox:
		target_item.set("theme_override_styles/panel", (panel_style as StyleBox).duplicate())

	var target_labels: Array[Label] = _get_card_labels(target_item)
	var template_labels: Array[Label] = _get_card_labels(template_item)
	var label_count: int = mini(target_labels.size(), template_labels.size())
	for index: int in range(label_count):
		_copy_label_visuals(template_labels[index], target_labels[index])


func _copy_label_visuals(source_label: Label, target_label: Label) -> void:
	target_label.set("theme_override_colors/font_color", source_label.get("theme_override_colors/font_color"))
	target_label.set("theme_override_colors/font_outline_color", source_label.get("theme_override_colors/font_outline_color"))
	target_label.set("theme_override_constants/outline_size", source_label.get("theme_override_constants/outline_size"))
	target_label.set("theme_override_fonts/font", source_label.get("theme_override_fonts/font"))
	target_label.set("theme_override_font_sizes/font_size", source_label.get("theme_override_font_sizes/font_size"))


func _get_card_labels(card_root: Panel) -> Array[Label]:
	var labels: Array[Label] = []
	for child: Node in card_root.get_children():
		if child is Label:
			labels.append(child as Label)
	return labels


func _get_drag_focus_index() -> float:
	return float(anchor_slot_index) - (_drag_offset_x / max(_page_span, 1.0))


func _apply_track_position(target_x: float) -> void:
	if _track != null:
		_track.position.x = target_x


func _apply_idle_focus() -> void:
	_refresh_visual_state(float(anchor_slot_index))
	_update_title()


func _queue_focus_refresh() -> void:
	if _focus_refresh_queued:
		return
	_focus_refresh_queued = true
	call_deferred("_apply_focus_refresh_after_layout")


func _apply_focus_refresh_after_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_focus_refresh_queued = false
	if not is_inside_tree() or _track == null:
		return

	for item: Panel in _slot_items:
		if item != null and is_instance_valid(item):
			item.pivot_offset = item.size * 0.5
	_page_span = _measure_page_span()
	_apply_track_position(_track_base_x + _drag_offset_x)
	if _dragging:
		_refresh_visual_state(_get_drag_focus_index())
	else:
		_apply_idle_focus()


func _refresh_visual_state(focus_index: float) -> void:
	for index: int in range(_slot_items.size()):
		var item: Panel = _slot_items[index]
		var distance: float = absf(float(index) - focus_index)
		var scale_value: float = _sample_visual_value(distance, front_scale, near_scale, far_scale)
		var alpha_value: float = _sample_visual_value(distance, front_alpha, near_alpha, far_alpha)
		item.scale = Vector2.ONE * scale_value
		item.modulate = Color(1.0, 1.0, 1.0, alpha_value)
		item.z_index = int(roundi(100.0 - minf(distance, 9.0) * 10.0))


func _sample_visual_value(distance: float, front_value: float, near_value: float, far_value: float) -> float:
	if distance <= 1.0:
		return lerpf(front_value, near_value, distance)
	if distance <= 2.0:
		return lerpf(near_value, far_value, distance - 1.0)
	return far_value


func _measure_page_span() -> float:
	if _slot_items.is_empty():
		return 0.0
	var first_item: Panel = _slot_items[0]
	var item_width: float = first_item.size.x
	if is_zero_approx(item_width):
		item_width = first_item.custom_minimum_size.x
	return item_width + float(_track.get_theme_constant("separation"))


func _compute_snap_duration(start_x: float, target_x: float) -> float:
	var distance_ratio: float = clampf(absf(start_x - target_x) / max(_page_span, 1.0), 0.0, 1.0)
	return maxf(lerpf(SNAP_MIN_DURATION, SNAP_MAX_DURATION, distance_ratio), snap_duration)


func _update_title() -> void:
	if _title_label == null:
		return
	_title_label.text = "%s%04d-%02d-%02d%s" % [
		title_prefix,
		int(_current_date.get("year", display_year)),
		int(_current_date.get("month", display_month)),
		int(_current_date.get("day", 1)),
		title_suffix,
	]


func _emit_current_date_changed() -> void:
	current_day_changed.emit(int(_current_date.get("day", 1)))
	current_date_changed.emit(_current_date.duplicate(true))


func _resolve_track() -> HBoxContainer:
	if not track_path.is_empty():
		return get_node_or_null(track_path) as HBoxContainer
	for child: Node in _find_descendants_of_type(self, HBoxContainer):
		var container: HBoxContainer = child as HBoxContainer
		if _count_panel_children(container) >= 5:
			return container
	return null


func _resolve_viewport_control() -> Control:
	if not viewport_path.is_empty():
		return get_node_or_null(viewport_path) as Control
	if _track != null and _track.get_parent() is Control:
		return _track.get_parent() as Control
	return null


func _resolve_title_label() -> Label:
	if not current_time_title_path.is_empty():
		return get_node_or_null(current_time_title_path) as Label
	var top_bar: Control = _resolve_top_bar()
	if top_bar == null:
		return null
	for child: Node in top_bar.get_children():
		if child is Label:
			return child as Label
	return null


func _resolve_buttons() -> void:
	var buttons: Array[Button] = _resolve_top_bar_buttons()
	if not year_previous_button_path.is_empty():
		_year_previous_button = get_node_or_null(year_previous_button_path) as Button
	elif buttons.size() >= 4:
		_year_previous_button = buttons[0]

	if not month_previous_button_path.is_empty():
		_month_previous_button = get_node_or_null(month_previous_button_path) as Button
	elif buttons.size() >= 4:
		_month_previous_button = buttons[1]

	if not month_next_button_path.is_empty():
		_month_next_button = get_node_or_null(month_next_button_path) as Button
	elif buttons.size() >= 4:
		_month_next_button = buttons[2]

	if not year_next_button_path.is_empty():
		_year_next_button = get_node_or_null(year_next_button_path) as Button
	elif buttons.size() >= 4:
		_year_next_button = buttons[3]


func _resolve_top_bar() -> Control:
	for child: Node in get_children():
		if child is Control and _count_descendants_of_type(child, Button) >= 4:
			return child as Control
	return null


func _resolve_top_bar_buttons() -> Array[Button]:
	var top_bar: Control = _resolve_top_bar()
	var buttons: Array[Button] = []
	if top_bar == null:
		return buttons
	for child: Node in top_bar.get_children():
		if child is Button:
			buttons.append(child as Button)
	for i: int in range(buttons.size()):
		for j: int in range(i + 1, buttons.size()):
			if buttons[j].position.x < buttons[i].position.x:
				var temp: Button = buttons[i]
				buttons[i] = buttons[j]
				buttons[j] = temp
	return buttons


func _count_panel_children(container: HBoxContainer) -> int:
	var count: int = 0
	for child: Node in container.get_children():
		if child is Panel:
			count += 1
	return count


func _count_descendants_of_type(root: Node, target_type: Variant) -> int:
	var count: int = 0
	for child: Node in root.get_children():
		if is_instance_of(child, target_type):
			count += 1
		count += _count_descendants_of_type(child, target_type)
	return count


func _find_descendants_of_type(root: Node, target_type: Variant) -> Array[Node]:
	var results: Array[Node] = []
	for child: Node in root.get_children():
		if is_instance_of(child, target_type):
			results.append(child)
		results.append_array(_find_descendants_of_type(child, target_type))
	return results


func _resolve_time_system() -> Node:
	var from_root: Node = get_node_or_null("/root/GameDataManager/TimeSystem")
	if from_root != null:
		return from_root
	return get_node_or_null("/root/GameDataManager/时间")


func _get_game_date() -> Dictionary:
	if _time_system == null:
		return {}
	if _time_system.has_method("获取当前日期数据"):
		var date_data: Dictionary = _time_system.call("获取当前日期数据") as Dictionary
		if not date_data.is_empty():
			return {
				"year": int(date_data.get("year", display_year)),
				"month": int(date_data.get("month", display_month)),
				"day": int(date_data.get("day", today_day)),
			}
	return {}


func _normalize_date(date_value: Dictionary) -> Dictionary:
	var year: int = max(int(date_value.get("year", display_year)), 1)
	var month: int = clampi(int(date_value.get("month", display_month)), 1, 12)
	var max_day: int = _get_days_in_month(year, month)
	var day: int = clampi(int(date_value.get("day", today_day)), 1, max_day)
	return {"year": year, "month": month, "day": day}


func _clamp_date_not_after_today(date_value: Dictionary) -> Dictionary:
	var normalized_date: Dictionary = _normalize_date(date_value)
	if _today_date.is_empty():
		return normalized_date
	if _compare_dates(normalized_date, _today_date) > 0:
		return _today_date.duplicate(true)
	return normalized_date


func _shift_month(date_value: Dictionary, month_delta: int) -> Dictionary:
	var result: Dictionary = _normalize_date(date_value)
	var year: int = int(result.get("year", display_year))
	var month: int = int(result.get("month", display_month)) + month_delta
	var day: int = int(result.get("day", 1))
	while month < 1:
		month += 12
		year -= 1
	while month > 12:
		month -= 12
		year += 1
	var max_day: int = _get_days_in_month(year, month)
	return _normalize_date({
		"year": max(year, 1),
		"month": month,
		"day": min(day, max_day),
	})


func _shift_date(date_value: Dictionary, day_delta: int) -> Dictionary:
	var result: Dictionary = _normalize_date(date_value)
	var year: int = int(result.get("year", display_year))
	var month: int = int(result.get("month", display_month))
	var day: int = int(result.get("day", 1)) + day_delta
	while day < 1:
		month -= 1
		if month < 1:
			month = 12
			year -= 1
		day += _get_days_in_month(year, month)
	while day > _get_days_in_month(year, month):
		day -= _get_days_in_month(year, month)
		month += 1
		if month > 12:
			month = 1
			year += 1
	return _normalize_date({
		"year": max(year, 1),
		"month": month,
		"day": day,
	})


func _compare_dates(left_date: Dictionary, right_date: Dictionary) -> int:
	var left_year: int = int(left_date.get("year", 0))
	var right_year: int = int(right_date.get("year", 0))
	if left_year != right_year:
		return -1 if left_year < right_year else 1
	var left_month: int = int(left_date.get("month", 0))
	var right_month: int = int(right_date.get("month", 0))
	if left_month != right_month:
		return -1 if left_month < right_month else 1
	var left_day: int = int(left_date.get("day", 0))
	var right_day: int = int(right_date.get("day", 0))
	if left_day != right_day:
		return -1 if left_day < right_day else 1
	return 0


func _days_between(from_date: Dictionary, to_date: Dictionary) -> int:
	return _days_from_civil(
		int(to_date.get("year", display_year)),
		int(to_date.get("month", display_month)),
		int(to_date.get("day", 1))
	) - _days_from_civil(
		int(from_date.get("year", display_year)),
		int(from_date.get("month", display_month)),
		int(from_date.get("day", 1))
	)


func _get_days_in_month(year: int, month: int) -> int:
	if _time_system != null and _time_system.has_method("获取当月天数"):
		return int(_time_system.call("获取当月天数", year, month))
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if _is_leap_year(year) else 28
		_:
			return 30


func _is_leap_year(year: int) -> bool:
	if year % 400 == 0:
		return true
	if year % 100 == 0:
		return false
	return year % 4 == 0


func _get_week_day_text(year: int, month: int, day: int) -> String:
	var day_index: int = posmod(_days_from_civil(year, month, day) + 4, 7)
	if day_index < 0 or day_index >= DEFAULT_WEEKDAY_LABELS.size():
		return DEFAULT_WEEKDAY_LABELS[0]
	return DEFAULT_WEEKDAY_LABELS[day_index]


func _days_from_civil(year: int, month: int, day: int) -> int:
	var adjusted_year: int = year - (1 if month <= 2 else 0)
	var era: int = int(floor(float(adjusted_year) / 400.0))
	var year_of_era: int = adjusted_year - era * 400
	var adjusted_month: int = month - 3 if month > 2 else month + 9
	var day_of_year: int = int((153 * adjusted_month + 2) / 5) + day - 1
	var day_of_era: int = year_of_era * 365 + int(year_of_era / 4) - int(year_of_era / 100) + day_of_year
	return era * 146097 + day_of_era - 719468


func _on_game_date_changed(year: int, month: int, day: int) -> void:
	_today_date = _normalize_date({"year": year, "month": month, "day": day})
	display_year = year
	display_month = month
	today_day = day
	if _compare_dates(_current_date, _today_date) > 0:
		_current_date = _today_date.duplicate(true)
	_rebuild_from_current_state(false)


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
