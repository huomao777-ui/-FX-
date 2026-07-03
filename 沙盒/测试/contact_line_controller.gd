extends Control

const BODY_LAYER_INDEX: int = 0
const FOG_LAYER_INDEX: int = 1
const RING_LAYER_INDEX: int = 2

@export_group("Connection")
@export var line_end_inset: float = 0.0
@export var line_surface_gap: float = 8.0
@export var line_endpoint_extra_length: float = 0.0
@export var collapse_to_dot_length: float = 18.0
@export var hide_dot_length: float = 4.0

@export_group("Body Geometry")
@export var body_height: float = 58.0
@export var fog_height: float = 68.0
@export var ring_height: float = 82.0
@export var endpoint_fade_ratio: float = 0.18

@export_group("Body Light")
@export var filament_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var filament_hot_color: Color = Color(0.98, 1.0, 1.0, 1.0)
@export var core_tint_color: Color = Color(0.97, 1.0, 1.0, 0.99)
@export var core_color: Color = Color(0.93, 0.99, 1.0, 0.98)
@export var inner_glow_color: Color = Color(0.86, 0.98, 1.0, 0.95)
@export var inner_core_color: Color = Color(0.78, 0.97, 1.0, 0.92)
@export var inner_color: Color = Color(0.58, 0.92, 1.0, 0.72)
@export var outer_mid_color: Color = Color(0.50, 0.89, 1.0, 0.64)
@export var mid_color: Color = Color(0.44, 0.86, 1.0, 0.56)
@export var outer_sheath_color: Color = Color(0.34, 0.82, 1.0, 0.42)
@export var sheath_color: Color = Color(0.26, 0.78, 1.0, 0.34)
@export var haze_color: Color = Color(0.30, 0.72, 0.96, 0.18)
@export var mist_color: Color = Color(0.34, 0.82, 1.0, 0.055)
@export var filament_width_ratio: float = 0.028
@export var filament_hot_width_ratio: float = 0.018
@export var core_tint_width_ratio: float = 0.052
@export var core_width_ratio: float = 0.075
@export var inner_glow_width_ratio: float = 0.098
@export var inner_core_width_ratio: float = 0.12
@export var inner_width_ratio: float = 0.19
@export var outer_mid_width_ratio: float = 0.23
@export var mid_width_ratio: float = 0.27
@export var outer_sheath_width_ratio: float = 0.32
@export var sheath_width_ratio: float = 0.36
@export var haze_width_ratio: float = 0.52
@export var mist_width_ratio: float = 0.62
@export var center_brightness: float = 1.42
@export var edge_brightness: float = 0.68
@export var center_focus: float = 0.82
@export var outer_falloff_strength: float = 1.52
@export var core_hot_boost: float = 1.22

@export_group("Endpoints")
@export var endpoint_core_color: Color = Color(0.98, 1.0, 1.0, 0.92)
@export var endpoint_glow_color: Color = Color(0.50, 0.88, 1.0, 0.22)
@export var endpoint_haze_color: Color = Color(0.62, 0.92, 1.0, 0.06)
@export var endpoint_core_radius: float = 1.6
@export var endpoint_glow_radius: float = 5.4
@export var endpoint_haze_radius: float = 10.2
@export var endpoint_flare_length: float = 10.0
@export var endpoint_taper_steps: int = 5
@export var endpoint_bridge_length: float = 16.0
@export var endpoint_bridge_width: float = 6.0
@export var endpoint_outer_color: Color = Color(0.26, 0.70, 0.96, 0.11)
@export var endpoint_mid_color: Color = Color(0.72, 0.95, 1.0, 0.44)
@export var endpoint_core_hot_color: Color = Color(1.0, 1.0, 1.0, 0.98)
@export var endpoint_core_length: float = 9.5
@export var endpoint_mid_length: float = 14.0
@export var endpoint_disc_steps: int = 14
@export var endpoint_haze_spread: float = 1.14
@export var endpoint_mid_spread: float = 1.10
@export var endpoint_core_spread: float = 0.92
@export var endpoint_beam_color: Color = Color(0.56, 0.88, 1.0, 0.22)
@export var endpoint_beam_core_color: Color = Color(0.86, 0.98, 1.0, 0.18)

@export_group("Fog Layer")
@export var fog_inner_color: Color = Color(0.76, 0.94, 1.0, 0.016)
@export var fog_outer_color: Color = Color(0.40, 0.76, 0.96, 0.010)
@export var fog_center_strength: float = 0.80
@export var fog_inner_strength: float = 0.58
@export var fog_outer_strength: float = 0.90
@export var fog_center_brightness: float = 1.04
@export var fog_edge_brightness: float = 0.88
@export var fog_center_focus: float = 0.60

@export_group("Ring Layer")
@export var ring_primary_color: Color = Color(0.94, 0.99, 1.0, 0.78)
@export var ring_secondary_color: Color = Color(0.58, 0.88, 1.0, 0.48)
@export var ring_glow_color: Color = Color(0.42, 0.84, 1.0, 0.28)
@export var ring_hot_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var ring_shadow_color: Color = Color(0.28, 0.66, 0.96, 0.32)
@export var ring_cycle_length: float = 72.0
@export var ring_scroll_speed: float = 16.0
@export var ring_wave_amplitude: float = 0.165
@export var ring_wave_thickness: float = 0.012
@export var ring_glow_thickness: float = 0.026
@export var ring_center_spread: float = 0.0
@export var ring_endpoint_fade_length: float = 48.0
@export var ring_visibility: float = 1.0
@export var ring_fragment_fill: float = 0.36
@export var ring_fragment_min_length: float = 0.28
@export var ring_fragment_max_length: float = 0.64
@export var ring_front_visibility: float = 0.82
@export var ring_fragment_life_speed: float = 0.62
@export var ring_fragment_head_boost: float = 1.18
@export var ring_fragment_tail_softness: float = 0.16
@export var ring_fragment_taper_power: float = 0.54
@export var ring_fragment_core_ratio: float = 0.46
@export var ring_fragment_random_offset: float = 0.42
@export var ring_fragment_brightness: float = 1.18
@export var ring_fragment_spawn_per_cell: float = 2.0
@export var ring_fragment_max_travel: float = 0.42
@export var ring_fragment_min_travel: float = 0.14
@export var ring_fragment_max_width_scale: float = 1.24
@export var ring_fragment_min_width_scale: float = 0.62
@export var ring_fragment_fade_start: float = 0.68
@export var ring_fragment_fade_end: float = 1.0
@export var ring_fragment_shrink_strength: float = 0.46

