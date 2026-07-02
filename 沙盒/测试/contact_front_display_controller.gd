extends Control

const CONTENT_ROOT_NAME: StringName = &"__content_root"
const MASK_OVERLAY_NAME: StringName = &"__rounded_mask_overlay"
const CONTENT_ROOT_PATH: NodePath = ^"__content_root"
const MASK_OVERLAY_PATH: NodePath = ^"__rounded_mask_overlay"

@export_group("Initial Layout")
@export var left_avatar_start: Vector2 = Vector2(120.0, 360.0)
@export var right_avatar_start: Vector2 = Vector2(385.0, 448.0)

@export_group("Zoom")
@export var min_zoom: float = 0.52
@export var max_zoom: float = 1.85
@export var zoom_step: float = 0.08

@export_group("World")
@export var activity_range_multiplier: float = 2.0
@export var zoom_limit_padding: float = 18.0

@export_group("Motion")
@export var left_mass: float = 1.75
@export var right_mass: float = 2.0
@export var friction_strength: float = 1250.0
@export var throw_speed_factor: float = 1.85
@export var min_throw_speed: float = 420.0
@export var max_throw_speed: float = 1320.0
@export var follow_safe_margin: float = 26.0
@export var follow_lead_distance: float = 58.0
@export var follow_max_speed: float = 112.0
@export var camera_return_speed: float = 5.2

@export_group("Collision")
@export var default_collision_radius: float = 54.0
@export var overlap_padding: float = 1.0
@export var edge_resistance_range: float = 42.0
@export var edge_resistance_strength: float = 0.72
@export var collision_velocity_keep: float = 0.18

@export_group("Mask")
@export var rounded_mask_color: Color = Color(0.31764707, 0.31764707, 0.31764707, 1.0)
@export var clip_left_padding: float = 0.0
@export var clip_top_padding: float = 0.0
@export var clip_right_padding: float = 0.0
@export var clip_bottom_padding: float = 0.0

var left_avatar: Control = null
var right_avatar: Control = null
var connection_node: Control = null
var background_panel: Panel = null
var content_root: Control = null
var rounded_mask_overlay: ColorRect = null

var dragged_avatar: Control = null
var focused_avatar: Control = null
var drag_center_offset: Vector2 = Vector2.ZERO
var previous_drag_position: Vector2 = Vector2.ZERO
var recent_mouse_world_velocity: Vector2 = Vector2.ZERO
var dragging_canvas: bool = false
var last_mouse_global: Vector2 = Vector2.ZERO

var avatar_velocities: Dictionary = {}
var base_pan_offset: Vector2 = Vector2.ZERO
var follow_pan_offset: Vector2 = Vector2.ZERO
var corner_radius: float = 70.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	cache_nodes()
	sync_display_rect_to_background()
	ensure_content_root()
	cache_nodes()
	ensure_exactly_two_avatars()
	cache_nodes()
	prepare_avatar_input_passthrough()
	apply_avatar_masks()
	cache_background_shape()
	ensure_rounded_mask_overlay()
	initialize_world_state()

	set_process(true)
	pivot_offset = size * 0.5
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func _process(delta: float) -> void:
	update_inertia(delta)
	update_camera_follow(delta)
	clamp_all_avatars()
	resolve_overlap()
	apply_content_transform()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_WHEEL_UP and button_event.pressed:
			adjust_zoom(1.0 + zoom_step)
			accept_event()
			return
		if button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and button_event.pressed:
			adjust_zoom(1.0 - zoom_step)
			accept_event()
			return
		if button_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if button_event.pressed:
			begin_pointer_action(button_event.position, button_event.global_position)
			accept_event()
			return
		end_pointer_action()
		accept_event()
		return

	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if dragged_avatar != null:
			update_avatar_drag(motion_event.position, motion_event.velocity / maxf(get_zoom_value(), 0.001))
			accept_event()
			return
		if dragging_canvas:
			update_canvas_drag(motion_event.global_position)
			accept_event()


