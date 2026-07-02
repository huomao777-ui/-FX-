extends Control

@export_group("Connection")
@export var line_end_inset: float = 0.0
@export var line_surface_gap: float = 8.0
@export var collapse_to_dot_length: float = 18.0
@export var hide_dot_length: float = 4.0

@export_group("Core Light")
@export var filament_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var core_color: Color = Color(0.95, 0.995, 1.0, 0.98)
@export var warm_core_color: Color = Color(0.86, 0.98, 1.0, 0.96)
@export var inner_glow_color: Color = Color(0.45, 0.88, 1.0, 0.38)
@export var sheath_color: Color = Color(0.30, 0.78, 1.0, 0.18)
@export var outer_glow_color: Color = Color(0.20, 0.66, 1.0, 0.11)
@export var haze_color: Color = Color(0.40, 0.80, 1.0, 0.018)
@export var far_haze_color: Color = Color(0.56, 0.88, 1.0, 0.008)
@export var ultra_haze_color: Color = Color(0.70, 0.94, 1.0, 0.0035)
@export var filament_width: float = 0.95
@export var core_width: float = 1.8
@export var warm_core_width: float = 3.8
@export var inner_glow_width: float = 11.0
@export var sheath_width: float = 18.0
@export var outer_glow_width: float = 28.0
@export var haze_width: float = 52.0
@export var far_haze_width: float = 82.0
@export var ultra_haze_width: float = 116.0
@export var feather_layers: int = 18
@export var beam_segments: int = 28
@export var spindle_bulge: float = 0.24
@export var tip_width_factor: float = 0.055
@export var tip_alpha_factor: float = 0.07
@export var tip_length_ratio: float = 0.20
@export var short_beam_soft_start: float = 120.0
@export var short_beam_soft_end: float = 320.0
@export var short_beam_bulge_factor: float = 0.35
@export var short_beam_haze_factor: float = 0.58

@export_group("Inner Threads")
@export var thread_color: Color = Color(0.97, 1.0, 1.0, 0.9)
@export var thread_secondary_color: Color = Color(0.70, 0.96, 1.0, 0.52)
@export var thread_width: float = 0.8
@export var thread_offset: float = 3.6
@export var thread_wave_amplitude: float = 1.8
@export var thread_wave_frequency: float = 2.1
@export var thread_speed: float = 1.18
@export var thread_pitch_pixels: float = 120.0
@export var thread_min_cycles: float = 2.1
@export var thread_max_cycles: float = 7.5

@export_group("Collapsed Dot")
@export var collapsed_dot_color: Color = Color(0.93, 0.99, 1.0, 1.0)
@export var collapsed_dot_glow_color: Color = Color(0.35, 0.82, 1.0, 0.48)
@export var collapsed_dot_radius: float = 5.5

@export_group("Endpoints")
@export var endpoint_core_color: Color = Color(0.98, 1.0, 1.0, 0.96)
@export var endpoint_glow_color: Color = Color(0.44, 0.86, 1.0, 0.24)
@export var endpoint_haze_color: Color = Color(0.68, 0.94, 1.0, 0.035)
@export var endpoint_core_radius: float = 1.15
@export var endpoint_glow_radius: float = 3.8
@export var endpoint_haze_radius: float = 7.2
@export var endpoint_flare_length: float = 22.0
@export var endpoint_flare_width: float = 4.6

var left_avatar: Control = null
var right_avatar: Control = null
var line_start: Vector2 = Vector2.ZERO
var line_end: Vector2 = Vector2.ZERO
var line_visible: bool = false
var collapsed_to_dot: bool = false
var time_passed: float = 0.0
var current_line_length: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	time_passed += delta
	sync_to_parent_rect()
	cache_avatars()
	update_line_geometry()


func _draw() -> void:
	if not line_visible:
		return

	if collapsed_to_dot:
		draw_collapsed_dot()
		return

	draw_core_beam(line_start, line_end)