@export_group("Collapsed Dot")
@export var collapsed_dot_color: Color = Color(0.94, 0.99, 1.0, 1.0)
@export var collapsed_dot_glow_color: Color = Color(0.40, 0.84, 1.0, 0.34)
@export var collapsed_dot_radius: float = 5.0
@export var collapsed_dot_haze_color: Color = Color(0.48, 0.86, 1.0, 0.10)
@export var collapsed_dot_core_color: Color = Color(1.0, 1.0, 1.0, 0.96)
@export var collapsed_dot_tail_length: float = 10.0
@export var collapsed_dot_steps: int = 16

var left_avatar: Control = null
var right_avatar: Control = null
var line_start: Vector2 = Vector2.ZERO
var line_end: Vector2 = Vector2.ZERO
var current_line_length: float = 0.0
var line_visible: bool = false
var collapsed_to_dot: bool = false

var body_layer: ColorRect = null
var fog_layer: ColorRect = null
var ring_layer: ColorRect = null
var ring_front_layer: ColorRect = null
var body_material: ShaderMaterial = null
var fog_material: ShaderMaterial = null
var ring_material: ShaderMaterial = null
var ring_front_material: ShaderMaterial = null
var body_layer_enabled: bool = true
var fog_layer_enabled: bool = true
var ring_layer_enabled: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	pivot_offset = Vector2.ZERO
	cache_layers()
	ensure_ring_front_layer()
	ensure_materials()
	configure_layers()
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	cache_avatars()
	update_line_geometry()
	apply_line_transform()
	apply_visual_state()


func _draw() -> void:
	if not collapsed_to_dot:
		if line_visible:
			draw_endpoint_at(Vector2.ZERO, false)
			draw_endpoint_at(Vector2(current_line_length, 0.0), true)
		return
	draw_collapsed_dot()


func cache_layers() -> void:
	var color_layers: Array[ColorRect] = []
	for child: Node in get_children():
		if child is ColorRect:
			color_layers.append(child as ColorRect)

	if color_layers.size() > BODY_LAYER_INDEX:
		body_layer = color_layers[BODY_LAYER_INDEX]
	if color_layers.size() > FOG_LAYER_INDEX:
		fog_layer = color_layers[FOG_LAYER_INDEX]
	if color_layers.size() > RING_LAYER_INDEX:
		ring_layer = color_layers[RING_LAYER_INDEX]

	body_layer_enabled = body_layer == null or body_layer.visible
	fog_layer_enabled = fog_layer == null or fog_layer.visible
	ring_layer_enabled = true


func ensure_materials() -> void:
	if body_layer != null and body_material == null:
		body_material = ShaderMaterial.new()
		body_material.shader = build_body_shader()
		body_layer.material = body_material

	if fog_layer != null and fog_material == null:
		fog_material = ShaderMaterial.new()
		fog_material.shader = build_fog_shader()
		fog_layer.material = fog_material

	if ring_layer != null and ring_material == null:
		ring_material = ShaderMaterial.new()
		ring_material.shader = build_ring_shader()
		ring_layer.material = ring_material

	if ring_front_layer != null and ring_front_material == null:
		ring_front_material = ShaderMaterial.new()
		ring_front_material.shader = build_ring_shader()
		ring_front_layer.material = ring_front_material


func ensure_ring_front_layer() -> void:
	if ring_layer == null:
		return

	if ring_front_layer == null and has_node(^"__ring_front_layer"):
		ring_front_layer = get_node(^"__ring_front_layer") as ColorRect

	if ring_front_layer != null:
		return

	ring_front_layer = ColorRect.new()
	ring_front_layer.name = "__ring_front_layer"
	ring_front_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_front_layer.color = Color.WHITE
	add_child(ring_front_layer)


func configure_layers() -> void:
	for layer: ColorRect in [body_layer, fog_layer, ring_layer, ring_front_layer]:
		if layer == null:
			continue
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.color = Color.WHITE
		layer.position = Vector2.ZERO

	if ring_layer != null:
		ring_layer.z_index = -1
	if fog_layer != null:
		fog_layer.z_index = 0
	if body_layer != null:
		body_layer.z_index = 1
	if ring_front_layer != null:
		ring_front_layer.z_index = 2

	if ring_layer != null:
		ring_layer.visible = ring_layer_enabled
	if ring_front_layer != null:
		ring_front_layer.visible = ring_layer_enabled


