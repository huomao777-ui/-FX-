extends Control
class_name NewsPopupCarouselController

signal current_item_changed(current_index: int)

const DRAG_START_DISTANCE: float = 8.0
const SNAP_DISTANCE_RATIO: float = 0.28
const SNAP_MIN_DURATION: float = 0.14
const SNAP_MAX_DURATION: float = 0.24

@export var track_path: NodePath
@export var viewport_path: NodePath
@export var title_label_path: NodePath
@export var previous_button_path: NodePath
@export var next_button_path: NodePath
@export var preferred_title_label_name: String = "名称"
@export_range(0, 8, 1) var anchor_slot_index: int = 2
@export var front_scale: float = 1.16
@export var near_scale: float = 0.96
@export var far_scale: float = 0.84
@export var front_alpha: float = 1.0
@export var near_alpha: float = 0.9
@export var far_alpha: float = 0.66
@export var active_velocity_threshold: float = 900.0
@export var snap_duration: float = 0.18

var _pointer_down: bool = false
var _dragging: bool = false
var _press_mouse_global_x: float = 0.0
var _drag_offset_x: float = 0.0
var _drag_velocity_x: float = 0.0
var _active_tween: Tween = null
var _current_index: int = 0
var _focus_refresh_queued: bool = false

var _track: HBoxContainer = null
var _viewport_control: Control = null
var _title_label: Label = null
var _previous_button: Button = null
var _next_button: Button = null
var _items: Array[Panel] = []
var _page_span: float = 0.0
var _track_base_x: float = 0.0


func _ready() -> void:
	_track = _resolve_track()
	_viewport_control = _resolve_viewport_control()
	_title_label = _resolve_title_label()
	_previous_button = _resolve_previous_button()
	_next_button = _resolve_next_button()
	_collect_items()
	if _track == null or _items.size() <= 1:
		push_warning("NewsPopupCarouselController: missing track or not enough items")
		return

	if _viewport_control != null:
		_viewport_control.clip_contents = true
		if not _viewport_control.resized.is_connected(_queue_focus_refresh):
			_viewport_control.resized.connect(_queue_focus_refresh)

	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track_base_x = _track.position.x
	anchor_slot_index = clampi(anchor_slot_index, 0, _items.size() - 1)
	_page_span = _measure_page_span()
	_configure_items()
	_connect_buttons()
	_apply_track_position(_track_base_x)
	_apply_idle_focus()
	_queue_focus_refresh()
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	current_item_changed.emit(_current_index)


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


func collect_items() -> void:
	_items.clear()
	if _track == null:
		return
	for child: Node in _track.get_children():
		if child is Panel:
			_items.append(child as Panel)


func _collect_items() -> void:
	collect_items()


func _configure_items() -> void:
	for item: Panel in _items:
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
	if _previous_button != null and not _previous_button.pressed.is_connected(_on_previous_button_pressed):
		_previous_button.pressed.connect(_on_previous_button_pressed)
	if _next_button != null and not _next_button.pressed.is_connected(_on_next_button_pressed):
		_next_button.pressed.connect(_on_next_button_pressed)


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
		_refresh_visual_state(_get_drag_progress())
	else:
		_queue_focus_refresh()


func _on_previous_button_pressed() -> void:
	_step(-1)


func _on_next_button_pressed() -> void:
	_step(1)


func _on_visibility_changed() -> void:
	if visible:
		_queue_focus_refresh()


func _begin_drag(mouse_global_x: float) -> void:
	if _items.size() <= 1:
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

	_drag_offset_x = clampf(raw_offset_x, -_page_span, _page_span)
	_drag_velocity_x = relative_x * 60.0
	_apply_track_position(_track_base_x + _drag_offset_x)
	_refresh_visual_state(_get_drag_progress())


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


func _step(step: int) -> void:
	if _items.size() <= 1:
		return
	_kill_active_tween()
	_animate_commit_step(step)


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
	)


func _animate_commit_step(step: int) -> void:
	var direction: int = signi(step)
	if direction == 0:
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
	)


func _tween_drag_position(current_x: float) -> void:
	_apply_track_position(current_x)
	_refresh_visual_state((current_x - _track_base_x) / max(_page_span, 1.0))


func _commit_step(direction: int) -> void:
	if direction > 0:
		_rotate_left()
		_current_index = posmod(_current_index + 1, _items.size())
	else:
		_rotate_right()
		_current_index = posmod(_current_index - 1, _items.size())
	_drag_offset_x = 0.0
	_drag_velocity_x = 0.0
	_apply_track_position(_track_base_x)
	_apply_idle_focus()
	_queue_focus_refresh()
	current_item_changed.emit(_current_index)


func _rotate_left() -> void:
	if _items.is_empty():
		return
	var first_item: Panel = _items.pop_front()
	_items.append(first_item)
	_track.move_child(first_item, _track.get_child_count() - 1)


func _rotate_right() -> void:
	if _items.is_empty():
		return
	var last_item: Panel = _items.pop_back()
	_items.push_front(last_item)
	_track.move_child(last_item, 0)