func draw_core_beam(start_point: Vector2, end_point: Vector2) -> void:
	draw_feathered_beam(start_point, end_point)
	draw_tapered_beam_layer(start_point, end_point, sheath_width, sheath_color, beam_segments)
	draw_tapered_beam_layer(start_point, end_point, inner_glow_width, inner_glow_color, beam_segments)
	draw_tapered_beam_layer(start_point, end_point, warm_core_width, warm_core_color, beam_segments)
	draw_tapered_beam_layer(start_point, end_point, core_width, core_color, beam_segments)
	draw_tapered_beam_layer(start_point, end_point, filament_width, filament_color, beam_segments)
	draw_inner_threads(start_point, end_point)
	draw_soft_caps(start_point, end_point)


func draw_feathered_beam(start_point: Vector2, end_point: Vector2) -> void:
	var haze_scale: float = get_short_beam_haze_scale()
	draw_tapered_beam_layer(start_point, end_point, ultra_haze_width * haze_scale, ultra_haze_color, beam_segments)
	draw_tapered_beam_layer(start_point, end_point, far_haze_width * haze_scale, far_haze_color, beam_segments)
	draw_tapered_beam_layer(start_point, end_point, haze_width * haze_scale, haze_color, beam_segments)

	var layer_count: int = maxi(feather_layers, 1)
	for index: int in range(layer_count):
		var t: float = float(index) / maxf(float(layer_count - 1), 1.0)
		var width_value: float = lerpf(haze_width * haze_scale, outer_glow_width * haze_scale, pow(t, 0.66))
		var alpha_value: float = lerpf(haze_color.a, outer_glow_color.a, pow(t, 1.65))
		var layer_color: Color = haze_color.lerp(outer_glow_color, t)
		layer_color.a = alpha_value
		draw_tapered_beam_layer(start_point, end_point, width_value, layer_color, beam_segments)


func draw_tapered_beam_layer(start_point: Vector2, end_point: Vector2, max_width: float, color: Color, segment_count: int) -> void:
	var delta: Vector2 = end_point - start_point
	var length_value: float = delta.length()
	if length_value <= 0.001:
		return

	var normal: Vector2 = Vector2(-delta.y, delta.x) / length_value
	var safe_segments: int = maxi(segment_count, 1)
	for index: int in range(safe_segments):
		var t0: float = float(index) / float(safe_segments)
		var t1: float = float(index + 1) / float(safe_segments)
		var center0: Vector2 = start_point.lerp(end_point, t0)
		var center1: Vector2 = start_point.lerp(end_point, t1)
		var width0: float = get_spindle_width(t0, max_width)
		var width1: float = get_spindle_width(t1, max_width)
		var alpha_value: float = color.a * get_spindle_alpha((t0 + t1) * 0.5)
		var layer_color: Color = Color(color.r, color.g, color.b, alpha_value)
		var points: PackedVector2Array = PackedVector2Array([
			center0 + normal * width0 * 0.5,
			center1 + normal * width1 * 0.5,
			center1 - normal * width1 * 0.5,
			center0 - normal * width0 * 0.5
		])
		var colors: PackedColorArray = PackedColorArray([layer_color, layer_color, layer_color, layer_color])
		draw_polygon(points, colors)


func get_spindle_width(t: float, max_width: float) -> float:
	var tip_distance: float = minf(t, 1.0 - t)
	var tip_profile: float = smoothstep(0.0, maxf(tip_length_ratio, 0.001), tip_distance)
	var center_weight: float = pow(maxf(sin(t * PI), 0.0), 1.2)
	var effective_bulge: float = spindle_bulge * get_short_beam_bulge_scale()
	var bulged_width: float = lerpf(1.0, 1.0 + effective_bulge, center_weight)
	return max_width * lerpf(tip_width_factor, bulged_width, tip_profile)