func build_body_shader() -> Shader:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 filament_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 filament_hot_color : source_color = vec4(0.98, 1.0, 1.0, 1.0);
uniform vec4 core_tint_color : source_color = vec4(0.97, 1.0, 1.0, 0.99);
uniform vec4 core_color : source_color = vec4(0.93, 0.99, 1.0, 0.98);
uniform vec4 inner_glow_color : source_color = vec4(0.86, 0.98, 1.0, 0.95);
uniform vec4 inner_core_color : source_color = vec4(0.78, 0.97, 1.0, 0.92);
uniform vec4 inner_color : source_color = vec4(0.58, 0.92, 1.0, 0.72);
uniform vec4 outer_mid_color : source_color = vec4(0.50, 0.89, 1.0, 0.64);
uniform vec4 mid_color : source_color = vec4(0.44, 0.86, 1.0, 0.56);
uniform vec4 outer_sheath_color : source_color = vec4(0.34, 0.82, 1.0, 0.42);
uniform vec4 sheath_color : source_color = vec4(0.26, 0.78, 1.0, 0.34);
uniform vec4 haze_color : source_color = vec4(0.30, 0.72, 0.96, 0.18);
uniform vec4 mist_color : source_color = vec4(0.34, 0.82, 1.0, 0.055);
uniform float filament_width_ratio = 0.028;
uniform float filament_hot_width_ratio = 0.018;
uniform float core_tint_width_ratio = 0.052;
uniform float core_width_ratio = 0.075;
uniform float inner_glow_width_ratio = 0.098;
uniform float inner_core_width_ratio = 0.12;
uniform float inner_width_ratio = 0.19;
uniform float outer_mid_width_ratio = 0.23;
uniform float mid_width_ratio = 0.27;
uniform float outer_sheath_width_ratio = 0.32;
uniform float sheath_width_ratio = 0.36;
uniform float haze_width_ratio = 0.52;
uniform float mist_width_ratio = 0.62;
uniform float endpoint_fade_ratio = 0.18;
uniform float center_brightness = 1.14;
uniform float edge_brightness = 0.88;
uniform float center_focus = 0.62;
uniform float outer_falloff_strength = 1.52;
uniform float core_hot_boost = 1.22;

float band(float dist_value, float width_ratio, float softness) {
	return 1.0 - smoothstep(width_ratio, width_ratio + softness, dist_value);
}

void fragment() {
	vec2 uv = UV;
	float center_dist = abs(uv.y - 0.5) * 2.0;
	float end_fade = smoothstep(0.0, endpoint_fade_ratio, uv.x) * (1.0 - smoothstep(1.0 - endpoint_fade_ratio, 1.0, uv.x));
	float center_profile = pow(max(1.0 - abs(uv.x - 0.5) * 2.0, 0.0), center_focus);
	float longitudinal_gain = mix(edge_brightness, center_brightness, center_profile);
	float radial_falloff = pow(max(1.0 - center_dist, 0.0), outer_falloff_strength);
	float filament_hot = band(center_dist, filament_hot_width_ratio, 0.012) * end_fade;
	float filament = band(center_dist, filament_width_ratio, 0.02) * end_fade;
	float core_tint = band(center_dist, core_tint_width_ratio, 0.028) * end_fade;
	float core = band(center_dist, core_width_ratio, 0.04) * end_fade;
	float inner_glow = band(center_dist, inner_glow_width_ratio, 0.05) * end_fade;
	float inner_core = band(center_dist, inner_core_width_ratio, 0.055) * end_fade;
	float inner = band(center_dist, inner_width_ratio, 0.075) * end_fade;
	float outer_mid = band(center_dist, outer_mid_width_ratio, 0.088) * end_fade;
	float mid = band(center_dist, mid_width_ratio, 0.1) * end_fade;
	float outer_sheath = band(center_dist, outer_sheath_width_ratio, 0.115) * end_fade;
	float sheath = band(center_dist, sheath_width_ratio, 0.13) * end_fade;
	float haze = band(center_dist, haze_width_ratio, 0.19) * end_fade;
	float mist = band(center_dist, mist_width_ratio, 0.18) * end_fade;

	filament_hot *= core_hot_boost;
	filament *= mix(0.98, 1.08, radial_falloff);
	core_tint *= mix(0.97, 1.06, radial_falloff);
	core *= mix(0.92, 1.04, radial_falloff);
	inner_glow *= radial_falloff;
	inner_core *= radial_falloff;
	inner *= radial_falloff;
	outer_mid *= radial_falloff * 0.95;
	mid *= radial_falloff * 0.9;
	outer_sheath *= radial_falloff * 0.8;
	sheath *= radial_falloff * 0.72;
	haze *= radial_falloff * 0.6;
	mist *= radial_falloff * 0.52;

	vec4 color = vec4(0.0);
	color += mist_color * mist;
	color = mix(color, haze_color, max(haze * haze_color.a, 0.0));
	color = mix(color, outer_sheath_color, max(outer_sheath * outer_sheath_color.a, 0.0));
	color = mix(color, sheath_color, max(sheath * sheath_color.a, 0.0));
	color = mix(color, outer_mid_color, max(outer_mid * outer_mid_color.a, 0.0));
	color = mix(color, mid_color, max(mid * mid_color.a, 0.0));
	color = mix(color, inner_color, max(inner * inner_color.a, 0.0));
	color = mix(color, inner_glow_color, max(inner_glow * inner_glow_color.a, 0.0));
	color = mix(color, inner_core_color, max(inner_core * inner_core_color.a, 0.0));
	color = mix(color, core_color, max(core * core_color.a, 0.0));
	color = mix(color, core_tint_color, max(core_tint * core_tint_color.a, 0.0));
	color = mix(color, filament_color, filament);
	color = mix(color, filament_hot_color, filament_hot);
	color.rgb *= longitudinal_gain;

	float alpha = max(
		max(mist * mist_color.a, haze * haze_color.a),
		max(
			max(outer_sheath * outer_sheath_color.a, sheath * sheath_color.a),
			max(
				max(outer_mid * outer_mid_color.a, mid * mid_color.a),
				max(
					max(inner * inner_color.a, inner_glow * inner_glow_color.a),
					max(inner_core * inner_core_color.a, max(core * core_color.a, max(core_tint * core_tint_color.a, max(filament, filament_hot))))
				)
			)
		)
	);
	COLOR = vec4(color.rgb, alpha);
}
"""
	return shader


func build_fog_shader() -> Shader:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 fog_inner_color : source_color = vec4(0.76, 0.94, 1.0, 0.016);
uniform vec4 fog_outer_color : source_color = vec4(0.40, 0.76, 0.96, 0.010);
uniform float endpoint_fade_ratio = 0.18;
uniform float fog_center_strength = 0.80;
uniform float fog_inner_strength = 0.58;
uniform float fog_outer_strength = 0.90;
uniform float fog_center_brightness = 1.04;
uniform float fog_edge_brightness = 0.88;
uniform float fog_center_focus = 0.60;

void fragment() {
	vec2 uv = UV;
	float center_dist = abs(uv.y - 0.5) * 2.0;
	float end_fade = smoothstep(0.0, endpoint_fade_ratio, uv.x) * (1.0 - smoothstep(1.0 - endpoint_fade_ratio, 1.0, uv.x));
	float center_profile = pow(max(1.0 - abs(uv.x - 0.5) * 2.0, 0.0), fog_center_focus);
	float longitudinal_gain = mix(fog_edge_brightness, fog_center_brightness, center_profile);
	float inner_mask = smoothstep(fog_inner_strength, fog_center_strength, center_dist);
	inner_mask *= 1.0 - smoothstep(fog_center_strength, fog_outer_strength, center_dist);
	float outer_mask = smoothstep(fog_center_strength, fog_outer_strength, center_dist);
	outer_mask *= 1.0 - smoothstep(fog_outer_strength, 1.0, center_dist);
	outer_mask = max(outer_mask, 0.0);
	inner_mask = max(inner_mask, 0.0);

	vec4 color = vec4(0.0);
	color += fog_outer_color * outer_mask;
	color = mix(color, fog_inner_color, max(inner_mask * fog_inner_color.a, 0.0));
	color.rgb *= longitudinal_gain;

	float alpha = max(outer_mask * fog_outer_color.a, inner_mask * fog_inner_color.a) * end_fade;
	COLOR = vec4(color.rgb, alpha);
}
"""
	return shader


