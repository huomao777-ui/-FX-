extends Control

const CONTENT_ROOT_NAME: StringName = &"__content_root"
const MASK_OVERLAY_NAME: StringName = &"__rounded_mask_overlay"
const CONTENT_ROOT_PATH: NodePath = ^"__content_root"
const MASK_OVERLAY_PATH: NodePath = ^"__rounded_mask_overlay"

@export_group("初始布局")
## 左侧头像框的初始世界坐标。
@export var left_avatar_start: Vector2 = Vector2(120.0, 360.0)
## 右侧头像框的初始世界坐标。
@export var right_avatar_start: Vector2 = Vector2(385.0, 448.0)

@export_group("缩放")
## 最小缩放值。
@export var min_zoom: float = 0.52
## 最大缩放值。
@export var max_zoom: float = 2.4
## 每次滚轮缩放的步进。
@export var zoom_step: float = 0.08

@export_group("活动范围")
## 前端显示的可活动范围，相对当前显示区域的倍数。
@export var activity_range_multiplier: float = 2.0
## 计算最小缩放时预留的边距。
@export var zoom_limit_padding: float = 18.0

@export_group("运动")
## 头像框1号的质量，越大越沉。
@export var left_mass: float = 1.65
## 头像框2号的质量，越大越沉。
@export var right_mass: float = 1.9
## 摩擦力，越大减速越快。
@export var friction_strength: float = 980.0
## 鼠标速度转换为甩出速度的系数。
@export var throw_speed_factor: float = 2.45
## 最小甩出速度。
@export var min_throw_speed: float = 680.0
## 最大甩出速度。
@export var max_throw_speed: float = 1820.0
## 触发最小甩出速度所需的最小鼠标速度。
@export var throw_min_activation_speed: float = 18.0
## 短距离快速滑动时的爆发阈值。
@export var flick_speed_threshold: float = 260.0
## 爆发加成强度。
@export var flick_boost_factor: float = 0.52
## 爆发加成的非线性指数。
@export var flick_boost_exponent: float = 1.18
## 松手时最多保留多久以内的鼠标甩动速度。
@export var throw_velocity_memory_time: float = 0.12
## 鼠标速度低于该值后，不再继续累计甩出速度。
@export var throw_stop_threshold: float = 12.0
## 镜头跟随时给头像框预留的安全边距。
@export var follow_safe_margin: float = 26.0
## 拖拽时镜头沿拖拽方向提前看的距离。
@export var follow_lead_distance: float = 58.0
## 镜头每秒最大跟随速度。
@export var follow_max_speed: float = 112.0
## 松手后镜头回正速度。
@export var camera_return_speed: float = 5.2

@export_group("碰撞")
## 找不到外框提示节点时使用的默认碰撞半径。
@export var default_collision_radius: float = 54.0
## 两个头像框分离时额外补一点距离，避免视觉重叠。
@export var overlap_padding: float = 1.0
## 靠近边缘时开始增加阻力的范围。
@export var edge_resistance_range: float = 42.0
## 边缘阻力强度。
@export var edge_resistance_strength: float = 0.72
## 碰撞后保留的速度比例。
@export var collision_velocity_keep: float = 0.34
## 头像框相撞时传给对方的冲量比例。
@export var collision_impulse_transfer: float = 0.88
## 拖拽撞击时额外放大的冲量比例。
@export var drag_collision_impulse_boost: float = 1.18
## 触发明显碰撞反馈所需的最小碰撞速度。
@export var collision_min_impulse_speed: float = 24.0

@export_group("圆角遮罩")
## 圆角外侧的遮罩颜色。
@export var rounded_mask_color: Color = Color(0.31764707, 0.31764707, 0.31764707, 1.0)
## 额外裁掉四角直角边的半径。
@export var rounded_mask_extra_corner_cut: float = 10.0
@export var clip_left_padding: float = 0.0
@export var clip_top_padding: float = 0.0
@export var clip_right_padding: float = 0.0
@export var clip_bottom_padding: float = 0.0