func get_spindle_alpha(t: float) -> float:
	var tip_distance: float = minf(t, 1.0 - t)
	var tip_profile: float = smoothstep(0.0, maxf(tip_length_ratio, 0.001), tip_distance)
	var center_weight: float = pow(maxf(sin(t * PI), 0.0), 0.7)
	return lerpf(tip_alpha_factor, 1.0, tip_profile * center_weight)


func get_short_beam_ratio() -> float:
	if current_line_length <= short_beam_soft_start:
		return 0.0
	if current_line_length >= short_beam_soft_end:
		return 1.0
	return clampf(
		(current_line_length - short_beam_soft_start) / maxf(short_beam_soft_end - short_beam_soft_start, 0.001),
		0.0,
		1.0
	)


func get_short_beam_bulge_scale() -> float:
	return lerpf(short_beam_bulge_factor, 1.0, get_short_beam_ratio())


func get_short_beam_haze_scale() -> float:
	return lerpf(short_beam_haze_factor, 1.0, get_short_beam_ratio())


func draw_inner_threads(start_point: Vector2, end_point: Vector2) -> void:
	var delta: Vector2 = end_point - start_point
	var length_value: float = delta.length()
	if length_value <= 0.001:
		return

	var direction: Vector2 = delta / length_value
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var cycle_count: float = get_thread_cycle_count(length_value)
	draw_single_thread(start_point, end_point, normal, 0.0, thread_color, 1.0, 0.0, cycle_count)
	draw_single_thread(start_point, end_point, normal, thread_offset, thread_secondary_color, 0.82, 0.65, cycle_count)
	draw_single_thread(start_point, end_point, normal, -thread_offset, thread_secondary_color, 0.82, 1.25, cycle_count)


func get_thread_cycle_count(length_value: float) -> float:
	var inferred_cycles: float = length_value / maxf(thread_pitch_pixels, 1.0)
	return clampf(inferred_cycles, thread_min_cycles, thread_max_cycles)


