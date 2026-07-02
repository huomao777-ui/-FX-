extends Control
class_name AppInteractionAreaController

@export var 双击回退延迟秒数: float = 0.08
@export var 回退冷却秒数: float = 0.28
@export var 弹窗关闭保护秒数: float = 0.35

var _app_root_controller: Node = null
var _pending_back_request_id: int = 0
var _next_allowed_back_time_msec: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_app_root_controller = get_parent()

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed or not mouse_event.double_click:
		return
	if _is_point_inside_interaction_area(mouse_event.global_position):
		return
	if not _can_trigger_back_now():
		return
	_pending_back_request_id += 1
	var request_id: int = _pending_back_request_id
	var delay_seconds: float = maxf(双击回退延迟秒数, 0.0)
	if delay_seconds <= 0.0:
		_perform_back_request(request_id)
		return
	var timer := get_tree().create_timer(delay_seconds)
	timer.timeout.connect(_on_back_delay_timeout.bind(request_id))

func _on_back_delay_timeout(request_id: int) -> void:
	_perform_back_request(request_id)

func _perform_back_request(request_id: int) -> void:
	if request_id != _pending_back_request_id:
		return
	if _app_root_controller == null or not is_instance_valid(_app_root_controller):
		return
	var viewport := get_viewport()
	if _app_root_controller.has_method("执行外部双击回退"):
		var result: String = str(_app_root_controller.call("执行外部双击回退"))
		if not result.is_empty():
			_apply_back_cooldown(result)
		if not result.is_empty() and viewport != null:
			viewport.set_input_as_handled()

func _is_point_inside_interaction_area(global_position: Vector2) -> bool:
	return Rect2(global_position_of_area(), size).has_point(global_position)

func global_position_of_area() -> Vector2:
	return global_position

func _can_trigger_back_now() -> bool:
	return Time.get_ticks_msec() >= _next_allowed_back_time_msec

func _apply_back_cooldown(result: String) -> void:
	var cooldown_seconds: float = maxf(回退冷却秒数, 0.0)
	if result == "popup":
		cooldown_seconds = maxf(cooldown_seconds, 弹窗关闭保护秒数)
	_next_allowed_back_time_msec = Time.get_ticks_msec() + int(roundi(cooldown_seconds * 1000.0))