@export_group("连接线")
## 连接线端头向球体内部回收的距离。
@export var line_end_inset: float = 0.0
## 连接线整体额外缩短一点，方便微调端头贴合。
@export var line_extra_shrink: float = 0.0
## 两球距离很近时，中段允许保留的最小长度。
@export var line_min_middle_length: float = 0.0
## 找不到连接线素材时，是否自动退回为代码示意线。
@export var line_use_debug_fallback: bool = true
## 示意线颜色。
@export var debug_line_color: Color = Color(0.63, 0.87, 1.0, 0.9)
## 示意线宽度。
@export var debug_line_width: float = 5.0

@export_group("信息卡")
## 信息卡相对星球右上侧的屏幕间距。
@export var info_card_screen_gap: Vector2 = Vector2(22.0, 30.0)
## 信息卡距离屏幕边缘的安全边距。
@export var info_card_safe_margin: float = 18.0
## 打开信息卡时切换到的镜头缩放值。
@export var info_card_open_zoom: float = 1.2
## 以信息卡中心为原点时，镜头中心的额外偏移。
@export var info_card_camera_center_offset: Vector2 = Vector2.ZERO

var left_avatar: Control = null
var right_avatar: Control = null
var connection_node: Control = null
var background_panel: Panel = null
var content_root: Control = null
var rounded_mask_overlay: ColorRect = null
var info_card_node: Control = null
var info_card_card_root: Control = null
var info_card_background: TextureRect = null
var info_card_base_scale: Vector2 = Vector2.ONE
var info_card_base_size: Vector2 = Vector2(640.0, 420.0)
var info_card_owner_avatar: Control = null

var line_left: Sprite2D = null
var line_mid: Sprite2D = null
var line_right: Sprite2D = null
var line_left_base_scale: Vector2 = Vector2.ONE
var line_mid_base_scale: Vector2 = Vector2.ONE
var line_right_base_scale: Vector2 = Vector2.ONE
var line_left_base_pos: Vector2 = Vector2.ZERO
var line_mid_base_pos: Vector2 = Vector2.ZERO
var line_right_base_pos: Vector2 = Vector2.ZERO
var debug_line_start: Vector2 = Vector2.ZERO
var debug_line_end: Vector2 = Vector2.ZERO
var debug_line_visible: bool = false

var dragged_avatar: Control = null
var focused_avatar: Control = null
var drag_center_offset: Vector2 = Vector2.ZERO
var previous_drag_position: Vector2 = Vector2.ZERO
var recent_mouse_world_velocity: Vector2 = Vector2.ZERO
var recent_mouse_velocity_age: float = 999.0
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
	cache_info_card_node()
	prepare_avatar_input_passthrough()
	apply_avatar_masks()
	cache_background_shape()
	ensure_rounded_mask_overlay()
	cache_line_parts()
	initialize_world_state()
	hide_info_card()

	set_process(true)
	pivot_offset = size * 0.5
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func _process(delta: float) -> void:
	update_throw_velocity_memory(delta)
	update_inertia(delta)
	update_camera_follow(delta)
	clamp_all_avatars()
	resolve_overlap()
	apply_content_transform()
	update_info_card_transform()
	update_connection_visual()


func _draw() -> void:
	return


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
			if button_event.double_click:
				if is_info_card_visible():
					if not is_point_over_info_card(button_event.position):
						close_info_card_and_focus_owner()
						accept_event()
						return
				else:
					if try_open_info_card(button_event.position):
						accept_event()
						return
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
	if is_info_card_visible():
		dragged_avatar = null
		dragging_canvas = true
		last_mouse_global = global_pos
		return

	dragged_avatar = pick_avatar(local_pos)
	recent_mouse_world_velocity = Vector2.ZERO
	recent_mouse_velocity_age = 999.0

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
		var release_velocity: Vector2 = Vector2.ZERO
		if recent_mouse_velocity_age <= throw_velocity_memory_time:
			release_velocity = recent_mouse_world_velocity
		avatar_velocities[dragged_avatar.name] = build_throw_velocity(dragged_avatar, release_velocity)
		focused_avatar = dragged_avatar
	dragged_avatar = null
	dragging_canvas = false
	recent_mouse_world_velocity = Vector2.ZERO
	recent_mouse_velocity_age = 999.0