func begin_pointer_action(local_pos: Vector2, global_pos: Vector2) -> void:
	dragged_avatar = pick_avatar(local_pos)
	recent_mouse_world_velocity = Vector2.ZERO

	if dragged_avatar != null:
		focused_avatar = dragged_avatar
		var world_pos: Vector2 = local_to_world(local_pos)
		drag_center_offset = dragged_avatar.position - world_pos
		previous_drag_position = dragged_avatar.position
		avatar_velocities[dragged_avatar.name] = Vector2.ZERO
		update_avatar_drag(local_pos, Vector2.ZERO)
		return

	focused_avatar = null
	dragging_canvas = true
	last_mouse_global = global_pos


func end_pointer_action() -> void:
	if dragged_avatar != null:
		avatar_velocities[dragged_avatar.name] = build_throw_velocity(dragged_avatar, recent_mouse_world_velocity)
		focused_avatar = dragged_avatar
	dragged_avatar = null
	dragging_canvas = false


func update_avatar_drag(local_pos: Vector2, mouse_world_velocity: Vector2) -> void:
	if dragged_avatar == null:
		return

	recent_mouse_world_velocity = mouse_world_velocity
	var target_world_pos: Vector2 = local_to_world(local_pos) + drag_center_offset
	previous_drag_position = dragged_avatar.position
	dragged_avatar.position = target_world_pos
	clamp_avatar_to_activity(dragged_avatar)
	resolve_drag_collision()
	avatar_velocities[dragged_avatar.name] = Vector2.ZERO


func update_canvas_drag(global_pos: Vector2) -> void:
	var viewport_scale: float = maxf(get_viewport_transform().get_scale().x, 0.001)
	var delta_local: Vector2 = (global_pos - last_mouse_global) / viewport_scale
	last_mouse_global = global_pos
	base_pan_offset = clamp_total_pan(base_pan_offset + delta_local + follow_pan_offset, get_zoom_value()) - follow_pan_offset


func cache_nodes() -> void:
	background_panel = find_background_panel()
	content_root = get_node_or_null(CONTENT_ROOT_PATH) as Control

	var avatars: Array[Control] = find_avatar_nodes()
	left_avatar = null
	right_avatar = null
	if avatars.size() > 0:
		left_avatar = avatars[0]
	if avatars.size() > 1:
		right_avatar = avatars[1]

	connection_node = find_connection_node()


func ensure_content_root() -> void:
	content_root = get_node_or_null(CONTENT_ROOT_PATH) as Control
	if content_root == null:
		content_root = Control.new()
		content_root.name = CONTENT_ROOT_NAME
		content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(content_root)

	var movable_children: Array[Node] = []
	for child: Node in get_children():
		if child == content_root or child.name == MASK_OVERLAY_NAME:
			continue
		movable_children.append(child)

	for child: Node in movable_children:
		remove_child(child)
		content_root.add_child(child)

	content_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	content_root.size = size
	content_root.custom_minimum_size = size
	content_root.pivot_offset = Vector2.ZERO


func ensure_exactly_two_avatars() -> void:
	var avatars: Array[Control] = find_avatar_nodes()
	if avatars.is_empty():
		return

	for index: int in range(avatars.size() - 1, 1, -1):
		var extra_avatar: Control = avatars[index]
		if is_instance_valid(extra_avatar):
			content_root.remove_child(extra_avatar)
			extra_avatar.queue_free()

	if avatars.size() >= 2:
		return

	var duplicated: Node = avatars[0].duplicate()
	if not (duplicated is Control):
		return

	var new_avatar: Control = duplicated as Control
	new_avatar.name = "avatar_2"
	content_root.add_child(new_avatar)
	if connection_node != null:
		content_root.move_child(new_avatar, content_root.get_children().find(connection_node))