func build_ring_shader() -> Shader:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 ring_primary_color : source_color = vec4(0.94, 0.99, 1.0, 0.78);
uniform vec4 ring_secondary_color : source_color = vec4(0.58, 0.88, 1.0, 0.48);
uniform vec4 ring_glow_color : source_color = vec4(0.42, 0.84, 1.0, 0.28);
uniform vec4 ring_hot_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 ring_shadow_color : source_color = vec4(0.28, 0.66, 0.96, 0.32);
uniform float ring_cycle_length = 72.0;
uniform float ring_scroll_speed = 16.0;
uniform float ring_wave_amplitude = 0.165;
uniform float ring_wave_thickness = 0.012;
uniform float ring_glow_thickness = 0.026;
uniform float ring_center_spread = 0.0;
uniform float ring_endpoint_fade_length = 48.0;
uniform float ring_visibility = 1.0;
uniform float line_pixel_length = 120.0;
uniform float ring_front_layer = 0.0;
uniform float ring_fragment_fill = 0.68;
uniform float ring_fragment_min_length = 0.28;
uniform float ring_fragment_max_length = 0.64;
uniform float ring_front_visibility = 0.82;
uniform float ring_fragment_life_speed = 0.72;
uniform float ring_fragment_head_boost = 1.18;
uniform float ring_fragment_tail_softness = 0.16;
uniform float ring_fragment_taper_power = 0.54;
uniform float ring_fragment_core_ratio = 0.46;
uniform float ring_fragment_random_offset = 0.42;
uniform float ring_fragment_brightness = 1.18;
uniform float ring_fragment_spawn_per_cell = 2.0;
uniform float ring_fragment_max_travel = 0.42;
uniform float ring_fragment_min_travel = 0.14;
uniform float ring_fragment_max_width_scale = 1.24;
uniform float ring_fragment_min_width_scale = 0.62;
uniform float ring_fragment_fade_start = 0.68;
uniform float ring_fragment_fade_end = 1.0;
uniform float ring_fragment_shrink_strength = 0.46;

float line_mask(float dist_value, float thickness, float softness) {
	return 1.0 - smoothstep(thickness, thickness + softness, dist_value);
}