func update_avatar_drag(local_pos: Vector2, mouse_world_velocity: Vector2) -> void:
	if dragged_avatar == null:
		return

	if mouse_world_velocity.length() >= throw_stop_threshold:
		recent_mouse_world_velocity = mouse_world_velocity
		recent_mouse_velocity_age = 0.0
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
	var target_pan: Vector2 = base_pan_offset + delta_local + follow_pan_offset
	if is_info_card_visible():
		base_pan_offset = target_pan - follow_pan_offset
	else:
		base_pan_offset = clamp_total_pan(target_pan, get_zoom_value()) - follow_pan_offset


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


func cache_info_card_node() -> void:
	info_card_node = find_info_card_node()
	info_card_card_root = find_card_root_node(info_card_node)
	info_card_background = find_card_background_node(info_card_node)
	if info_card_node != null:
		info_card_base_scale = info_card_node.scale
		set_control_tree_mouse_filter(info_card_node, Control.MOUSE_FILTER_IGNORE)
	if info_card_card_root != null:
		info_card_base_size = get_card_root_base_size(info_card_card_root)


func try_open_info_card(local_pos: Vector2) -> bool:
	var clicked_avatar: Control = pick_avatar(local_pos)
	if clicked_avatar == null:
		return false

	if is_main_avatar(clicked_avatar):
		return true

	show_info_card()
	info_card_owner_avatar = clicked_avatar
	place_info_card_near_avatar(clicked_avatar)
	focused_avatar = null
	dragged_avatar = null
	dragging_canvas = false
	recent_mouse_world_velocity = Vector2.ZERO
	recent_mouse_velocity_age = 999.0
	snap_camera_to_info_card()
	return true


func is_main_avatar(avatar: Control) -> bool:
	return avatar != null and avatar == left_avatar


func show_info_card() -> void:
	if info_card_node == null:
		cache_info_card_node()
	if info_card_node == null:
		return
	info_card_node.visible = true
	info_card_node.scale = info_card_base_scale


func hide_info_card() -> void:
	if info_card_node == null:
		cache_info_card_node()
	if info_card_node == null:
		return
	info_card_node.visible = false
	focused_avatar = null
	info_card_owner_avatar = null


func close_info_card_and_focus_owner() -> void:
	var owner_avatar: Control = info_card_owner_avatar
	hide_info_card()
	if owner_avatar == null or not is_instance_valid(owner_avatar):
		return
	focused_avatar = owner_avatar
	base_pan_offset = clamp_total_pan(get_pan_to_center_world_point(get_avatar_world_center(owner_avatar)), get_zoom_value())
	follow_pan_offset = Vector2.ZERO
	apply_content_transform()


func is_info_card_visible() -> bool:
	return info_card_node != null and info_card_node.visible


func update_info_card_transform() -> void:
	if not is_info_card_visible():
		return
	info_card_node.scale = info_card_base_scale


func place_info_card_near_avatar(target_avatar: Control) -> void:
	if info_card_node == null or target_avatar == null:
		return
	var avatar_world_center: Vector2 = get_avatar_world_center(target_avatar)
	var radius_world: float = get_avatar_collision_radius(target_avatar)
	var world_top_left: Vector2 = compute_info_card_world_top_left(
		avatar_world_center,
		radius_world,
		get_info_card_world_size()
	)
	info_card_node.scale = info_card_base_scale
	info_card_node.position = world_top_left


