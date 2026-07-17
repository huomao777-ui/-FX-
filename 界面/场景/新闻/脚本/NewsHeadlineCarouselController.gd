extends Panel
class_name NewsHeadlineCarouselController

signal page_changed(current_index: int)
signal drag_preview_changed(from_index: int, to_index: int, progress: float, velocity: float)
signal headline_activated(card: Panel, index: int)

const DRAG_START_DISTANCE: float = 8.0
const EDGE_DAMPING: float = 0.35
const SNAP_DISTANCE_RATIO: float = 0.33
const SNAP_MIN_DURATION: float = 0.16
const SNAP_MAX_DURATION: float = 0.24

@export var switch_distance_ratio: float = 0.22
@export var switch_velocity_threshold: float = 1200.0
@export var snap_duration: float = 0.20
# Inner HBox that directly contains the headline cards.
# Bind this to the moving track, not the outer viewport panel.
@export var track_path: NodePath
# Page-indicator controller under the headline area.
# It receives drag preview progress so the liquid-dot animation can react during dragging.
@export var indicator_path: NodePath

var _current_index: int = 0
var _pointer_down: bool = false
var _dragging: bool = false
var _press_mouse_global_x: float = 0.0
var _drag_offset_x: float = 0.0
var _drag_velocity_x: float = 0.0
var _drag_from_index: int = 0
var _drag_to_index: int = 0
var _page_span: float = 0.0
var _track_base_x: float = 0.0
var _active_tween: Tween = null
var _track: HBoxContainer = null
var _cards: Array[Panel] = []
var _indicator: NewsPageIndicatorController = null
var _pressed_card: Panel = null
var _pressed_index: int = -1


func _ready() -> void:
	_track = _resolve_track()
	_indicator = _resolve_indicator()
	_collect_cards()
	if _track == null or _cards.size() <= 1:
		push_warning("NewsHeadlineCarouselController: headline track is missing or has too few cards")
		return
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track_base_x = _track.position.x
	_page_span = _measure_page_span()
	_configure_card_interaction()
	_apply_track_position(_get_index_target_x(_current_index))
	_update_indicator_state(_current_index, _current_index, 0.0, 0.0)
	page_changed.emit(_current_index)


func _input(event: InputEvent) -> void:
	if not _pointer_down and not _dragging:
		return
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		_handle_drag_motion(motion_event.global_position.x, motion_event.relative.x)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		_handle_drag_motion(drag_event.position.x, drag_event.relative.x)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_finish_drag()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if not touch_event.pressed:
			_finish_drag()
			get_viewport().set_input_as_handled()


func _on_card_gui_input(event: InputEvent, card: Panel) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_begin_drag(mouse_event.global_position.x, card)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_drag(touch_event.position.x, card)
			get_viewport().set_input_as_handled()


func _begin_drag(mouse_global_x: float, card: Panel) -> void:
	_pointer_down = true
	_dragging = false
	_press_mouse_global_x = mouse_global_x
	_drag_offset_x = 0.0
	_drag_velocity_x = 0.0
	_drag_from_index = _current_index
	_drag_to_index = _current_index
	_pressed_card = card
	_pressed_index = _cards.find(card)
	_kill_active_tween()


func _handle_drag_motion(mouse_global_x: float, relative_x: float) -> void:
	if not _pointer_down and not _dragging:
		return
	var raw_offset_x: float = mouse_global_x - _press_mouse_global_x
	if not _dragging and absf(raw_offset_x) >= DRAG_START_DISTANCE:
		_dragging = true
	if not _dragging:
		return
	_drag_offset_x = _get_damped_offset(raw_offset_x)
	_drag_velocity_x = relative_x * 60.0
	_drag_to_index = _resolve_drag_target_index(_drag_offset_x)
	_apply_track_position(_get_index_target_x(_drag_from_index) + _drag_offset_x)
	_emit_drag_state()


func _finish_drag() -> void:
	if not _pointer_down and not _dragging:
		return
	_pointer_down = false
	if not _dragging:
		_emit_card_activation_if_possible()
		_clear_pressed_card_state()
		return
	_dragging = false
	var target_index: int = _resolve_snap_index()
	_current_index = target_index
	_clear_pressed_card_state()
	_animate_to_index(target_index)


func _resolve_snap_index() -> int:
	var switch_distance: float = _page_span * SNAP_DISTANCE_RATIO
	if absf(_drag_velocity_x) >= switch_velocity_threshold:
		return _drag_to_index
	if absf(_drag_offset_x) >= switch_distance:
		return _drag_to_index
	return _drag_from_index


func _resolve_track() -> HBoxContainer:
	if not track_path.is_empty():
		return get_node_or_null(track_path) as HBoxContainer
	for child: Node in get_children():
		if child is HBoxContainer:
			var candidate: HBoxContainer = child as HBoxContainer
			if _count_panel_children(candidate) >= 2:
				return candidate
	return null