func initialize_world_state() -> void:
	var initial_zoom: float = clampf(1.0, get_dynamic_min_zoom(), max_zoom)
	set_zoom_value(initial_zoom)
	base_pan_offset = get_centered_pan(get_zoom_value())
	follow_pan_offset = Vector2.ZERO

	var initial_world_top_left: Vector2 = get_visible_world_top_left(get_centered_pan(1.0), 1.0)
	if left_avatar != null:
		left_avatar.position = initial_world_top_left + left_avatar_start
		avatar_velocities[left_avatar.name] = Vector2.ZERO
	if right_avatar != null:
		right_avatar.position = initial_world_top_left + right_avatar_start
		avatar_velocities[right_avatar.name] = Vector2.ZERO

	clamp_all_avatars()
	resolve_overlap()
	apply_content_transform()


func prepare_avatar_input_passthrough() -> void:
	if left_avatar != null:
		set_control_tree_mouse_filter(left_avatar, Control.MOUSE_FILTER_IGNORE)
	if right_avatar != null:
		set_control_tree_mouse_filter(right_avatar, Control.MOUSE_FILTER_IGNORE)


func apply_avatar_masks() -> void:
	if left_avatar != null:
		apply_single_avatar_mask(left_avatar)
	if right_avatar != null:
		apply_single_avatar_mask(right_avatar)


func apply_single_avatar_mask(avatar: Control) -> void:
	if avatar == null:
		return

	var inner_panel: Panel = find_inner_panel(avatar)
	if inner_panel != null:
		inner_panel.clip_contents = false

	var portrait_sprite: Sprite2D = find_portrait_sprite(avatar)
	if portrait_sprite == null:
		return

	var mask_material: ShaderMaterial = ShaderMaterial.new()
	var mask_shader: Shader = Shader.new()
	mask_shader.code = """
shader_type canvas_item;

uniform float edge_softness = 0.02;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 centered_uv = UV - vec2(0.5);
	float dist = length(centered_uv) * 2.0;
	float alpha = 1.0 - smoothstep(1.0 - edge_softness, 1.0, dist);
	COLOR = vec4(tex.rgb, tex.a * alpha);
}
"""
	mask_material.shader = mask_shader
	portrait_sprite.material = mask_material


func cache_background_shape() -> void:
	corner_radius = 70.0
	if background_panel == null:
		return

	var panel_style: Variant = background_panel.get("theme_override_styles/panel")
	if panel_style is StyleBoxFlat:
		var flat_style: StyleBoxFlat = panel_style as StyleBoxFlat
		corner_radius = float(flat_style.corner_radius_top_left)


func sync_display_rect_to_background() -> void:
	if background_panel == null:
		return

	position = background_panel.position + Vector2(clip_left_padding, clip_top_padding)
	size = background_panel.size - Vector2(clip_left_padding + clip_right_padding, clip_top_padding + clip_bottom_padding)
	custom_minimum_size = size


func ensure_rounded_mask_overlay() -> void:
	rounded_mask_overlay = get_node_or_null(MASK_OVERLAY_PATH) as ColorRect
	if rounded_mask_overlay == null:
		rounded_mask_overlay = ColorRect.new()
		rounded_mask_overlay.name = MASK_OVERLAY_NAME
		rounded_mask_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rounded_mask_overlay)

	var shader_material: ShaderMaterial = rounded_mask_overlay.material as ShaderMaterial
	if shader_material == null:
		shader_material = ShaderMaterial.new()
		var shader: Shader = Shader.new()
		shader.code = """
shader_type canvas_item;

uniform vec4 cover_color : source_color = vec4(0.31764707, 0.31764707, 0.31764707, 1.0);
uniform float corner_radius = 70.0;
uniform vec2 rect_size = vec2(100.0, 100.0);

float rounded_rect_sdf(vec2 p, vec2 b, float r) {
	vec2 q = abs(p - b * 0.5) - (b * 0.5 - vec2(r));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 pixel_pos = UV * rect_size;
	float sdf = rounded_rect_sdf(pixel_pos, rect_size, corner_radius);
	if (sdf <= 0.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		COLOR = cover_color;
	}
}
"""
		shader_material.shader = shader
		rounded_mask_overlay.material = shader_material

	rounded_mask_overlay.position = Vector2.ZERO
	rounded_mask_overlay.size = size
	move_child(rounded_mask_overlay, get_child_count() - 1)
	update_rounded_mask_overlay()