func snap_camera_to_info_card() -> void:
	if not is_info_card_visible():
		return
	var target_zoom: float = clampf(info_card_open_zoom, get_dynamic_min_zoom(), max_zoom)
	set_zoom_value(target_zoom)
	var card_world_rect: Rect2 = get_info_card_focus_world_rect()
	var card_world_center: Vector2 = card_world_rect.position + card_world_rect.size * 0.5
	var focus_screen_center: Vector2 = get_view_focus_center_local() + info_card_camera_center_offset
	var target_total_pan: Vector2 = focus_screen_center - card_world_center * target_zoom
	base_pan_offset = target_total_pan
	follow_pan_offset = Vector2.ZERO
	apply_content_transform()


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
	update_connection_visual()


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
	var mask_corner_radius: float = corner_radius + maxf(rounded_mask_extra_corner_cut, 0.0)
	shader_material.set_shader_parameter("cover_color", rounded_mask_color)
	shader_material.set_shader_parameter("corner_radius", mask_corner_radius)
	shader_material.set_shader_parameter("rect_size", size)


func cache_line_parts() -> void:
	if connection_node != null:
		# 让连接线整体处于圆角遮罩下方，避免四角发光溢出。
		connection_node.z_as_relative = true
		connection_node.z_index = -10
	return


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
	velocity = get_avatar_velocity(avatar)
	velocity = velocity.move_toward(Vector2.ZERO, friction_strength * delta)
	avatar_velocities[avatar.name] = velocity


func update_throw_velocity_memory(delta: float) -> void:
	recent_mouse_velocity_age = minf(recent_mouse_velocity_age + delta, 999.0)
	if dragged_avatar != null and recent_mouse_velocity_age > throw_velocity_memory_time:
		recent_mouse_world_velocity = Vector2.ZERO


func update_camera_follow(delta: float) -> void:
	if is_info_card_visible():
		focused_avatar = null
		follow_pan_offset = follow_pan_offset.lerp(Vector2.ZERO, clampf(delta * camera_return_speed, 0.0, 1.0))
		return

	if focused_avatar == null or not is_instance_valid(focused_avatar):
		focused_avatar = null
		follow_pan_offset = follow_pan_offset.lerp(Vector2.ZERO, clampf(delta * camera_return_speed, 0.0, 1.0))
		return

	var avatar_world_center: Vector2 = get_avatar_world_center(focused_avatar)
	var zoom_value: float = get_zoom_value()
	var current_total_pan: Vector2 = get_total_pan()
	var current_screen_center: Vector2 = avatar_world_center * zoom_value + current_total_pan
	var lead_offset: Vector2 = Vector2.ZERO
	if is_info_card_visible():
		follow_pan_offset = follow_pan_offset.lerp(Vector2.ZERO, clampf(delta * camera_return_speed, 0.0, 1.0))
		return
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
	var impact_velocity: Vector2 = recent_mouse_world_velocity

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
	apply_drag_collision_push_velocity(dragged_avatar, pushed_avatar, normal, pushed_previous_position, impact_velocity)
	apply_collision_impulse(dragged_avatar, pushed_avatar, normal, impact_velocity, drag_collision_impulse_boost)


