extends Panel

const FAR_FOG_NAME: StringName = &"far_fog_layer"
const NEAR_FOG_NAME: StringName = &"near_fog_layer"

@export_group("Nodes")
@export var star_background_path: NodePath = ^"星空背景/星空背景"
@export var star_foreground_path: NodePath = ^"前景星点/前景星点"

@export_group("Parallax")
@export var enable_drag_parallax: bool = false
@export var star_background_drag_factor: float = 0.18
@export var far_fog_drag_factor: float = 0.34
@export var near_fog_drag_factor: float = 0.5
@export var star_foreground_drag_factor: float = 0.82
@export var max_drag_offset: float = 42.0
@export var spring_back_speed: float = 4.8

@export_group("Drift")
@export var star_background_drift: Vector2 = Vector2(4.0, 3.0)
@export var far_fog_drift: Vector2 = Vector2(10.0, 8.0)
@export var near_fog_drift: Vector2 = Vector2(15.0, 11.0)
@export var star_foreground_drift: Vector2 = Vector2(7.0, 6.0)
@export var drift_speed: float = 0.42

var star_background: CanvasItem = null
var star_foreground: CanvasItem = null
var far_fog: ColorRect = null
var near_fog: ColorRect = null

var star_background_base_pos: Vector2 = Vector2.ZERO
var star_foreground_base_pos: Vector2 = Vector2.ZERO
var far_fog_base_pos: Vector2 = Vector2.ZERO
var near_fog_base_pos: Vector2 = Vector2.ZERO

var drag_offset: Vector2 = Vector2.ZERO
var target_drag_offset: Vector2 = Vector2.ZERO
var last_local_mouse: Vector2 = Vector2.ZERO
var dragging: bool = false
var time_passed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS if enable_drag_parallax else Control.MOUSE_FILTER_IGNORE
	cache_nodes()
	ensure_fog_layers()
	cache_base_positions()
	apply_parallax()
	set_process(true)
	if not resized.is_connected(_on_panel_resized):
		resized.connect(_on_panel_resized)


func _process(delta: float) -> void:
	time_passed += delta
	target_drag_offset = target_drag_offset.limit_length(max_drag_offset)
	drag_offset = drag_offset.lerp(target_drag_offset, clampf(delta * spring_back_speed, 0.0, 1.0))
	if not dragging and target_drag_offset.length() > 0.01:
		target_drag_offset = target_drag_offset.lerp(Vector2.ZERO, clampf(delta * 2.8, 0.0, 1.0))
	apply_parallax()


func _gui_input(event: InputEvent) -> void:
	if not enable_drag_parallax:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			dragging = true
			last_local_mouse = mouse_event.position
			accept_event()
		else:
			dragging = false
			accept_event()
	elif event is InputEventMouseMotion:
		if not dragging:
			return
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		var delta_local: Vector2 = motion_event.position - last_local_mouse
		last_local_mouse = motion_event.position
		target_drag_offset += delta_local
		target_drag_offset = target_drag_offset.limit_length(max_drag_offset)
		accept_event()


func cache_nodes() -> void:
	star_background = get_node_or_null(star_background_path) as CanvasItem
	star_foreground = get_node_or_null(star_foreground_path) as CanvasItem


func ensure_fog_layers() -> void:
	far_fog = get_node_or_null(FAR_FOG_NAME) as ColorRect
	if far_fog == null:
		far_fog = ColorRect.new()
		far_fog.name = FAR_FOG_NAME
		far_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		far_fog.material = build_fog_material(
			Color(0.52, 0.63, 0.74, 0.07),
			Color(0.65, 0.76, 0.86, 0.0),
			2.1,
			0.022
		)
		add_child(far_fog)
		move_child(far_fog, 1)

	near_fog = get_node_or_null(NEAR_FOG_NAME) as ColorRect
	if near_fog == null:
		near_fog = ColorRect.new()
		near_fog.name = NEAR_FOG_NAME
		near_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		near_fog.material = build_fog_material(
			Color(0.76, 0.84, 0.92, 0.055),
			Color(0.85, 0.92, 1.0, 0.0),
			3.2,
			0.035
		)
		add_child(near_fog)
		if star_foreground != null:
			move_child(near_fog, max(get_children().find(star_foreground), 0))

	layout_fog_layer(far_fog, 1.24)
	layout_fog_layer(near_fog, 1.34)


func cache_base_positions() -> void:
	if star_background != null:
		star_background_base_pos = star_background.position
	if star_foreground != null:
		star_foreground_base_pos = star_foreground.position
	if far_fog != null:
		far_fog_base_pos = far_fog.position
	if near_fog != null:
		near_fog_base_pos = near_fog.position


func _on_panel_resized() -> void:
	if far_fog != null:
		layout_fog_layer(far_fog, 1.24)
	if near_fog != null:
		layout_fog_layer(near_fog, 1.34)
	cache_base_positions()


func layout_fog_layer(fog: ColorRect, overscan_scale: float) -> void:
	var layer_size: Vector2 = size * overscan_scale
	fog.size = layer_size
	fog.position = -((layer_size - size) * 0.5)


func apply_parallax() -> void:
	if star_background != null:
		star_background.position = star_background_base_pos + compose_layer_offset(star_background_drag_factor, star_background_drift, 0.2)
	if far_fog != null:
		far_fog.position = far_fog_base_pos + compose_layer_offset(far_fog_drag_factor, far_fog_drift, 0.65)
	if near_fog != null:
		near_fog.position = near_fog_base_pos + compose_layer_offset(near_fog_drag_factor, near_fog_drift, 1.15)
	if star_foreground != null:
		star_foreground.position = star_foreground_base_pos + compose_layer_offset(star_foreground_drag_factor, star_foreground_drift, 1.7)


func compose_layer_offset(drag_factor: float, drift_amplitude: Vector2, phase: float) -> Vector2:
	var drag_part: Vector2 = drag_offset * drag_factor
	var drift_part: Vector2 = Vector2(
		sin(time_passed * drift_speed + phase) * drift_amplitude.x,
		cos(time_passed * drift_speed * 0.83 + phase * 1.3) * drift_amplitude.y
	)
	return drag_part + drift_part


func build_fog_material(primary_color: Color, secondary_color: Color, noise_scale: float, edge_softness: float) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 primary_color : source_color = vec4(0.52, 0.63, 0.74, 0.07);
uniform vec4 secondary_color : source_color = vec4(0.65, 0.76, 0.86, 0.0);
uniform float noise_scale = 2.0;
uniform float edge_softness = 0.03;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * amplitude;
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - vec2(0.5)) * noise_scale;
	float base_noise = fbm(p + vec2(TIME * 0.015, TIME * 0.01));
	float secondary_noise = fbm(p * 1.5 - vec2(TIME * 0.02, TIME * 0.013));
	float cloud = smoothstep(0.48, 0.82, base_noise * 0.72 + secondary_noise * 0.38);
	float edge_x = smoothstep(0.0, edge_softness, uv.x) * (1.0 - smoothstep(1.0 - edge_softness, 1.0, uv.x));
	float edge_y = smoothstep(0.0, edge_softness, uv.y) * (1.0 - smoothstep(1.0 - edge_softness, 1.0, uv.y));
	float edge_mask = edge_x * edge_y;
	vec4 color = mix(secondary_color, primary_color, cloud);
	color.a *= cloud * edge_mask;
	COLOR = color;
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("primary_color", primary_color)
	material.set_shader_parameter("secondary_color", secondary_color)
	material.set_shader_parameter("noise_scale", noise_scale)
	material.set_shader_parameter("edge_softness", edge_softness)
	return material
