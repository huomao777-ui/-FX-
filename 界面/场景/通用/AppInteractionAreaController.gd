extends Control
class_name AppInteractionAreaController

const REFERENCE_NODE_NAME: String = "交互判定参考节点"

## 双击屏幕外触发回退前的延迟。
@export var 双击回退延迟秒数: float = 0.08
## 普通回退的冷却时间。
@export var 回退冷却秒数: float = 0.28
## 关闭弹窗后的额外保护冷却。
@export var 弹窗关闭保护秒数: float = 0.35
## 参考节点不是 Panel 时使用的默认圆角半径。
@export var 默认圆角半径: float = 0.0

var _app_root_controller: Node = null
var _pending_back_request_id: int = 0
var _next_allowed_back_time_msec: int = 0
var _reference_control: Control = null
var _cached_corner_radius: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_app_root_controller = get_parent()
	_cache_reference_control()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed or not mouse_event.double_click:
		return
	if 是否在交互范围内(mouse_event.global_position):
		return
	if not _can_trigger_back_now():
		return

	_pending_back_request_id += 1
	var request_id: int = _pending_back_request_id
	var delay_seconds: float = maxf(双击回退延迟秒数, 0.0)
	if delay_seconds <= 0.0:
		_perform_back_request(request_id)
		return

	var timer: SceneTreeTimer = get_tree().create_timer(delay_seconds)
	timer.timeout.connect(_on_back_delay_timeout.bind(request_id))


func _on_back_delay_timeout(request_id: int) -> void:
	_perform_back_request(request_id)


func _perform_back_request(request_id: int) -> void:
	if request_id != _pending_back_request_id:
		return
	if _app_root_controller == null or not is_instance_valid(_app_root_controller):
		return

	var viewport: Viewport = get_viewport()
	if _app_root_controller.has_method("执行外部双击回退"):
		var result: String = str(_app_root_controller.call("执行外部双击回退"))
		if not result.is_empty():
			_apply_back_cooldown(result)
		if not result.is_empty() and viewport != null:
			viewport.set_input_as_handled()


func 是否在交互范围内(global_position_value: Vector2) -> bool:
	var rect: Rect2 = 获取交互范围全局矩形()
	if not rect.has_point(global_position_value):
		return false

	var corner_radius: float = 获取交互范围圆角半径()
	if corner_radius <= 0.001:
		return true
	return _is_point_inside_rounded_rect(global_position_value, rect, corner_radius)


func 获取交互范围全局矩形() -> Rect2:
	var target: Control = _get_effective_reference_control()
	return Rect2(target.global_position, target.size)


func 获取交互范围圆角半径() -> float:
	if _reference_control == null:
		return maxf(默认圆角半径, 0.0)
	return maxf(_cached_corner_radius, 默认圆角半径)


func _cache_reference_control() -> void:
	_reference_control = _find_reference_control()
	_cached_corner_radius = _extract_corner_radius(_reference_control)


func _find_reference_control() -> Control:
	var found: Node = _find_descendant_by_name(self, REFERENCE_NODE_NAME)
	if found is Control:
		return found as Control
	return null


func _get_effective_reference_control() -> Control:
	if _reference_control == null or not is_instance_valid(_reference_control):
		_cache_reference_control()
	if _reference_control != null:
		return _reference_control
	return self


func _extract_corner_radius(target: Control) -> float:
	if target is Panel:
		var panel: Panel = target as Panel
		var style: Variant = panel.get("theme_override_styles/panel")
		if style is StyleBoxFlat:
			return float((style as StyleBoxFlat).corner_radius_top_left)
	return 0.0


func _is_point_inside_rounded_rect(global_position_value: Vector2, rect: Rect2, radius: float) -> bool:
	var safe_radius: float = minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
	if safe_radius <= 0.001:
		return rect.has_point(global_position_value)

	var local_point: Vector2 = global_position_value - rect.position
	var inner_rect: Rect2 = Rect2(
		Vector2(safe_radius, 0.0),
		Vector2(rect.size.x - safe_radius * 2.0, rect.size.y)
	)
	if inner_rect.has_point(local_point):
		return true

	var vertical_rect: Rect2 = Rect2(
		Vector2(0.0, safe_radius),
		Vector2(rect.size.x, rect.size.y - safe_radius * 2.0)
	)
	if vertical_rect.has_point(local_point):
		return true

	var top_left_center: Vector2 = Vector2(safe_radius, safe_radius)
	var top_right_center: Vector2 = Vector2(rect.size.x - safe_radius, safe_radius)
	var bottom_left_center: Vector2 = Vector2(safe_radius, rect.size.y - safe_radius)
	var bottom_right_center: Vector2 = Vector2(rect.size.x - safe_radius, rect.size.y - safe_radius)
	var radius_squared: float = safe_radius * safe_radius

	return (
		local_point.distance_squared_to(top_left_center) <= radius_squared
		or local_point.distance_squared_to(top_right_center) <= radius_squared
		or local_point.distance_squared_to(bottom_left_center) <= radius_squared
		or local_point.distance_squared_to(bottom_right_center) <= radius_squared
	)


func _can_trigger_back_now() -> bool:
	return Time.get_ticks_msec() >= _next_allowed_back_time_msec


func _apply_back_cooldown(result: String) -> void:
	var cooldown_seconds: float = maxf(回退冷却秒数, 0.0)
	if result == "popup":
		cooldown_seconds = maxf(cooldown_seconds, 弹窗关闭保护秒数)
	_next_allowed_back_time_msec = Time.get_ticks_msec() + int(roundi(cooldown_seconds * 1000.0))


func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if root.name == target_name:
		return root

	for child: Node in root.get_children():
		var found: Node = _find_descendant_by_name(child, target_name)
		if found != null:
			return found
	return null
