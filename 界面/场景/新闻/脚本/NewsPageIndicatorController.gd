extends HBoxContainer
class_name NewsPageIndicatorController

const ACTIVE_WIDTH: float = 20.0
const INACTIVE_WIDTH: float = 10.0
const DOT_HEIGHT: float = 10.0
const MIN_BRIDGE_WIDTH: float = 10.0

@export var active_style: StyleBox
@export var inactive_style: StyleBox

var _dots: Array[Panel] = []
var _active_color: Color = Color(0.92, 0.67, 0.15, 1.0)
var _inactive_color: Color = Color(0.57, 0.15, 0.07, 1.0)

func _ready() -> void:
	_collect_dots()
	_cache_style_colors()
	update_indicator(0, 0, 0.0, 0.0)

func update_indicator(from_index: int, to_index: int, progress: float, velocity: float) -> void:
	if _dots.is_empty():
		return

	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	var velocity_boost: float = lerpf(1.0, 1.18, clampf(velocity, 0.0, 1.0))
	for index in _dots.size():
		var dot: Panel = _dots[index]
		var width: float = INACTIVE_WIDTH
		var color: Color = _inactive_color
		if index == from_index and from_index == to_index:
			width = ACTIVE_WIDTH
			color = _active_color
		elif index == from_index:
			width = lerpf(ACTIVE_WIDTH, MIN_BRIDGE_WIDTH, clamped_progress) * velocity_boost
			color = _active_color.lerp(_inactive_color, clamped_progress)
		elif index == to_index:
			width = lerpf(INACTIVE_WIDTH, ACTIVE_WIDTH, clamped_progress) * velocity_boost
			color = _inactive_color.lerp(_active_color, clamped_progress)
		_apply_dot_state(dot, width, color)

func _collect_dots() -> void:
	_dots.clear()
	for child in get_children():
		if child is Panel:
			_dots.append(child as Panel)

func _cache_style_colors() -> void:
	var active_flat: StyleBoxFlat = active_style as StyleBoxFlat
	if active_flat != null:
		_active_color = active_flat.bg_color

	var inactive_flat: StyleBoxFlat = inactive_style as StyleBoxFlat
	if inactive_flat != null:
		_inactive_color = inactive_flat.bg_color

func _apply_dot_state(dot: Panel, width: float, color: Color) -> void:
	dot.custom_minimum_size = Vector2(width, DOT_HEIGHT)
	dot.size = Vector2(width, DOT_HEIGHT)
	var style_override: StyleBoxFlat = _build_style_for_color(color)
	dot.add_theme_stylebox_override("panel", style_override)

func _build_style_for_color(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_right = 9
	style.corner_radius_bottom_left = 9
	return style