func resolve_overlap() -> void:
	if left_avatar == null or right_avatar == null:
		return

	var overlap_data: Dictionary = get_overlap_data()
	if not bool(overlap_data.get("overlapping", false)):
		return

	var normal: Vector2 = overlap_data.get("normal", Vector2.RIGHT)
	var overlap: float = float(overlap_data.get("overlap", 0.0)) + overlap_padding
	var left_velocity: Vector2 = get_avatar_velocity(left_avatar)
	var right_velocity: Vector2 = get_avatar_velocity(right_avatar)
	var relative_velocity: Vector2 = left_velocity - right_velocity

	if dragged_avatar == left_avatar:
		right_avatar.position += normal * overlap
		clamp_avatar_to_activity(right_avatar)
		apply_collision_impulse(left_avatar, right_avatar, normal, relative_velocity, 1.0)
		return
	if dragged_avatar == right_avatar:
		left_avatar.position -= normal * overlap
		clamp_avatar_to_activity(left_avatar)
		apply_collision_impulse(right_avatar, left_avatar, -normal, -relative_velocity, 1.0)
		return

	var half_push: Vector2 = normal * (overlap * 0.5)
	left_avatar.position -= half_push
	right_avatar.position += half_push
	clamp_avatar_to_activity(left_avatar)
	clamp_avatar_to_activity(right_avatar)
	apply_mutual_collision_impulse(left_avatar, right_avatar, normal, left_velocity, right_velocity)


func clamp_all_avatars() -> void:
	clamp_avatar_to_activity(left_avatar)
	clamp_avatar_to_activity(right_avatar)


func apply_drag_collision_push_velocity(source_avatar: Control, target_avatar: Control, collision_normal: Vector2, target_previous_position: Vector2, source_velocity: Vector2) -> void:
	if source_avatar == null or target_avatar == null:
		return

	var safe_normal: Vector2 = collision_normal.normalized()
	if safe_normal.length() <= 0.001:
		return

	var pushed_delta: Vector2 = target_avatar.position - target_previous_position
	var pushed_distance_along_normal: float = maxf(pushed_delta.dot(safe_normal), 0.0)
	var source_speed_along_normal: float = maxf(source_velocity.dot(safe_normal), 0.0)
	var base_push_speed: float = maxf(source_speed_along_normal * drag_collision_impulse_boost, pushed_distance_along_normal * 20.0)
	if base_push_speed <= collision_min_impulse_speed:
		return

	var source_mass: float = maxf(get_avatar_mass(source_avatar), 0.001)
	var target_mass: float = maxf(get_avatar_mass(target_avatar), 0.001)
	var mass_ratio: float = source_mass / (source_mass + target_mass)
	var push_velocity: Vector2 = safe_normal * base_push_speed * collision_impulse_transfer * mass_ratio
	var target_velocity: Vector2 = get_avatar_velocity(target_avatar)
	avatar_velocities[target_avatar.name] = target_velocity + push_velocity


func apply_collision_impulse(source_avatar: Control, target_avatar: Control, collision_normal: Vector2, source_velocity: Vector2, boost: float) -> void:
	if source_avatar == null or target_avatar == null:
		return

	var safe_normal: Vector2 = collision_normal.normalized()
	if safe_normal.length() <= 0.001:
		return

	var source_speed_along_normal: float = source_velocity.dot(safe_normal)
	if source_speed_along_normal <= collision_min_impulse_speed:
		avatar_velocities[target_avatar.name] = get_avatar_velocity(target_avatar) * collision_velocity_keep
		return

	var source_mass: float = maxf(get_avatar_mass(source_avatar), 0.001)
	var target_mass: float = maxf(get_avatar_mass(target_avatar), 0.001)
	var mass_ratio: float = source_mass / (source_mass + target_mass)
	var impulse_speed: float = source_speed_along_normal * collision_impulse_transfer * boost
	var target_velocity: Vector2 = get_avatar_velocity(target_avatar)
	target_velocity += safe_normal * impulse_speed * mass_ratio
	avatar_velocities[target_avatar.name] = target_velocity

	var source_current_velocity: Vector2 = get_avatar_velocity(source_avatar)
	var source_normal_velocity: Vector2 = safe_normal * source_current_velocity.dot(safe_normal)
	var source_tangent_velocity: Vector2 = source_current_velocity - source_normal_velocity
	source_normal_velocity *= maxf(1.0 - collision_velocity_keep, 0.0)
	avatar_velocities[source_avatar.name] = source_tangent_velocity + source_normal_velocity