func update_rounded_mask_overlay() -> void:
	if rounded_mask_overlay == null:
		return

	rounded_mask_overlay.position = Vector2.ZERO
	rounded_mask_overlay.size = size
	var shader_material: ShaderMaterial = rounded_mask_overlay.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("cover_color", rounded_mask_color)
	shader_material.set_shader_parameter("corner_radius", corner_radius)
	shader_material.set_shader_parameter("rect_size", size)


func adjust_zoom(multiplier: float) -> void:
	var current_zoom: float = get_zoom_value()
	var target_zoom: float = clampf(current_zoom * multiplier, get_dynamic_min_zoom(), max_zoom)
	if is_equal_approx(target_zoom, current_zoom):
		return

	var current_total_pan: Vector2 = get_total_pan()
	var center_world: Vector2 = (size * 0.5 - current_total_pan) / current_zoom
	set_zoom_value(target_zoom)
	var next_total_pan: Vector2 = size * 0.5 - center_world * target_zoom
	next_total_pan = clamp_total_pan(next_total_pan, target_zoom)
	base_pan_offset = next_total_pan
	follow_pan_offset = Vector2.ZERO
	apply_content_transform()


func update_inertia(delta: float) -> void:
	update_single_avatar_inertia(left_avatar, delta)
	update_single_avatar_inertia(right_avatar, delta)


func update_single_avatar_inertia(avatar: Control, delta: float) -> void:
	if avatar == null or avatar == dragged_avatar:
		return

	var velocity: Vector2 = get_avatar_velocity(avatar)
	if velocity.length() <= 0.01:
		avatar_velocities[avatar.name] = Vector2.ZERO
		return

	avatar.position += velocity * delta
	clamp_avatar_to_activity(avatar)
	velocity = velocity.move_toward(Vector2.ZERO, friction_strength * delta)
	avatar_velocities[avatar.name] = velocity


func update_camera_follow(delta: float) -> void:
	if focused_avatar == null or not is_instance_valid(focused_avatar):
		focused_avatar = null
		follow_pan_offset = follow_pan_offset.lerp(Vector2.ZERO, clampf(delta * camera_return_speed, 0.0, 1.0))
		return

	var avatar_world_center: Vector2 = get_avatar_world_center(focused_avatar)
	var zoom_value: float = get_zoom_value()
	var current_total_pan: Vector2 = get_total_pan()
	var current_screen_center: Vector2 = avatar_world_center * zoom_value + current_total_pan
	var lead_offset: Vector2 = Vector2.ZERO
	if dragged_avatar == focused_avatar and recent_mouse_world_velocity.length() > 0.001:
		lead_offset = recent_mouse_world_velocity.normalized() * follow_lead_distance
	var radius_on_screen: float = get_avatar_collision_radius(focused_avatar) * zoom_value
	var target_screen_center: Vector2 = clamp_point_to_rounded_rect(current_screen_center + lead_offset, radius_on_screen, follow_safe_margin)
	var target_total_pan: Vector2 = target_screen_center - avatar_world_center * zoom_value
	target_total_pan = clamp_total_pan(target_total_pan, zoom_value)
	var target_follow_offset: Vector2 = target_total_pan - base_pan_offset
	var max_step: float = follow_max_speed * delta
	follow_pan_offset = follow_pan_offset.move_toward(target_follow_offset, max_step)