func _resolve_snap_step() -> int:
	if absf(_drag_velocity_x) >= active_velocity_threshold:
		return 1 if _drag_velocity_x < 0.0 else -1
	if absf(_drag_offset_x) >= _page_span * SNAP_DISTANCE_RATIO:
		return 1 if _drag_offset_x < 0.0 else -1
	return 0


func _get_drag_progress() -> float:
	return _drag_offset_x / max(_page_span, 1.0)


func _apply_track_position(target_x: float) -> void:
	if _track != null:
		_track.position.x = target_x


func _apply_idle_focus() -> void:
	_refresh_visual_state(0.0)
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
	for item: Panel in _items:
		if item != null and is_instance_valid(item):
			item.pivot_offset = item.size * 0.5
	_page_span = _measure_page_span()
	_apply_track_position(_track_base_x + _drag_offset_x)
	if _dragging:
		_refresh_visual_state(_get_drag_progress())
	else:
		_apply_idle_focus()


func _refresh_visual_state(normalized_progress: float) -> void:
	var focus_index: float = float(anchor_slot_index) - normalized_progress
	for index: int in range(_items.size()):
		var item: Panel = _items[index]
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
	if _items.is_empty():
		return 0.0
	var first_item: Panel = _items[0]
	var item_width: float = first_item.size.x
	if is_zero_approx(item_width):
		item_width = first_item.custom_minimum_size.x
	return item_width + float(_track.get_theme_constant("separation"))


func _compute_snap_duration(start_x: float, target_x: float) -> float:
	var distance_ratio: float = clampf(absf(start_x - target_x) / max(_page_span, 1.0), 0.0, 1.0)
	return max(lerpf(SNAP_MIN_DURATION, SNAP_MAX_DURATION, distance_ratio), snap_duration)


func _update_title() -> void:
	if _title_label == null:
		return
	var current_item: Panel = _get_current_item()
	if current_item == null:
		return
	var source_label: Label = _find_best_title_label(current_item)
	if source_label != null:
		_title_label.text = source_label.text


func _get_current_item() -> Panel:
	if anchor_slot_index < 0 or anchor_slot_index >= _items.size():
		return null
	return _items[anchor_slot_index]


func _find_best_title_label(root: Node) -> Label:
	if not preferred_title_label_name.is_empty():
		var named_label: Label = _find_label_by_name(root, preferred_title_label_name)
		if named_label != null:
			return named_label
	var labels: Array[Label] = _find_labels(root)
	var best_label: Label = null
	var best_score: float = -INF
	for label: Label in labels:
		var score: float = _score_title_label(label)
		if score > best_score:
			best_score = score
			best_label = label
	return best_label


func _score_title_label(label: Label) -> float:
	var width: float = maxf(label.size.x, label.get_minimum_size().x)
	var score: float = width
	var name_text: String = String(label.name)
	if name_text == "名称":
		score += 100000.0
	elif name_text.contains("名称"):
		score += 50000.0
	if name_text == "标题":
		score += 30000.0
	elif name_text.contains("标题"):
		score += 18000.0
	if label.text.length() <= 8:
		score += 3000.0
	return score


func _find_label_by_name(root: Node, target_name: String) -> Label:
	for child: Node in root.get_children():
		if child is Label and String(child.name) == target_name:
			return child as Label
		var found: Label = _find_label_by_name(child, target_name)
		if found != null:
			return found
	return null


func _find_labels(root: Node) -> Array[Label]:
	var labels: Array[Label] = []
	for child: Node in root.get_children():
		if child is Label:
			labels.append(child as Label)
		labels.append_array(_find_labels(child))
	return labels


func _resolve_track() -> HBoxContainer:
	if not track_path.is_empty():
		return get_node_or_null(track_path) as HBoxContainer
	for child: Node in _find_descendants_of_type(self, HBoxContainer):
		var container: HBoxContainer = child as HBoxContainer
		if _count_panel_children(container) >= 3:
			return container
	return null


func _resolve_viewport_control() -> Control:
	if not viewport_path.is_empty():
		return get_node_or_null(viewport_path) as Control
	if _track != null and _track.get_parent() is Control:
		return _track.get_parent() as Control
	return null


func _resolve_title_label() -> Label:
	if not title_label_path.is_empty():
		return get_node_or_null(title_label_path) as Label
	var top_bar: Control = _resolve_top_bar()
	if top_bar == null:
		return null
	for child: Node in top_bar.get_children():
		if child is Label:
			return child as Label
	return null


func _resolve_previous_button() -> Button:
	if not previous_button_path.is_empty():
		return get_node_or_null(previous_button_path) as Button
	var buttons: Array[Button] = _resolve_top_bar_buttons()
	if buttons.size() >= 2:
		return buttons[0]
	return null


func _resolve_next_button() -> Button:
	if not next_button_path.is_empty():
		return get_node_or_null(next_button_path) as Button
	var buttons: Array[Button] = _resolve_top_bar_buttons()
	if buttons.size() >= 2:
		return buttons[buttons.size() - 1]
	return null


func _resolve_top_bar() -> Control:
	for child: Node in get_children():
		if child is Control and _count_descendants_of_type(child, Button) >= 2:
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


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