func apply_mutual_collision_impulse(left: Control, right: Control, collision_normal: Vector2, left_velocity: Vector2, right_velocity: Vector2) -> void:
	if left == null or right == null:
		return

	var safe_normal: Vector2 = collision_normal.normalized()
	if safe_normal.length() <= 0.001:
		return

	var left_speed: float = left_velocity.dot(safe_normal)
	var right_speed: float = right_velocity.dot(safe_normal)
	var closing_speed: float = left_speed - right_speed
	if closing_speed <= collision_min_impulse_speed:
		avatar_velocities[left.name] = left_velocity * collision_velocity_keep
		avatar_velocities[right.name] = right_velocity * collision_velocity_keep
		return

	var left_mass: float = maxf(get_avatar_mass(left), 0.001)
	var right_mass: float = maxf(get_avatar_mass(right), 0.001)
	var impulse_speed: float = closing_speed * collision_impulse_transfer
	var left_mass_ratio: float = right_mass / (left_mass + right_mass)
	var right_mass_ratio: float = left_mass / (left_mass + right_mass)
	var left_tangent: Vector2 = left_velocity - safe_normal * left_speed
	var right_tangent: Vector2 = right_velocity - safe_normal * right_speed
	var left_new_normal_speed: float = maxf(left_speed - impulse_speed * left_mass_ratio, 0.0)
	var right_new_normal_speed: float = right_speed + impulse_speed * right_mass_ratio
	avatar_velocities[left.name] = left_tangent + safe_normal * left_new_normal_speed
	avatar_velocities[right.name] = right_tangent + safe_normal * right_new_normal_speed


func clamp_avatar_to_activity(avatar: Control) -> void:
	if avatar == null:
		return

	var radius: float = get_avatar_collision_radius(avatar)
	var center: Vector2 = get_avatar_world_center(avatar)
	var hard_center: Vector2 = clamp_point_to_activity_rect(center, radius)
	var hard_correction: Vector2 = hard_center - center
	if hard_correction.length() > 0.001:
		avatar.position += hard_correction
		absorb_avatar_velocity_against_edge(avatar, hard_correction.normalized(), 1.0)
		return

	var soft_radius: float = maxf(radius - edge_resistance_range, 0.0)
	var soft_center: Vector2 = clamp_point_to_activity_rect(center, soft_radius)
	var soft_delta: Vector2 = soft_center - center
	if soft_delta.length() > 0.001:
		var resistance_ratio: float = clampf(soft_delta.length() / maxf(edge_resistance_range, 0.001), 0.0, 1.0)
		absorb_avatar_velocity_against_edge(avatar, soft_delta.normalized(), resistance_ratio)


func absorb_avatar_velocity_against_edge(avatar: Control, inward_normal: Vector2, strength_ratio: float) -> void:
	if avatar == null:
		return

	var velocity: Vector2 = get_avatar_velocity(avatar)
	if velocity.length() <= 0.001:
		return

	var safe_normal: Vector2 = inward_normal.normalized()
	if safe_normal.length() <= 0.001:
		return

	var inward_component: float = velocity.dot(safe_normal)
	if inward_component < 0.0:
		velocity -= safe_normal * inward_component

	var tangential_velocity: Vector2 = velocity - safe_normal * velocity.dot(safe_normal)
	var tangential_keep: float = clampf(1.0 - edge_resistance_strength * strength_ratio, 0.0, 1.0)
	velocity = safe_normal * maxf(velocity.dot(safe_normal), 0.0) + tangential_velocity * tangential_keep
	avatar_velocities[avatar.name] = velocity


func update_connection_visual() -> void:
	return


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


func get_avatar_world_rect(avatar: Control) -> Rect2:
	var radius: float = get_avatar_collision_radius(avatar)
	var center: Vector2 = get_avatar_world_center(avatar)
	return Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)