func resolve_drag_collision() -> void:
	if dragged_avatar == null:
		return
	if left_avatar == null or right_avatar == null:
		return

	var pushed_avatar: Control = right_avatar if dragged_avatar == left_avatar else left_avatar
	var overlap_data: Dictionary = get_overlap_data()
	if not bool(overlap_data.get("overlapping", false)):
		return

	var normal: Vector2 = overlap_data.get("normal", Vector2.RIGHT)
	var overlap: float = float(overlap_data.get("overlap", 0.0)) + overlap_padding
	var pushed_previous_position: Vector2 = pushed_avatar.position

	if dragged_avatar == left_avatar:
		pushed_avatar.position += normal * overlap
	else:
		pushed_avatar.position -= normal * overlap

	clamp_avatar_to_activity(pushed_avatar)
	var remaining_overlap: Dictionary = get_overlap_data()
	if bool(remaining_overlap.get("overlapping", false)):
		dragged_avatar.position = previous_drag_position
		pushed_avatar.position = pushed_previous_position
		clamp_avatar_to_activity(dragged_avatar)
		clamp_avatar_to_activity(pushed_avatar)

	avatar_velocities[dragged_avatar.name] = Vector2.ZERO
	avatar_velocities[pushed_avatar.name] = Vector2.ZERO


func resolve_overlap() -> void:
	if left_avatar == null or right_avatar == null:
		return

	var overlap_data: Dictionary = get_overlap_data()
	if not bool(overlap_data.get("overlapping", false)):
		return

	var normal: Vector2 = overlap_data.get("normal", Vector2.RIGHT)
	var overlap: float = float(overlap_data.get("overlap", 0.0)) + overlap_padding

	if dragged_avatar == left_avatar:
		right_avatar.position += normal * overlap
		clamp_avatar_to_activity(right_avatar)
		avatar_velocities[right_avatar.name] = get_avatar_velocity(right_avatar) * collision_velocity_keep
		return
	if dragged_avatar == right_avatar:
		left_avatar.position -= normal * overlap
		clamp_avatar_to_activity(left_avatar)
		avatar_velocities[left_avatar.name] = get_avatar_velocity(left_avatar) * collision_velocity_keep
		return

	var half_push: Vector2 = normal * (overlap * 0.5)
	left_avatar.position -= half_push
	right_avatar.position += half_push
	clamp_avatar_to_activity(left_avatar)
	clamp_avatar_to_activity(right_avatar)
	avatar_velocities[left_avatar.name] = get_avatar_velocity(left_avatar) * collision_velocity_keep
	avatar_velocities[right_avatar.name] = get_avatar_velocity(right_avatar) * collision_velocity_keep


func clamp_all_avatars() -> void:
	clamp_avatar_to_activity(left_avatar)
	clamp_avatar_to_activity(right_avatar)


func clamp_avatar_to_activity(avatar: Control) -> void:
	if avatar == null:
		return

	var radius: float = get_avatar_collision_radius(avatar)
	var center: Vector2 = get_avatar_world_center(avatar)
	var hard_center: Vector2 = clamp_point_to_activity_rect(center, radius)
	var soft_radius: float = maxf(radius - edge_resistance_range, 0.0)
	var soft_center: Vector2 = clamp_point_to_activity_rect(center, soft_radius)
	var corrected_center: Vector2 = hard_center
	if center.distance_to(hard_center) <= 0.001:
		corrected_center = soft_center.lerp(center, 1.0 - clampf(edge_resistance_strength, 0.0, 1.0))
	avatar.position += corrected_center - get_avatar_world_center(avatar)


func pick_avatar(local_pos: Vector2) -> Control:
	var world_pos: Vector2 = local_to_world(local_pos)
	if right_avatar != null and avatar_contains_point(right_avatar, world_pos):
		return right_avatar
	if left_avatar != null and avatar_contains_point(left_avatar, world_pos):
		return left_avatar
	return null


func avatar_contains_point(avatar: Control, world_pos: Vector2) -> bool:
	if avatar == null:
		return false

	var hidden_hint: Panel = find_hidden_hint_panel(avatar)
	if hidden_hint != null:
		var local_in_avatar: Vector2 = world_pos - avatar.position
		var rect: Rect2 = Rect2(hidden_hint.position, hidden_hint.size)
		if not rect.has_point(local_in_avatar):
			return false
		var center: Vector2 = rect.position + rect.size * 0.5
		var half_size: Vector2 = rect.size * 0.5
		if half_size.x <= 0.001 or half_size.y <= 0.001:
			return true
		var normalized: Vector2 = Vector2(
			(local_in_avatar.x - center.x) / half_size.x,
			(local_in_avatar.y - center.y) / half_size.y
		)
		return normalized.length_squared() <= 1.0

	var radius: float = get_avatar_collision_radius(avatar)
	return get_avatar_world_center(avatar).distance_to(world_pos) <= radius


