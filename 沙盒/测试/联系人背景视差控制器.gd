extends Panel

const FAR_FOG_NAME := "远景雾层"
const NEAR_FOG_NAME := "前景雾层"

@export_group("节点名称")
@export var 星空背景节点路径: NodePath = ^"星空背景/星空背景"
@export var 前景星点节点路径: NodePath = ^"前景星点/前景星点"

@export_group("拖拽视差")
@export var 启用拖拽视差: bool = false
@export var 星空拖拽系数: float = 0.18
@export var 远景雾拖拽系数: float = 0.34
@export var 前景雾拖拽系数: float = 0.5
@export var 前景星点拖拽系数: float = 0.82
@export var 最大偏移像素: float = 42.0
@export var 回弹速度: float = 4.8

@export_group("呼吸漂浮")
@export var 星空漂浮幅度: Vector2 = Vector2(4.0, 3.0)
@export var 远景雾漂浮幅度: Vector2 = Vector2(10.0, 8.0)
@export var 前景雾漂浮幅度: Vector2 = Vector2(15.0, 11.0)
@export var 前景星点漂浮幅度: Vector2 = Vector2(7.0, 6.0)
@export var 漂浮速度: float = 0.42

var _star_bg: CanvasItem = null
var _star_fg: CanvasItem = null
var _far_fog: ColorRect = null
var _near_fog: ColorRect = null

var _star_bg_base_pos: Vector2 = Vector2.ZERO
var _star_fg_base_pos: Vector2 = Vector2.ZERO
var _far_fog_base_pos: Vector2 = Vector2.ZERO
var _near_fog_base_pos: Vector2 = Vector2.ZERO

var _drag_offset: Vector2 = Vector2.ZERO
var _target_drag_offset: Vector2 = Vector2.ZERO
var _last_local_mouse: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _time_passed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS if 启用拖拽视差 else Control.MOUSE_FILTER_IGNORE
	_cache_nodes()
	_ensure_fog_layers()
	_cache_base_positions()
	_apply_parallax()
	set_process(true)
	if not resized.is_connected(_on_panel_resized):
		resized.connect(_on_panel_resized)


func _process(delta: float) -> void:
	_time_passed += delta
	_target_drag_offset = _target_drag_offset.limit_length(最大偏移像素)
	_drag_offset = _drag_offset.lerp(_target_drag_offset, clampf(delta * 回弹速度, 0.0, 1.0))
	if not _dragging and _target_drag_offset.length() > 0.01:
		_target_drag_offset = _target_drag_offset.lerp(Vector2.ZERO, clampf(delta * 2.8, 0.0, 1.0))
	_apply_parallax()


func _gui_input(event: InputEvent) -> void:
	if not 启用拖拽视差:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_dragging = true
			_last_local_mouse = mouse_event.position
			accept_event()
		else:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion:
		if not _dragging:
			return
		var motion_event := event as InputEventMouseMotion
		var delta_local := motion_event.position - _last_local_mouse
		_last_local_mouse = motion_event.position
		_target_drag_offset += delta_local
		_target_drag_offset = _target_drag_offset.limit_length(最大偏移像素)
		accept_event()


func _cache_nodes() -> void:
	_star_bg = get_node_or_null(星空背景节点路径) as CanvasItem
	_star_fg = get_node_or_null(前景星点节点路径) as CanvasItem


func _ensure_fog_layers() -> void:
	_far_fog = get_node_or_null(FAR_FOG_NAME) as ColorRect
	if _far_fog == null:
		_far_fog = ColorRect.new()
		_far_fog.name = FAR_FOG_NAME
		_far_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_far_fog.material = _build_fog_material(
			Color(0.52, 0.63, 0.74, 0.07),
			Color(0.65, 0.76, 0.86, 0.0),
			2.1,
			0.022
		)
		add_child(_far_fog)
		move_child(_far_fog, 1)

	_near_fog = get_node_or_null(NEAR_FOG_NAME) as ColorRect
	if _near_fog == null:
		_near_fog = ColorRect.new()
		_near_fog.name = NEAR_FOG_NAME
		_near_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_near_fog.material = _build_fog_material(
			Color(0.76, 0.84, 0.92, 0.055),
			Color(0.85, 0.92, 1.0, 0.0),
			3.2,
			0.035
		)
		add_child(_near_fog)
		if _star_fg != null:
			move_child(_near_fog, max(get_children().find(_star_fg), 0))

	_layout_fog_layer(_far_fog, 1.24)
	_layout_fog_layer(_near_fog, 1.34)


func _cache_base_positions() -> void:
	if _star_bg != null:
		_star_bg_base_pos = _star_bg.position
	if _star_fg != null:
		_star_fg_base_pos = _star_fg.position
	if _far_fog != null:
		_far_fog_base_pos = _far_fog.position
	if _near_fog != null:
		_near_fog_base_pos = _near_fog.position


func _on_panel_resized() -> void:
	if _far_fog != null:
		_layout_fog_layer(_far_fog, 1.24)
	if _near_fog != null:
		_layout_fog_layer(_near_fog, 1.34)
	_cache_base_positions()


func _layout_fog_layer(fog: ColorRect, overscan_scale: float) -> void:
	var layer_size := size * overscan_scale
	fog.size = layer_size
	fog.position = -((layer_size - size) * 0.5)


func _apply_parallax() -> void:
	if _star_bg != null:
		_star_bg.position = _star_bg_base_pos + _compose_layer_offset(星空拖拽系数, 星空漂浮幅度, 0.2)
	if _far_fog != null:
		_far_fog.position = _far_fog_base_pos + _compose_layer_offset(远景雾拖拽系数, 远景雾漂浮幅度, 0.65)
	if _near_fog != null:
		_near_fog.position = _near_fog_base_pos + _compose_layer_offset(前景雾拖拽系数, 前景雾漂浮幅度, 1.15)
	if _star_fg != null:
		_star_fg.position = _star_fg_base_pos + _compose_layer_offset(前景星点拖拽系数, 前景星点漂浮幅度, 1.7)


func _compose_layer_offset(drag_factor: float, drift_amplitude: Vector2, phase: float) -> Vector2:
	var drag_part := _drag_offset * drag_factor
	var drift_part := Vector2(
		sin(_time_passed * 漂浮速度 + phase) * drift_amplitude.x,
		cos(_time_passed * 漂浮速度 * 0.83 + phase * 1.3) * drift_amplitude.y
	)
	return drag_part + drift_part


func _build_fog_material(primary_color: Color, secondary_color: Color, noise_scale: float, edge_softness: float) -> ShaderMaterial:
	var shader := Shader.new()
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

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("primary_color", primary_color)
	material.set_shader_parameter("secondary_color", secondary_color)
	material.set_shader_parameter("noise_scale", noise_scale)
	material.set_shader_parameter("edge_softness", edge_softness)
	return material