func build_throw_velocity(avatar: Control, mouse_world_velocity: Vector2) -> Vector2:
	var motion_length: float = mouse_world_velocity.length()
	if motion_length <= 1.0:
		return Vector2.ZERO

	var launch_speed: float = motion_length * throw_speed_factor
	if motion_length > flick_speed_threshold:
		var flick_ratio: float = (motion_length - flick_speed_threshold) / maxf(flick_speed_threshold, 1.0)
		var flick_boost: float = pow(maxf(flick_ratio, 0.0), flick_boost_exponent) * flick_speed_threshold * flick_boost_factor
		launch_speed += flick_boost
	if motion_length > throw_min_activation_speed:
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
	var total_pan: Vector2 = get_total_pan()
	if is_info_card_visible():
		base_pan_offset = base_pan_offset
	else:
		total_pan = clamp_total_pan(total_pan, zoom_value)
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


func world_to_screen_point(world_pos: Vector2) -> Vector2:
	return world_pos * get_zoom_value() + get_total_pan()


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


func get_sprite_texture_width(sprite: Sprite2D) -> float:
	if sprite == null or sprite.texture == null:
		return 0.0
	return sprite.texture.get_size().x


func get_sprite_display_width(sprite: Sprite2D, base_scale: Vector2) -> float:
	if sprite == null or sprite.texture == null:
		return 0.0
	return sprite.texture.get_size().x * absf(base_scale.x)


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


func find_info_card_node() -> Control:
	var root_node: Node = content_root if content_root != null else self
	if root_node == null:
		return null

	for child: Node in root_node.get_children():
		if child is Control and String(child.name) == "人物信息卡":
			return child as Control
	for child: Node in root_node.get_children():
		if child is Control and has_card_root_descendant(child):
			return child as Control
	return null


func has_card_root_descendant(root: Node) -> bool:
	for child: Node in root.get_children():
		if String(child.name) == "CardRoot":
			return true
		if has_card_root_descendant(child):
			return true
	return false


func find_card_root_node(root: Node) -> Control:
	if root == null:
		return null
	for child: Node in root.get_children():
		if child is Control and String(child.name) == "CardRoot":
			return child as Control
		var nested_result: Control = find_card_root_node(child)
		if nested_result != null:
			return nested_result
	return null


func find_card_background_node(root: Node) -> TextureRect:
	if root == null:
		return null
	for child: Node in root.get_children():
		if child is TextureRect and String(child.name) == "CardBackground":
			return child as TextureRect
		var nested_result: TextureRect = find_card_background_node(child)
		if nested_result != null:
			return nested_result
	return null


func get_card_root_base_size(card_root: Control) -> Vector2:
	if card_root == null:
		return Vector2(640.0, 420.0)
	if card_root.custom_minimum_size.length() > 0.001:
		return card_root.custom_minimum_size
	if card_root.size.length() > 0.001:
		return card_root.size
	return Vector2(640.0, 420.0)


func get_info_card_scaled_size() -> Vector2:
	var zoom_value: float = get_zoom_value()
	return Vector2(
		info_card_base_size.x * absf(info_card_base_scale.x) * zoom_value,
		info_card_base_size.y * absf(info_card_base_scale.y) * zoom_value
	)


func get_info_card_local_rect() -> Rect2:
	if info_card_node == null:
		return Rect2(Vector2.ZERO, get_info_card_scaled_size())
	var background_rect: Rect2 = get_info_card_background_local_rect()
	if background_rect.size.length() > 0.001:
		return background_rect
	var screen_top_left: Vector2 = world_to_screen_point(info_card_node.position)
	return Rect2(screen_top_left, get_info_card_scaled_size())


func get_info_card_world_size() -> Vector2:
	return Vector2(
		info_card_base_size.x * absf(info_card_base_scale.x),
		info_card_base_size.y * absf(info_card_base_scale.y)
	)


func get_info_card_world_rect() -> Rect2:
	if info_card_node == null:
		return Rect2(Vector2.ZERO, get_info_card_world_size())
	return Rect2(info_card_node.position, get_info_card_world_size())