func get_avatar_world_center(avatar: Control) -> Vector2:
	if avatar == null:
		return Vector2.ZERO
	return avatar.position + get_avatar_local_center(avatar)


func get_avatar_local_center(avatar: Control) -> Vector2:
	var hidden_hint: Panel = find_hidden_hint_panel(avatar)
	if hidden_hint != null:
		return hidden_hint.position + hidden_hint.size * 0.5

	var ring_sprite: Sprite2D = find_ring_sprite(avatar)
	if ring_sprite != null:
		return get_local_position_from_avatar(avatar, ring_sprite)

	return avatar.size * 0.5


func get_avatar_collision_radius(avatar: Control) -> float:
	if avatar == null:
		return default_collision_radius

	var hidden_hint: Panel = find_hidden_hint_panel(avatar)
	if hidden_hint != null:
		return maxf(hidden_hint.size.x, hidden_hint.size.y) * 0.5

	var ring_sprite: Sprite2D = find_ring_sprite(avatar)
	if ring_sprite != null and ring_sprite.texture != null:
		var relative_scale: Vector2 = get_relative_scale_from_avatar(avatar, ring_sprite)
		var texture_size: Vector2 = ring_sprite.texture.get_size()
		return maxf(texture_size.x * absf(relative_scale.x), texture_size.y * absf(relative_scale.y)) * 0.5

	return default_collision_radius


func get_overlap_data() -> Dictionary:
	var left_center: Vector2 = get_avatar_world_center(left_avatar)
	var right_center: Vector2 = get_avatar_world_center(right_avatar)
	var delta: Vector2 = right_center - left_center
	var distance_value: float = delta.length()
	var min_distance: float = get_avatar_collision_radius(left_avatar) + get_avatar_collision_radius(right_avatar)
	if distance_value >= min_distance:
		return {
			"overlapping": false,
			"normal": Vector2.RIGHT,
			"overlap": 0.0
		}

	var normal: Vector2 = Vector2.RIGHT
	if distance_value > 0.001:
		normal = delta / distance_value
	return {
		"overlapping": true,
		"normal": normal,
		"overlap": min_distance - distance_value
	}


func build_throw_velocity(avatar: Control, mouse_world_velocity: Vector2) -> Vector2:
	var motion_length: float = mouse_world_velocity.length()
	if motion_length <= 1.0:
		return Vector2.ZERO

	var launch_speed: float = motion_length * throw_speed_factor
	if motion_length > 40.0:
		launch_speed = maxf(launch_speed, min_throw_speed)
	launch_speed = minf(launch_speed, max_throw_speed)

	var mass_factor: float = sqrt(maxf(get_avatar_mass(avatar), 0.001))
	return mouse_world_velocity.normalized() * (launch_speed / mass_factor)


func get_avatar_velocity(avatar: Control) -> Vector2:
	if avatar == null:
		return Vector2.ZERO
	var stored: Variant = avatar_velocities.get(avatar.name, Vector2.ZERO)
	if stored is Vector2:
		return stored as Vector2
	return Vector2.ZERO


func get_avatar_mass(avatar: Control) -> float:
	if avatar == right_avatar:
		return right_mass
	return left_mass


func get_zoom_value() -> float:
	if content_root == null:
		return 1.0
	return maxf(content_root.scale.x, 0.001)


func set_zoom_value(value: float) -> void:
	if content_root == null:
		return
	content_root.scale = Vector2(value, value)


func get_total_pan() -> Vector2:
	return base_pan_offset + follow_pan_offset