func _resolve_indicator() -> NewsPageIndicatorController:
	if not indicator_path.is_empty():
		return get_node_or_null(indicator_path) as NewsPageIndicatorController
	for child: Node in get_children():
		if child is NewsPageIndicatorController:
			return child as NewsPageIndicatorController
	return null


func _collect_cards() -> void:
	_cards.clear()
	if _track == null:
		return
	for child: Node in _track.get_children():
		if child is Panel:
			_cards.append(child as Panel)


func _configure_card_interaction() -> void:
	for card: Panel in _cards:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_disable_child_mouse_filter(card)
		if not card.gui_input.is_connected(_on_card_gui_input.bind(card)):
			card.gui_input.connect(_on_card_gui_input.bind(card))


func _measure_page_span() -> float:
	if _cards.is_empty():
		return 0.0
	var first_card: Panel = _cards[0]
	var card_width: float = first_card.size.x
	if is_zero_approx(card_width):
		card_width = first_card.custom_minimum_size.x
	return card_width + float(_track.get_theme_constant("separation"))


func _resolve_drag_target_index(offset_x: float) -> int:
	if is_zero_approx(offset_x):
		return _drag_from_index
	if offset_x < 0.0:
		return min(_drag_from_index + 1, _cards.size() - 1)
	return max(_drag_from_index - 1, 0)


func _get_damped_offset(raw_offset_x: float) -> float:
	if _page_span <= 0.0:
		return raw_offset_x
	var damped: float = clampf(raw_offset_x, -_page_span, _page_span)
	if _current_index == 0 and damped > 0.0:
		return damped * EDGE_DAMPING
	if _current_index == _cards.size() - 1 and damped < 0.0:
		return damped * EDGE_DAMPING
	return damped


func _emit_drag_state() -> void:
	var progress: float = clampf(absf(_drag_offset_x) / max(_page_span, 1.0), 0.0, 1.0)
	var normalized_velocity: float = clampf(absf(_drag_velocity_x) / max(switch_velocity_threshold, 1.0), 0.0, 1.0)
	drag_preview_changed.emit(_drag_from_index, _drag_to_index, progress, normalized_velocity)
	_update_indicator_state(_drag_from_index, _drag_to_index, progress, normalized_velocity)


func _animate_to_index(target_index: int) -> void:
	_kill_active_tween()
	var start_x: float = _track.position.x
	var target_x: float = _get_index_target_x(target_index)
	var travel_ratio: float = clampf(absf(start_x - target_x) / max(_page_span, 1.0), 0.0, 1.0)
	var settle_duration: float = lerpf(SNAP_MIN_DURATION, SNAP_MAX_DURATION, travel_ratio)
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUART)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.tween_method(_animate_track_position, start_x, target_x, max(settle_duration, snap_duration))
	_active_tween.finished.connect(func() -> void:
		_drag_offset_x = 0.0
		_drag_velocity_x = 0.0
		_drag_from_index = _current_index
		_drag_to_index = _current_index
		_apply_track_position(target_x)
		_update_indicator_state(_current_index, _current_index, 0.0, 0.0)
		page_changed.emit(_current_index)
	)


func _animate_track_position(current_x: float) -> void:
	_apply_track_position(current_x)
	var from_index: int = _drag_from_index
	var to_index: int = _current_index if _current_index != _drag_from_index else _drag_to_index
	var progress: float = clampf(absf(current_x - _get_index_target_x(from_index)) / max(_page_span, 1.0), 0.0, 1.0)
	_update_indicator_state(from_index, to_index, progress, 0.0)


func _apply_track_position(target_x: float) -> void:
	if _track != null:
		_track.position.x = target_x


func _get_index_target_x(index: int) -> float:
	return _track_base_x - float(index) * _page_span


func _update_indicator_state(from_index: int, to_index: int, progress: float, velocity: float) -> void:
	if _indicator != null:
		_indicator.update_indicator(from_index, to_index, progress, velocity)


func _count_panel_children(container: HBoxContainer) -> int:
	var count: int = 0
	for child: Node in container.get_children():
		if child is Panel:
			count += 1
	return count


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _emit_card_activation_if_possible() -> void:
	if _pressed_card == null or _pressed_index < 0:
		return
	if _pressed_index >= _cards.size():
		return
	if _pressed_index != _current_index:
		return
	headline_activated.emit(_pressed_card, _pressed_index)


func _clear_pressed_card_state() -> void:
	_pressed_card = null
	_pressed_index = -1


func _disable_child_mouse_filter(root: Control) -> void:
	for child: Node in root.get_children():
		if child is Control:
			var child_control: Control = child as Control
			child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_disable_child_mouse_filter(child_control)