float hash11(float value) {
	return fract(sin(value * 127.1) * 43758.5453123);
}

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float safe_cycle = max(ring_cycle_length, 8.0);
	float safe_length = max(line_pixel_length, 1.0);
	float pixel_x = uv.x * safe_length;
	float moved_pixel_x = pixel_x + TIME * ring_scroll_speed;
	float center_y = 0.5;
	float x_fade = smoothstep(0.0, ring_endpoint_fade_length, pixel_x) * (1.0 - smoothstep(safe_length - ring_endpoint_fade_length, safe_length, pixel_x));
	float body_exclusion = smoothstep(0.035, 0.095, abs(uv.y - center_y));
	float cell_index = floor(moved_pixel_x / safe_cycle);
	float cell_phase = fract(moved_pixel_x / safe_cycle);

	float alpha_a = 0.0;
	float alpha_b = 0.0;
	float glow_alpha = 0.0;
	float hot_alpha = 0.0;
	float shadow_alpha = 0.0;

	for (int lane = 0; lane < 2; lane++) {
		float lane_index = float(lane);
		float side_sign = lane_index < 0.5 ? -1.0 : 1.0;
		float lane_direction_sign = hash11(cell_index * 5.37 + lane_index * 13.1 + 61.4) < 0.5 ? -1.0 : 1.0;
		for (int slot = 0; slot < 3; slot++) {
			float slot_index = float(slot);
			float slot_enabled = step(slot_index, ring_fragment_spawn_per_cell - 0.001);
			float seed = cell_index * 7.13 + lane_index * 19.73 + slot_index * 53.17;
			float guaranteed_slot = 1.0 - step(0.5, slot_index);
			float random_active = step(hash11(seed), ring_fragment_fill);
			float active = max(guaranteed_slot, random_active) * slot_enabled;
			float size_seed = hash11(seed + 17.8);
			float front_pick = step(0.5, hash11(seed + 3.71));
			float layer_pick = mix(1.0 - front_pick, front_pick, ring_front_layer);
			float life_rate = mix(1.24, 0.48, size_seed);
			float life_phase = fract(TIME * ring_fragment_life_speed * life_rate + hash11(seed + 51.3));
			float fade_progress = smoothstep(ring_fragment_fade_start, ring_fragment_fade_end, life_phase);
			float life_mask = smoothstep(0.0, 0.14, life_phase) * (1.0 - fade_progress);
			float travel_distance = mix(ring_fragment_min_travel, ring_fragment_max_travel, size_seed);
			float travel_jitter = (hash21(vec2(seed, floor(TIME * ring_fragment_life_speed * 2.6) + slot_index + 0.37)) - 0.5) * ring_fragment_random_offset;
			float slot_anchor = (slot_index + 0.5) / max(ring_fragment_spawn_per_cell, 1.0);
			float base_center = mix(0.12, 0.88, slot_anchor);
			base_center += (hash11(seed + 11.2) - 0.5) * 0.10;
			float segment_center = clamp(base_center + travel_jitter + lane_direction_sign * (life_phase - 0.18) * travel_distance, 0.04, 0.96);
			float segment_length = mix(ring_fragment_min_length, ring_fragment_max_length, size_seed);
			float segment_half = segment_length * 0.5;
			float local_phase = (cell_phase - (segment_center - segment_half)) / max(segment_length, 0.001);
			float inside_segment = step(0.0, local_phase) * (1.0 - step(1.0, local_phase));
			float motion_phase = lane_direction_sign > 0.0 ? local_phase : (1.0 - local_phase);
			float tail_phase = clamp(1.0 - motion_phase, 0.0, 1.0);
			float head_shape = pow(clamp(motion_phase, 0.0, 1.0), 0.26);
			float retreat_phase = clamp((motion_phase - fade_progress * ring_fragment_shrink_strength) / max(1.0 - fade_progress * ring_fragment_shrink_strength, 0.001), 0.0, 1.0);
			float retreat_tail_phase = clamp(1.0 - retreat_phase, 0.0, 1.0);
			float tail_shape = pow(retreat_tail_phase, ring_fragment_taper_power) * mix(1.0, retreat_tail_phase, fade_progress);
			float body_profile = head_shape * tail_shape * 2.65;
			float head_taper = smoothstep(0.0, 0.42, retreat_phase);
			float tail_taper = 1.0 - smoothstep(1.0 - ring_fragment_tail_softness, 1.0, retreat_phase);
			float segment_mask = inside_segment * clamp(body_profile, 0.0, 1.0) * head_taper * tail_taper;
			float vertical_jitter = mix(-0.036, 0.036, hash11(seed + 31.6));
			float lane_center = center_y + side_sign * ring_wave_amplitude + vertical_jitter;
			float dist = abs(uv.y - lane_center);
			float width_scale = mix(ring_fragment_min_width_scale, ring_fragment_max_width_scale, size_seed);
			float thickness_scale = mix(0.22, width_scale * mix(1.0, 0.72, fade_progress), clamp(body_profile, 0.0, 1.0));
			float line_shadow = line_mask(dist, ring_glow_thickness * 1.12 * thickness_scale, 0.024) * segment_mask * active * layer_pick;
			float line_glow = line_mask(dist, ring_glow_thickness * thickness_scale, 0.02) * segment_mask * active * layer_pick;
			float line_body = line_mask(dist, ring_wave_thickness * thickness_scale, 0.012) * segment_mask * active * layer_pick;
			float line_core = line_mask(dist, ring_wave_thickness * ring_fragment_core_ratio * thickness_scale, 0.008) * segment_mask * active * layer_pick;
			float lane_mix = hash11(seed + 41.8);
			float layer_visibility = mix(1.0, ring_front_visibility, ring_front_layer);
			float head_energy = smoothstep(0.04, 0.94, motion_phase);
			float tail_energy = 1.0 - smoothstep(0.08, 0.52, motion_phase);
			float head_highlight = mix(0.84, ring_fragment_head_boost, head_energy);
			alpha_a = max(alpha_a, line_body * mix(0.72, 1.0, lane_mix) * layer_visibility * head_highlight * life_mask * ring_fragment_brightness);
			alpha_b = max(alpha_b, line_body * mix(0.36, 0.72, 1.0 - lane_mix) * 0.82 * layer_visibility * (0.84 + head_energy * 0.16) * life_mask * ring_fragment_brightness);
			hot_alpha = max(hot_alpha, line_core * layer_visibility * (0.66 + head_energy * 0.98) * life_mask * ring_fragment_brightness);
			shadow_alpha = max(shadow_alpha, line_shadow * layer_visibility * (0.56 + tail_energy * 0.28) * life_mask * ring_fragment_brightness);
			glow_alpha = max(glow_alpha, line_glow * layer_visibility * (0.86 + head_energy * 0.28) * life_mask * ring_fragment_brightness);
		}
	}

	alpha_a *= ring_primary_color.a;
	alpha_b *= ring_secondary_color.a;
	glow_alpha *= ring_glow_color.a;
	hot_alpha *= ring_hot_color.a;
	shadow_alpha *= ring_shadow_color.a;

	vec3 rgb = vec3(0.0);
	rgb += ring_shadow_color.rgb * shadow_alpha;
	rgb += ring_glow_color.rgb * glow_alpha;
	rgb = mix(rgb, ring_secondary_color.rgb, alpha_b);
	rgb = mix(rgb, ring_primary_color.rgb, alpha_a);
	rgb = mix(rgb, ring_hot_color.rgb, hot_alpha);

	float alpha = max(max(glow_alpha, hot_alpha), max(shadow_alpha, max(alpha_a, alpha_b))) * x_fade * body_exclusion * ring_visibility;
	COLOR = vec4(rgb, alpha);
}
"""
	return shader


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

	var start_offset: float = get_line_surface_offset(left_radius)
	var end_offset: float = get_line_surface_offset(right_radius)
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


func apply_line_transform() -> void:
	if not line_visible or collapsed_to_dot:
		return

	var delta: Vector2 = line_end - line_start
	var length_value: float = delta.length()
	if length_value <= 0.001:
		return

	position = line_start
	rotation = delta.angle()
	size = Vector2(length_value, 0.0)
	pivot_offset = Vector2.ZERO

	if body_layer != null:
		body_layer.position = Vector2(0.0, -body_height * 0.5)
		body_layer.size = Vector2(length_value, body_height)
	if fog_layer != null:
		fog_layer.position = Vector2(0.0, -fog_height * 0.5)
		fog_layer.size = Vector2(length_value, fog_height)
	if ring_layer != null:
		ring_layer.position = Vector2(0.0, -ring_height * 0.5)
		ring_layer.size = Vector2(length_value, ring_height)
	if ring_front_layer != null:
		ring_front_layer.position = Vector2(0.0, -ring_height * 0.5)
		ring_front_layer.size = Vector2(length_value, ring_height)


func apply_visual_state() -> void:
	visible = line_visible

	if not line_visible:
		return

	if body_layer != null:
		body_layer.visible = body_layer_enabled and not collapsed_to_dot
	if fog_layer != null:
		fog_layer.visible = fog_layer_enabled and not collapsed_to_dot
	if ring_layer != null:
		ring_layer.visible = ring_layer_enabled and not collapsed_to_dot
	if ring_front_layer != null:
		ring_front_layer.visible = ring_layer_enabled and not collapsed_to_dot

	if collapsed_to_dot:
		rotation = 0.0
		position = line_start
		size = Vector2.ZERO
		return

	update_material_params()


func update_material_params() -> void:
	if body_material != null:
		body_material.set_shader_parameter("filament_color", filament_color)
		body_material.set_shader_parameter("filament_hot_color", filament_hot_color)
		body_material.set_shader_parameter("core_tint_color", core_tint_color)
		body_material.set_shader_parameter("core_color", core_color)
		body_material.set_shader_parameter("inner_glow_color", inner_glow_color)
		body_material.set_shader_parameter("inner_core_color", inner_core_color)
		body_material.set_shader_parameter("inner_color", inner_color)
		body_material.set_shader_parameter("outer_mid_color", outer_mid_color)
		body_material.set_shader_parameter("mid_color", mid_color)
		body_material.set_shader_parameter("outer_sheath_color", outer_sheath_color)
		body_material.set_shader_parameter("sheath_color", sheath_color)
		body_material.set_shader_parameter("haze_color", haze_color)
		body_material.set_shader_parameter("mist_color", mist_color)
		body_material.set_shader_parameter("filament_width_ratio", filament_width_ratio)
		body_material.set_shader_parameter("filament_hot_width_ratio", filament_hot_width_ratio)
		body_material.set_shader_parameter("core_tint_width_ratio", core_tint_width_ratio)
		body_material.set_shader_parameter("core_width_ratio", core_width_ratio)
		body_material.set_shader_parameter("inner_glow_width_ratio", inner_glow_width_ratio)
		body_material.set_shader_parameter("inner_core_width_ratio", inner_core_width_ratio)
		body_material.set_shader_parameter("inner_width_ratio", inner_width_ratio)
		body_material.set_shader_parameter("outer_mid_width_ratio", outer_mid_width_ratio)
		body_material.set_shader_parameter("mid_width_ratio", mid_width_ratio)
		body_material.set_shader_parameter("outer_sheath_width_ratio", outer_sheath_width_ratio)
		body_material.set_shader_parameter("sheath_width_ratio", sheath_width_ratio)
		body_material.set_shader_parameter("haze_width_ratio", haze_width_ratio)
		body_material.set_shader_parameter("mist_width_ratio", mist_width_ratio)
		body_material.set_shader_parameter("endpoint_fade_ratio", endpoint_fade_ratio)
		body_material.set_shader_parameter("center_brightness", center_brightness)
		body_material.set_shader_parameter("edge_brightness", edge_brightness)
		body_material.set_shader_parameter("center_focus", center_focus)
		body_material.set_shader_parameter("outer_falloff_strength", outer_falloff_strength)
		body_material.set_shader_parameter("core_hot_boost", core_hot_boost)

	if fog_material != null:
		fog_material.set_shader_parameter("fog_inner_color", fog_inner_color)
		fog_material.set_shader_parameter("fog_outer_color", fog_outer_color)
		fog_material.set_shader_parameter("endpoint_fade_ratio", endpoint_fade_ratio)
		fog_material.set_shader_parameter("fog_center_strength", fog_center_strength)
		fog_material.set_shader_parameter("fog_inner_strength", fog_inner_strength)
		fog_material.set_shader_parameter("fog_outer_strength", fog_outer_strength)
		fog_material.set_shader_parameter("fog_center_brightness", fog_center_brightness)
		fog_material.set_shader_parameter("fog_edge_brightness", fog_edge_brightness)
		fog_material.set_shader_parameter("fog_center_focus", fog_center_focus)

	if ring_material != null:
		ring_material.set_shader_parameter("ring_primary_color", ring_primary_color)
		ring_material.set_shader_parameter("ring_secondary_color", ring_secondary_color)
		ring_material.set_shader_parameter("ring_glow_color", ring_glow_color)
		ring_material.set_shader_parameter("ring_hot_color", ring_hot_color)
		ring_material.set_shader_parameter("ring_shadow_color", ring_shadow_color)
		ring_material.set_shader_parameter("ring_cycle_length", ring_cycle_length)
		ring_material.set_shader_parameter("ring_scroll_speed", ring_scroll_speed)
		ring_material.set_shader_parameter("ring_wave_amplitude", ring_wave_amplitude)
		ring_material.set_shader_parameter("ring_wave_thickness", ring_wave_thickness)
		ring_material.set_shader_parameter("ring_glow_thickness", ring_glow_thickness)
		ring_material.set_shader_parameter("ring_center_spread", ring_center_spread)
		ring_material.set_shader_parameter("ring_endpoint_fade_length", ring_endpoint_fade_length)
		ring_material.set_shader_parameter("ring_visibility", ring_visibility)
		ring_material.set_shader_parameter("line_pixel_length", current_line_length)
		ring_material.set_shader_parameter("ring_front_layer", 0.0)
		ring_material.set_shader_parameter("ring_fragment_fill", ring_fragment_fill)
		ring_material.set_shader_parameter("ring_fragment_min_length", ring_fragment_min_length)
		ring_material.set_shader_parameter("ring_fragment_max_length", ring_fragment_max_length)
		ring_material.set_shader_parameter("ring_front_visibility", ring_front_visibility)
		ring_material.set_shader_parameter("ring_fragment_life_speed", ring_fragment_life_speed)
		ring_material.set_shader_parameter("ring_fragment_head_boost", ring_fragment_head_boost)
		ring_material.set_shader_parameter("ring_fragment_tail_softness", ring_fragment_tail_softness)
		ring_material.set_shader_parameter("ring_fragment_taper_power", ring_fragment_taper_power)
		ring_material.set_shader_parameter("ring_fragment_core_ratio", ring_fragment_core_ratio)
		ring_material.set_shader_parameter("ring_fragment_random_offset", ring_fragment_random_offset)
		ring_material.set_shader_parameter("ring_fragment_brightness", ring_fragment_brightness)
		ring_material.set_shader_parameter("ring_fragment_spawn_per_cell", ring_fragment_spawn_per_cell)
		ring_material.set_shader_parameter("ring_fragment_max_travel", ring_fragment_max_travel)
		ring_material.set_shader_parameter("ring_fragment_min_travel", ring_fragment_min_travel)
		ring_material.set_shader_parameter("ring_fragment_max_width_scale", ring_fragment_max_width_scale)
		ring_material.set_shader_parameter("ring_fragment_min_width_scale", ring_fragment_min_width_scale)
		ring_material.set_shader_parameter("ring_fragment_fade_start", ring_fragment_fade_start)
		ring_material.set_shader_parameter("ring_fragment_fade_end", ring_fragment_fade_end)
		ring_material.set_shader_parameter("ring_fragment_shrink_strength", ring_fragment_shrink_strength)

	if ring_front_material != null:
		ring_front_material.set_shader_parameter("ring_primary_color", ring_primary_color)
		ring_front_material.set_shader_parameter("ring_secondary_color", ring_secondary_color)
		ring_front_material.set_shader_parameter("ring_glow_color", ring_glow_color)
		ring_front_material.set_shader_parameter("ring_hot_color", ring_hot_color)
		ring_front_material.set_shader_parameter("ring_shadow_color", ring_shadow_color)
		ring_front_material.set_shader_parameter("ring_cycle_length", ring_cycle_length)
		ring_front_material.set_shader_parameter("ring_scroll_speed", ring_scroll_speed)
		ring_front_material.set_shader_parameter("ring_wave_amplitude", ring_wave_amplitude)
		ring_front_material.set_shader_parameter("ring_wave_thickness", ring_wave_thickness)
		ring_front_material.set_shader_parameter("ring_glow_thickness", ring_glow_thickness)
		ring_front_material.set_shader_parameter("ring_center_spread", ring_center_spread)
		ring_front_material.set_shader_parameter("ring_endpoint_fade_length", ring_endpoint_fade_length)
		ring_front_material.set_shader_parameter("ring_visibility", ring_visibility)
		ring_front_material.set_shader_parameter("line_pixel_length", current_line_length)
		ring_front_material.set_shader_parameter("ring_front_layer", 1.0)
		ring_front_material.set_shader_parameter("ring_fragment_fill", ring_fragment_fill)
		ring_front_material.set_shader_parameter("ring_fragment_min_length", ring_fragment_min_length)
		ring_front_material.set_shader_parameter("ring_fragment_max_length", ring_fragment_max_length)
		ring_front_material.set_shader_parameter("ring_front_visibility", ring_front_visibility)
		ring_front_material.set_shader_parameter("ring_fragment_life_speed", ring_fragment_life_speed)
		ring_front_material.set_shader_parameter("ring_fragment_head_boost", ring_fragment_head_boost)
		ring_front_material.set_shader_parameter("ring_fragment_tail_softness", ring_fragment_tail_softness)
		ring_front_material.set_shader_parameter("ring_fragment_taper_power", ring_fragment_taper_power)
		ring_front_material.set_shader_parameter("ring_fragment_core_ratio", ring_fragment_core_ratio)
		ring_front_material.set_shader_parameter("ring_fragment_random_offset", ring_fragment_random_offset)
		ring_front_material.set_shader_parameter("ring_fragment_brightness", ring_fragment_brightness)
		ring_front_material.set_shader_parameter("ring_fragment_spawn_per_cell", ring_fragment_spawn_per_cell)
		ring_front_material.set_shader_parameter("ring_fragment_max_travel", ring_fragment_max_travel)
		ring_front_material.set_shader_parameter("ring_fragment_min_travel", ring_fragment_min_travel)
		ring_front_material.set_shader_parameter("ring_fragment_max_width_scale", ring_fragment_max_width_scale)
		ring_front_material.set_shader_parameter("ring_fragment_min_width_scale", ring_fragment_min_width_scale)
		ring_front_material.set_shader_parameter("ring_fragment_fade_start", ring_fragment_fade_start)
		ring_front_material.set_shader_parameter("ring_fragment_fade_end", ring_fragment_fade_end)
		ring_front_material.set_shader_parameter("ring_fragment_shrink_strength", ring_fragment_shrink_strength)


func hide_line() -> void:
	current_line_length = 0.0
	line_visible = false
	collapsed_to_dot = false
	position = Vector2.ZERO
	rotation = 0.0
	queue_redraw()


func draw_endpoint_at(center: Vector2, reverse_flare: bool) -> void:
	var flare_dir: float = -1.0 if reverse_flare else 1.0
	var outer_end: Vector2 = center + Vector2(flare_dir * endpoint_bridge_length, 0.0)
	var core_end: Vector2 = center + Vector2(flare_dir * endpoint_core_length, 0.0)
	draw_soft_line_stack(center, outer_end, endpoint_bridge_width * 1.02, endpoint_beam_color, endpoint_taper_steps + 2, 0.12)
	draw_soft_line_stack(center, core_end, endpoint_core_radius * 2.2, endpoint_beam_core_color, endpoint_taper_steps + 1, 0.18)
	draw_rich_endpoint_disc(center)


func draw_collapsed_dot() -> void:
	var tail_start: Vector2 = Vector2(-collapsed_dot_tail_length * 0.45, 0.0)
	var tail_end: Vector2 = Vector2(collapsed_dot_tail_length * 0.72, 0.0)
	draw_soft_line_stack(tail_start, tail_end, collapsed_dot_radius * 1.18, collapsed_dot_haze_color, 8, 0.10)
	draw_soft_line_stack(tail_start, tail_end, collapsed_dot_radius * 0.76, collapsed_dot_glow_color, 7, 0.16)
	draw_soft_disc(Vector2.ZERO, collapsed_dot_radius * 2.15, collapsed_dot_haze_color, collapsed_dot_steps, 0.06)
	draw_soft_disc(Vector2.ZERO, collapsed_dot_radius * 1.52, collapsed_dot_glow_color, collapsed_dot_steps, 0.10)
	draw_soft_disc(Vector2.ZERO, collapsed_dot_radius * 1.04, collapsed_dot_color, collapsed_dot_steps - 2, 0.16)
	draw_soft_disc(Vector2.ZERO, collapsed_dot_radius * 0.58, collapsed_dot_core_color, collapsed_dot_steps - 4, 0.24)
	draw_soft_disc(Vector2.ZERO, collapsed_dot_radius * 0.34, endpoint_core_hot_color, collapsed_dot_steps - 6, 0.34)


func draw_rich_endpoint_disc(center: Vector2) -> void:
	draw_soft_disc(center, endpoint_haze_radius * endpoint_haze_spread, endpoint_outer_color, endpoint_disc_steps, 0.05)
	draw_soft_disc(center, endpoint_haze_radius * 1.02, endpoint_haze_color, endpoint_disc_steps, 0.07)
	draw_soft_disc(center, endpoint_glow_radius * endpoint_mid_spread, endpoint_mid_color, endpoint_disc_steps - 2, 0.11)
	draw_soft_disc(center, endpoint_glow_radius * 0.98, endpoint_glow_color, endpoint_disc_steps - 3, 0.14)
	draw_soft_disc(center, (endpoint_core_radius + 1.5) * endpoint_core_spread, core_color, endpoint_disc_steps - 5, 0.18)
	draw_soft_disc(center, (endpoint_core_radius + 0.76) * endpoint_core_spread, endpoint_core_color, endpoint_disc_steps - 6, 0.22)
	draw_soft_disc(center, endpoint_core_radius * endpoint_core_spread, endpoint_core_hot_color, endpoint_disc_steps - 8, 0.30)


func draw_soft_disc(center: Vector2, radius_value: float, color_value: Color, steps: int, alpha_scale: float) -> void:
	if radius_value <= 0.0 or steps <= 0:
		return
	for index: int in range(steps, 0, -1):
		var t: float = float(index) / float(steps)
		var ring_radius: float = radius_value * t
		var ring_color: Color = color_value
		ring_color.a *= alpha_scale * pow(t, 2.8)
		draw_circle(center, ring_radius, ring_color)


func draw_soft_line_stack(from_point: Vector2, to_point: Vector2, width_value: float, color_value: Color, steps: int, alpha_scale: float) -> void:
	if width_value <= 0.0 or steps <= 0:
		return
	for index: int in range(steps, 0, -1):
		var t: float = float(index) / float(steps)
		var line_color: Color = color_value
		line_color.a *= alpha_scale * pow(t, 2.4)
		draw_line(from_point, to_point, line_color, width_value * t, true)


func get_line_surface_offset(radius_value: float) -> float:
	return maxf(radius_value + line_surface_gap + line_endpoint_extra_length - line_end_inset, 0.0)


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