func apply_content_transform() -> void:
	if content_root == null:
		return

	var zoom_value: float = get_zoom_value()
	var total_pan: Vector2 = clamp_total_pan(get_total_pan(), zoom_value)
	base_pan_offset = clamp_total_pan(base_pan_offset, zoom_value)
	follow_pan_offset = total_pan - base_pan_offset
	content_root.position = total_pan
	content_root.size = get_activity_world_size()
	content_root.custom_minimum_size = content_root.size


func get_visible_world_top_left(total_pan: Vector2, zoom_value: float) -> Vector2:
	return (-total_pan) / maxf(zoom_value, 0.001)


func get_activity_world_size() -> Vector2:
	return size * maxf(activity_range_multiplier, 1.0)


func get_activity_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, get_activity_world_size())


func get_centered_pan(zoom_value: float) -> Vector2:
	var activity_center: Vector2 = get_activity_world_size() * 0.5
	return size * 0.5 - activity_center * zoom_value


func get_dynamic_min_zoom() -> float:
	var activity_size: Vector2 = get_activity_world_size() - Vector2.ONE * zoom_limit_padding * 2.0
	activity_size.x = maxf(activity_size.x, 1.0)
	activity_size.y = maxf(activity_size.y, 1.0)
	var width_limit: float = size.x / activity_size.x
	var height_limit: float = size.y / activity_size.y
	return maxf(min_zoom, maxf(width_limit, height_limit))


func clamp_total_pan(total_pan: Vector2, zoom_value: float) -> Vector2:
	var activity_size: Vector2 = get_activity_world_size()
	var min_pan: Vector2 = size - activity_size * zoom_value
	var max_pan: Vector2 = Vector2.ZERO
	return Vector2(
		clampf(total_pan.x, min_pan.x, max_pan.x),
		clampf(total_pan.y, min_pan.y, max_pan.y)
	)


func clamp_point_to_activity_rect(point: Vector2, radius: float) -> Vector2:
	var activity_rect: Rect2 = get_activity_world_rect()
	var result: Vector2 = point
	result.x = clampf(result.x, activity_rect.position.x + radius, activity_rect.end.x - radius)
	result.y = clampf(result.y, activity_rect.position.y + radius, activity_rect.end.y - radius)
	return result


func local_to_world(local_pos: Vector2) -> Vector2:
	var zoom_value: float = get_zoom_value()
	return (local_pos - get_total_pan()) / zoom_value


func clamp_point_to_rounded_rect(point: Vector2, radius: float, extra_padding: float) -> Vector2:
	var inset_rect: Rect2 = Rect2(Vector2.ZERO, size).grow(-(radius + extra_padding))
	var result: Vector2 = point
	result.x = clampf(result.x, inset_rect.position.x, inset_rect.end.x)
	result.y = clampf(result.y, inset_rect.position.y, inset_rect.end.y)

	var effective_radius: float = maxf(corner_radius - radius - extra_padding, 0.0)
	if effective_radius <= 0.0:
		return result

	var top_left_center: Vector2 = inset_rect.position + Vector2(effective_radius, effective_radius)
	var top_right_center: Vector2 = Vector2(inset_rect.end.x - effective_radius, inset_rect.position.y + effective_radius)
	var bottom_left_center: Vector2 = Vector2(inset_rect.position.x + effective_radius, inset_rect.end.y - effective_radius)
	var bottom_right_center: Vector2 = inset_rect.end - Vector2(effective_radius, effective_radius)

	if result.x < top_left_center.x and result.y < top_left_center.y:
		return clamp_to_corner_circle(result, top_left_center, effective_radius)
	if result.x > top_right_center.x and result.y < top_right_center.y:
		return clamp_to_corner_circle(result, top_right_center, effective_radius)
	if result.x < bottom_left_center.x and result.y > bottom_left_center.y:
		return clamp_to_corner_circle(result, bottom_left_center, effective_radius)
	if result.x > bottom_right_center.x and result.y > bottom_right_center.y:
		return clamp_to_corner_circle(result, bottom_right_center, effective_radius)
	return result