func draw_single_thread(start_point: Vector2, end_point: Vector2, normal: Vector2, base_offset: float, color: Color, amplitude_scale: float, phase_offset: float, cycle_count: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var point_count: int = 28
	for index: int in range(point_count):
		var t: float = float(index) / float(point_count - 1)
		var center_weight: float = pow(maxf(sin(t * PI), 0.0), 0.88)
		var wave_phase: float = t * PI * 2.0 * thread_wave_frequency * cycle_count
		var wave: float = sin(wave_phase + time_passed * thread_speed + phase_offset) * thread_wave_amplitude * amplitude_scale
		var point: Vector2 = start_point.lerp(end_point, t) + normal * ((base_offset + wave) * center_weight)
		points.append(point)
	draw_polyline(points, color, thread_width, true)


func draw_soft_caps(start_point: Vector2, end_point: Vector2) -> void:
	var haze_scale: float = get_short_beam_haze_scale()
	draw_endpoint_detail(start_point, end_point, haze_scale)
	draw_endpoint_detail(end_point, start_point, haze_scale)


func draw_endpoint_detail(point: Vector2, toward_point: Vector2, haze_scale: float) -> void:
	var flare_end: Vector2 = point.lerp(toward_point, minf(endpoint_flare_length / maxf(current_line_length, 0.001), 0.22))
	draw_tapered_beam_layer(point, flare_end, endpoint_flare_width * haze_scale, Color(endpoint_glow_color.r, endpoint_glow_color.g, endpoint_glow_color.b, endpoint_glow_color.a * 0.9), 8)
	draw_circle(point, endpoint_haze_radius * haze_scale, endpoint_haze_color)
	draw_circle(point, endpoint_glow_radius, endpoint_glow_color)
	draw_circle(point, endpoint_core_radius + 0.6, warm_core_color)
	draw_circle(point, endpoint_core_radius, endpoint_core_color)


func draw_collapsed_dot() -> void:
	draw_circle(line_start, haze_width * 0.3, Color(haze_color.r, haze_color.g, haze_color.b, haze_color.a * 0.8))
	draw_circle(line_start, collapsed_dot_radius + 9.0, outer_glow_color)
	draw_circle(line_start, collapsed_dot_radius + 4.0, collapsed_dot_glow_color)
	draw_circle(line_start, collapsed_dot_radius, collapsed_dot_color)


func cache_avatars() -> void:
	left_avatar = null
	right_avatar = null

	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var avatars: Array[Control] = []
	for child: Node in parent_node.get_children():
		if child == self:
			continue
		if child is Control and looks_like_avatar_node(child as Control):
			avatars.append(child as Control)

	if avatars.size() > 0:
		left_avatar = avatars[0]
	if avatars.size() > 1:
		right_avatar = avatars[1]


func sync_to_parent_rect() -> void:
	var parent_control: Control = get_parent() as Control
	if parent_control == null:
		return
	size = parent_control.size


func update_line_geometry() -> void:
	if left_avatar == null or right_avatar == null:
		hide_line()
		return

	var left_center: Vector2 = get_avatar_center(left_avatar)
	var right_center: Vector2 = get_avatar_center(right_avatar)
	var center_delta: Vector2 = right_center - left_center
	var center_distance: float = center_delta.length()
	if center_distance <= 0.001:
		hide_line()
		return

	var direction: Vector2 = center_delta / center_distance
	var left_radius: float = get_avatar_radius(left_avatar)
	var right_radius: float = get_avatar_radius(right_avatar)

	var start_offset: float = maxf(left_radius + line_surface_gap - line_end_inset, 0.0)
	var end_offset: float = maxf(right_radius + line_surface_gap - line_end_inset, 0.0)
	var start_point: Vector2 = left_center + direction * start_offset
	var end_point: Vector2 = right_center - direction * end_offset
	var visible_length: float = start_point.distance_to(end_point)

	if visible_length <= hide_dot_length:
		hide_line()
		return

	if visible_length <= collapse_to_dot_length:
		line_start = (start_point + end_point) * 0.5
		line_end = line_start
		current_line_length = visible_length
		line_visible = true
		collapsed_to_dot = true
		queue_redraw()
		return

	line_start = start_point
	line_end = end_point
	current_line_length = visible_length
	line_visible = true
	collapsed_to_dot = false
	queue_redraw()


func hide_line() -> void:
	current_line_length = 0.0
	line_visible = false
	collapsed_to_dot = false
	queue_redraw()


func get_avatar_center(avatar: Control) -> Vector2:
	if avatar == null:
		return Vector2.ZERO

	var hidden_hint: Panel = find_hidden_hint_panel(avatar)
	if hidden_hint != null:
		return avatar.position + hidden_hint.position + hidden_hint.size * 0.5

	var ring_sprite: Sprite2D = find_ring_sprite(avatar)
	if ring_sprite != null:
		return avatar.position + get_local_position_from_avatar(avatar, ring_sprite)

	return avatar.position + avatar.size * 0.5


func get_avatar_radius(avatar: Control) -> float:
	if avatar == null:
		return 54.0

	var hidden_hint: Panel = find_hidden_hint_panel(avatar)
	if hidden_hint != null:
		return maxf(hidden_hint.size.x, hidden_hint.size.y) * 0.5

	var ring_sprite: Sprite2D = find_ring_sprite(avatar)
	if ring_sprite != null and ring_sprite.texture != null:
		var relative_scale: Vector2 = get_relative_scale_from_avatar(avatar, ring_sprite)
		var texture_size: Vector2 = ring_sprite.texture.get_size()
		return maxf(texture_size.x * absf(relative_scale.x), texture_size.y * absf(relative_scale.y)) * 0.5

	return 54.0


func looks_like_avatar_node(candidate: Control) -> bool:
	return find_inner_panel(candidate) != null and (find_ring_sprite(candidate) != null or find_hidden_hint_panel(candidate) != null)


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