func get_info_card_focus_world_rect() -> Rect2:
	if info_card_node == null:
		return Rect2(Vector2.ZERO, get_info_card_world_size())
	if info_card_background == null:
		return get_info_card_world_rect()

	var local_offset: Vector2 = get_control_local_offset(info_card_node, info_card_background)
	var local_scale: Vector2 = get_control_relative_scale(info_card_node, info_card_background)
	var top_left: Vector2 = info_card_node.position + local_offset * info_card_base_scale
	var rect_size: Vector2 = Vector2(
		info_card_background.size.x * absf(local_scale.x) * absf(info_card_base_scale.x),
		info_card_background.size.y * absf(local_scale.y) * absf(info_card_base_scale.y)
	)
	return Rect2(top_left, rect_size)


func get_pan_to_frame_rect(target_rect: Rect2) -> Vector2:
	var zoom_value: float = get_zoom_value()
	var visible_world_size: Vector2 = size / maxf(zoom_value, 0.001)
	var padded_rect: Rect2 = target_rect.grow_individual(
		info_card_screen_gap.x / zoom_value,
		info_card_screen_gap.y / zoom_value,
		info_card_screen_gap.x / zoom_value,
		info_card_screen_gap.y / zoom_value
	)
	var target_world_top_left: Vector2 = padded_rect.position + padded_rect.size * 0.5 - visible_world_size * 0.5
	return -target_world_top_left * zoom_value


func get_pan_to_center_world_point(world_point: Vector2) -> Vector2:
	return size * 0.5 - world_point * get_zoom_value()


func get_view_focus_center_local() -> Vector2:
	return size * 0.5


func is_point_over_info_card(local_pos: Vector2) -> bool:
	if not is_info_card_visible():
		return false
	var card_rect: Rect2 = get_info_card_local_rect()
	var inset_x: float = minf(card_rect.size.x * 0.1, 36.0)
	var inset_y: float = minf(card_rect.size.y * 0.1, 36.0)
	card_rect = card_rect.grow_individual(-inset_x, -inset_y, -inset_x, -inset_y)
	return card_rect.has_point(local_pos)


func get_info_card_background_local_rect() -> Rect2:
	if info_card_node == null or info_card_background == null:
		return Rect2()
	var local_offset: Vector2 = get_control_local_offset(info_card_node, info_card_background)
	var local_scale: Vector2 = get_control_relative_scale(info_card_node, info_card_background)
	var world_top_left: Vector2 = info_card_node.position + local_offset * info_card_base_scale
	var screen_top_left: Vector2 = world_to_screen_point(world_top_left)
	var screen_size: Vector2 = Vector2(
		info_card_background.size.x * absf(local_scale.x) * absf(info_card_base_scale.x) * get_zoom_value(),
		info_card_background.size.y * absf(local_scale.y) * absf(info_card_base_scale.y) * get_zoom_value()
	)
	return Rect2(screen_top_left, screen_size)


func compute_info_card_world_top_left(avatar_world_center: Vector2, radius_world: float, card_size_world: Vector2) -> Vector2:
	var zoom_value: float = maxf(get_zoom_value(), 0.001)
	var gap_world: Vector2 = info_card_screen_gap / zoom_value
	return avatar_world_center + Vector2(
		radius_world + gap_world.x,
		-card_size_world.y - radius_world - gap_world.y
	)


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


func get_control_local_offset(root: Control, target: Control) -> Vector2:
	var result: Vector2 = Vector2.ZERO
	var current: Node = target
	while current != null and current != root:
		if current is Control:
			result += (current as Control).position
		current = current.get_parent()
	return result


func get_control_relative_scale(root: Control, target: Control) -> Vector2:
	var result: Vector2 = Vector2.ONE
	var current: Node = target
	while current != null and current != root:
		if current is Control:
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
	update_connection_visual()