func clamp_to_corner_circle(point: Vector2, center: Vector2, radius: float) -> Vector2:
	var delta: Vector2 = point - center
	var distance_value: float = delta.length()
	if distance_value <= radius:
		return point
	if distance_value <= 0.001:
		return center + Vector2.RIGHT * radius
	return center + delta.normalized() * radius


func find_avatar_nodes() -> Array[Control]:
	var result: Array[Control] = []
	var root_node: Node = content_root if content_root != null else self
	for child: Node in root_node.get_children():
		if child is Control and looks_like_avatar_node(child as Control):
			result.append(child as Control)
	return result


func find_connection_node() -> Control:
	var root_node: Node = content_root if content_root != null else self
	for child: Node in root_node.get_children():
		if child is Control and looks_like_connection_node(child as Control):
			return child as Control
	return null


func find_background_panel() -> Panel:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return null
	for child: Node in parent_node.get_children():
		if child is Panel:
			return child as Panel
	return null


func looks_like_avatar_node(candidate: Control) -> bool:
	return find_inner_panel(candidate) != null and (find_ring_sprite(candidate) != null or find_hidden_hint_panel(candidate) != null)


func looks_like_connection_node(candidate: Control) -> bool:
	var sprite_count: int = 0
	for child: Node in candidate.get_children():
		if child is Panel:
			return false
		if child is Sprite2D:
			sprite_count += 1
	return sprite_count >= 2


func find_inner_panel(root: Node) -> Panel:
	for child: Node in root.get_children():
		if child is Panel and child.visible:
			return child as Panel
	return null


func find_hidden_hint_panel(root: Node) -> Panel:
	for child: Node in root.get_children():
		if child is Panel and not child.visible:
			return child as Panel
	return null


func find_portrait_sprite(root: Node) -> Sprite2D:
	var inner_panel: Panel = find_inner_panel(root)
	if inner_panel != null:
		var inner_sprite: Sprite2D = find_first_sprite(inner_panel)
		if inner_sprite != null:
			return inner_sprite
	return null


func find_first_sprite(root: Node) -> Sprite2D:
	for child: Node in root.get_children():
		if child is Sprite2D:
			return child as Sprite2D
		var nested_result: Sprite2D = find_first_sprite(child)
		if nested_result != null:
			return nested_result
	return null


func find_ring_sprite(root: Node) -> Sprite2D:
	for child: Node in root.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	for child: Node in root.get_children():
		if child is Panel:
			continue
		var nested_result: Sprite2D = find_ring_sprite(child)
		if nested_result != null:
			return nested_result
	return null


func get_local_position_from_avatar(avatar: Control, target: Node2D) -> Vector2:
	var result: Vector2 = Vector2.ZERO
	var current: Node = target
	while current != null and current != avatar:
		if current is Node2D:
			result += (current as Node2D).position
		elif current is Control:
			result += (current as Control).position
		current = current.get_parent()
	return result


func get_relative_scale_from_avatar(avatar: Control, target: Node2D) -> Vector2:
	var result: Vector2 = Vector2.ONE
	var current: Node = target
	while current != null and current != avatar:
		if current is Node2D:
			result *= (current as Node2D).scale
		elif current is Control:
			result *= (current as Control).scale
		current = current.get_parent()
	return result


func set_control_tree_mouse_filter(root: Node, filter_mode: Control.MouseFilter) -> void:
	if root is Control:
		var control: Control = root as Control
		control.mouse_filter = filter_mode
	for child: Node in root.get_children():
		set_control_tree_mouse_filter(child, filter_mode)


func _on_resized() -> void:
	pivot_offset = size * 0.5
	if content_root != null:
		content_root.size = get_activity_world_size()
		content_root.custom_minimum_size = content_root.size
	cache_background_shape()
	update_rounded_mask_overlay()
	base_pan_offset = clamp_total_pan(base_pan_offset, get_zoom_value())
	follow_pan_offset = Vector2.ZERO
	clamp_all_avatars()
	apply_content_transform()
