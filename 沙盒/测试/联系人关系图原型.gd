extends Panel

const BACKGROUND_COLOR := Color(0.02, 0.03, 0.06, 1.0)
const STAR_COLOR := Color(1.0, 1.0, 1.0, 0.72)
const LINE_COLOR := Color(0.47, 0.73, 0.98, 0.28)
const LINE_HIGHLIGHT_COLOR := Color(0.76, 0.9, 1.0, 0.95)
const NODE_FILL_COLOR := Color(0.08, 0.12, 0.19, 0.96)
const CARD_BG_COLOR := Color(0.05, 0.09, 0.16, 0.94)
const CARD_BORDER_COLOR := Color(0.54, 0.77, 1.0, 0.55)
const CARD_TEXT_COLOR := Color(0.93, 0.97, 1.0, 1.0)
const CARD_SUBTEXT_COLOR := Color(0.73, 0.82, 0.93, 0.9)
const BUTTON_BG_COLOR := Color(0.08, 0.13, 0.21, 0.92)
const BUTTON_ACTIVE_COLOR := Color(0.2, 0.4, 0.66, 0.95)
const BUTTON_BORDER_COLOR := Color(0.58, 0.8, 1.0, 0.55)
const MIN_SCALE := 0.62
const MAX_SCALE := 2.35
const SECONDARY_LINKS_SCALE_THRESHOLD := 0.95
const DRAG_THRESHOLD := 8.0

var _star_points: Array[Dictionary] = []
var _people: Array[Dictionary] = []
var _links: Array[PackedInt32Array] = []
var _selected_id: int = 0
var _focus_id: int = -1
var _view_center: Vector2 = Vector2.ZERO
var _view_scale: float = 1.0
var _pulse_time: float = 0.0
var _show_secondary_links: bool = false
var _button_rect: Rect2 = Rect2(20.0, 76.0, 128.0, 30.0)
var _is_dragging: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_last_mouse: Vector2 = Vector2.ZERO
var _press_started_on_person_id: int = -1
var _press_started_on_button: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_demo_data()
	_generate_star_field()
	_reset_view(false)
	set_process(true)


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
		return

	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
		_zoom_at_position(1.12, mouse_event.position)
		accept_event()
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
		_zoom_at_position(1.0 / 1.12, mouse_event.position)
		accept_event()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var local_pos := mouse_event.position
	var hit_id := _find_person_at(local_pos)

	if mouse_event.pressed:
		_drag_start_mouse = local_pos
		_drag_last_mouse = local_pos
		_is_dragging = false
		_press_started_on_person_id = hit_id
		_press_started_on_button = _button_rect.has_point(local_pos)
		if mouse_event.double_click:
			if _press_started_on_button:
				_toggle_secondary_links()
			elif hit_id >= 0:
				_select_person(hit_id, true)
			else:
				_reset_view(true)
			accept_event()
			return
		accept_event()
		return

	if _is_dragging:
		_is_dragging = false
		accept_event()
		return

	if _press_started_on_button and _button_rect.has_point(local_pos):
		_toggle_secondary_links()
		accept_event()
		return

	if _press_started_on_person_id >= 0 and hit_id == _press_started_on_person_id:
		_select_person(hit_id, false)
		accept_event()
		return

	if hit_id >= 0:
		_select_person(hit_id, false)
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR, true)
	_draw_stars()
	_draw_links()
	_draw_people()
	_draw_hud()
	if _focus_id >= 0:
		_draw_info_card(_get_person(_focus_id))


func _build_demo_data() -> void:
	_people = [
		{"id": 0, "name": "主角", "role": "关系中心", "summary": "擅长观察局势，和所有人的关系都会牵动局面。", "detail": "最近状态：正在重新整理自己的人脉网络。", "pos": Vector2(0.0, 0.0), "radius": 46.0, "color": Color(0.53, 0.83, 1.0, 1.0)},
		{"id": 1, "name": "林夏", "role": "旧友", "summary": "大学时期最默契的朋友，现在联系忽远忽近。", "detail": "信任度高，但彼此都在试探是否要重新靠近。", "pos": Vector2(-152.0, -118.0), "radius": 34.0, "color": Color(1.0, 0.74, 0.59, 1.0)},
		{"id": 2, "name": "顾沉", "role": "同事", "summary": "说话克制，常常在关键时刻提供情报。", "detail": "表面合作稳定，但背后还有别的打算。", "pos": Vector2(170.0, -92.0), "radius": 31.0, "color": Color(0.62, 1.0, 0.83, 1.0)},
		{"id": 3, "name": "周柠", "role": "家人", "summary": "最在意你的状态，总想把你拉回安全区。", "detail": "关系稳定，但对你的选择并不完全认同。", "pos": Vector2(208.0, 142.0), "radius": 33.0, "color": Color(0.99, 0.85, 0.52, 1.0)},
		{"id": 4, "name": "许渡", "role": "合作方", "summary": "利益关联很深，彼此都知道不能完全相信对方。", "detail": "合作越紧密，风险也会一起放大。", "pos": Vector2(-198.0, 96.0), "radius": 30.0, "color": Color(0.94, 0.61, 1.0, 1.0)},
		{"id": 5, "name": "阿澈", "role": "线人", "summary": "信息总来得很快，但从不免费。", "detail": "是危险边缘的人，知道太多不该知道的事。", "pos": Vector2(-34.0, 202.0), "radius": 28.0, "color": Color(0.72, 0.79, 1.0, 1.0)},
		{"id": 6, "name": "沈闻", "role": "竞争者", "summary": "你最强的对手之一，关系紧张却互相欣赏。", "detail": "一旦局势变化，可能会成为敌人，也可能是盟友。", "pos": Vector2(34.0, -212.0), "radius": 29.0, "color": Color(1.0, 0.55, 0.55, 1.0)}
	]

	_links = [
		PackedInt32Array([0, 1]),
		PackedInt32Array([0, 2]),
		PackedInt32Array([0, 3]),
		PackedInt32Array([0, 4]),
		PackedInt32Array([0, 5]),
		PackedInt32Array([0, 6]),
		PackedInt32Array([1, 4]),
		PackedInt32Array([1, 6]),
		PackedInt32Array([2, 3]),
		PackedInt32Array([2, 6]),
		PackedInt32Array([4, 5])
	]


func _generate_star_field() -> void:
	_star_points.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260630
	for i in range(78):
		_star_points.append({
			"pos": Vector2(rng.randf_range(16.0, size.x - 16.0), rng.randf_range(18.0, size.y - 18.0)),
			"radius": rng.randf_range(0.5, 1.7),
			"phase": rng.randf_range(0.0, TAU),
			"alpha": rng.randf_range(0.16, 0.68)
		})


func _draw_stars() -> void:
	for star in _star_points:
		var phase: float = float(star.phase)
		var alpha: float = float(star.alpha)
		var radius: float = float(star.radius)
		var position: Vector2 = star.pos as Vector2
		var twinkle: float = 0.78 + 0.22 * sin(_pulse_time * 0.8 + phase)
		var color := STAR_COLOR
		color.a = alpha * twinkle
		draw_circle(position, radius, color)


func _draw_links() -> void:
	for link in _links:
		if link.size() < 2:
			continue
		var from_person := _get_person(link[0])
		var to_person := _get_person(link[1])
		if from_person.is_empty() or to_person.is_empty():
			continue

		var from_pos := _world_to_screen(from_person.pos)
		var to_pos := _world_to_screen(to_person.pos)
		var relation_to_selected := _selected_id in link or (_focus_id >= 0 and _focus_id in link)
		var secondary_visible := _show_secondary_links and _view_scale >= SECONDARY_LINKS_SCALE_THRESHOLD
		if not relation_to_selected and not secondary_visible:
			continue
		var highlighted := relation_to_selected
		var color := LINE_HIGHLIGHT_COLOR if highlighted else LINE_COLOR
		var width := 2.6 if highlighted else 1.1

		draw_line(from_pos, to_pos, color, width, true)
		if highlighted:
			draw_circle(from_pos.lerp(to_pos, 0.5), 2.2, Color(0.84, 0.95, 1.0, 0.85))


func _draw_people() -> void:
	for person in _people:
		_draw_person(person)


func _draw_person(person: Dictionary) -> void:
	var person_id: int = int(person.id)
	var world_pos: Vector2 = person.pos as Vector2
	var person_radius: float = float(person.radius)
	var ring_base_color: Color = person.color as Color
	var base_pos := _world_to_screen(world_pos)
	var is_selected := person_id == _selected_id
	var is_focused := person_id == _focus_id
	var scale_boost := 1.0
	if is_selected:
		scale_boost = 1.12
	if is_focused:
		scale_boost = 1.32

	var pulse: float = 1.0 + 0.018 * sin(_pulse_time * 1.8 + float(person_id))
	var radius: float = person_radius * _view_scale * scale_boost * pulse
	var ring_color: Color = ring_base_color
	ring_color.a = 0.96 if is_selected or is_focused else 0.76
	var fill_color := NODE_FILL_COLOR
	if is_focused:
		fill_color = Color(0.1, 0.15, 0.24, 1.0)

	draw_circle(base_pos, radius + 12.0, Color(ring_color.r, ring_color.g, ring_color.b, 0.08))
	if is_selected or is_focused:
		draw_arc(base_pos, radius + 10.0, -PI * 0.2, PI * 1.15, 36, Color(ring_color.r, ring_color.g, ring_color.b, 0.45), 2.0, true)
	draw_circle(base_pos, radius, fill_color)
	draw_arc(base_pos, radius, 0.0, TAU, 48, ring_color, 3.0, true)
	_draw_avatar(base_pos, radius * 0.64, ring_color)

	var font := get_theme_default_font()
	var font_size := 14 if is_focused else 12
	draw_string(font, base_pos + Vector2(0.0, radius + 24.0), str(person.name), HORIZONTAL_ALIGNMENT_CENTER, 120.0, font_size, CARD_TEXT_COLOR)


func _draw_avatar(center: Vector2, avatar_radius: float, tint: Color) -> void:
	draw_circle(center + Vector2(0.0, -avatar_radius * 0.35), avatar_radius * 0.42, tint)
	draw_circle(center + Vector2(0.0, avatar_radius * 0.55), avatar_radius * 0.62, Color(tint.r * 0.72, tint.g * 0.72, tint.b * 0.76, 1.0))
	draw_line(center + Vector2(-avatar_radius * 0.22, -avatar_radius * 0.1), center + Vector2(avatar_radius * 0.22, -avatar_radius * 0.1), Color(0.02, 0.04, 0.08, 0.85), 1.6, true)


func _draw_hud() -> void:
	var font := get_theme_default_font()
	draw_string(font, Vector2(24.0, 34.0), "RELATION MAP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.72, 0.86, 1.0, 0.92))
	draw_string(font, Vector2(24.0, 58.0), "拖动画布，滚轮缩放，单击选中，双击节点查看详情", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, CARD_SUBTEXT_COLOR)
	_draw_toggle_button()
	var link_tip := "当前: 仅显示选中人物关系" if not _show_secondary_links else "当前: 已开启全关系显示"
	if _show_secondary_links and _view_scale < SECONDARY_LINKS_SCALE_THRESHOLD:
		link_tip = "当前: 全关系已开启，但缩放过远时自动隐藏次级关系"
	draw_string(font, Vector2(24.0, 124.0), link_tip, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, CARD_SUBTEXT_COLOR)


func _draw_toggle_button() -> void:
	var active: bool = _show_secondary_links
	var bg_color := BUTTON_ACTIVE_COLOR if active else BUTTON_BG_COLOR
	draw_rect(_button_rect, bg_color, true)
	draw_rect(_button_rect, BUTTON_BORDER_COLOR, false, 2.0)

	var font := get_theme_default_font()
	var button_text := "切换: 全关系"
	draw_string(
		font,
		_button_rect.position + Vector2(_button_rect.size.x * 0.5, 20.0),
		button_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		_button_rect.size.x - 12.0,
		12,
		CARD_TEXT_COLOR
	)


func _draw_info_card(person: Dictionary) -> void:
	if person.is_empty():
		return

	var card_size := Vector2(210.0, 168.0)
	var person_pos: Vector2 = person.pos as Vector2
	var person_color: Color = person.color as Color
	var anchor := _world_to_screen(person_pos) + Vector2(78.0, -22.0)
	if anchor.x + card_size.x > size.x - 18.0:
		anchor.x = size.x - card_size.x - 18.0
	if anchor.y + card_size.y > size.y - 18.0:
		anchor.y = size.y - card_size.y - 18.0
	if anchor.y < 18.0:
		anchor.y = 18.0

	var panel_rect := Rect2(anchor, card_size)
	draw_rect(panel_rect, CARD_BG_COLOR, true)
	draw_rect(panel_rect, CARD_BORDER_COLOR, false, 2.0)

	var font := get_theme_default_font()
	draw_string(font, anchor + Vector2(18.0, 32.0), str(person.name), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, CARD_TEXT_COLOR)
	draw_string(font, anchor + Vector2(18.0, 56.0), str(person.role), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(person_color.r, person_color.g, person_color.b, 1.0))
	draw_multiline_string(font, anchor + Vector2(18.0, 84.0), str(person.summary), HORIZONTAL_ALIGNMENT_LEFT, 174.0, 13, 18, CARD_TEXT_COLOR)
	draw_multiline_string(font, anchor + Vector2(18.0, 126.0), str(person.detail), HORIZONTAL_ALIGNMENT_LEFT, 174.0, 12, 17, CARD_SUBTEXT_COLOR)


func _select_person(person_id: int, focus: bool) -> void:
	_selected_id = person_id
	if focus:
		_focus_id = person_id
		_animate_view_to_person(person_id)
	else:
		_focus_id = -1
		_animate_view(Vector2.ZERO, 1.0)
	queue_redraw()


func _reset_view(animated: bool) -> void:
	_focus_id = -1
	if animated:
		_animate_view(Vector2.ZERO, 1.0)
	else:
		_view_center = Vector2.ZERO
		_view_scale = 1.0
	queue_redraw()


func _animate_view_to_person(person_id: int) -> void:
	var person := _get_person(person_id)
	if person.is_empty():
		return
	_animate_view(person.pos as Vector2, 1.55)


func _animate_view(target_center: Vector2, target_scale: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_view_center", target_center, 0.28)
	tween.tween_property(self, "_view_scale", clampf(target_scale, MIN_SCALE, MAX_SCALE), 0.28)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	return size * 0.5 + (world_pos - _view_center) * _view_scale


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return ((screen_pos - size * 0.5) / maxf(_view_scale, 0.001)) + _view_center


func _find_person_at(screen_pos: Vector2) -> int:
	var world_pos := _screen_to_world(screen_pos)
	for i in range(_people.size() - 1, -1, -1):
		var person := _people[i]
		var person_pos: Vector2 = person.pos as Vector2
		var person_radius: float = float(person.radius)
		if world_pos.distance_to(person_pos) <= person_radius * 1.08:
			return int(person.id)
	return -1


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var left_pressed: bool = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if not left_pressed:
		return
	var current_pos := event.position
	var drag_distance: float = current_pos.distance_to(_drag_start_mouse)
	if not _is_dragging and drag_distance >= DRAG_THRESHOLD:
		_is_dragging = true
	if not _is_dragging:
		return

	var delta_screen := current_pos - _drag_last_mouse
	_view_center -= delta_screen / maxf(_view_scale, 0.001)
	_drag_last_mouse = current_pos
	queue_redraw()
	accept_event()


func _zoom_at_position(zoom_factor: float, screen_pos: Vector2) -> void:
	var before_world := _screen_to_world(screen_pos)
	_view_scale = clampf(_view_scale * zoom_factor, MIN_SCALE, MAX_SCALE)
	var center := size * 0.5
	_view_center = before_world - ((screen_pos - center) / _view_scale)
	queue_redraw()


func _toggle_secondary_links() -> void:
	_show_secondary_links = not _show_secondary_links
	queue_redraw()


func _get_person(person_id: int) -> Dictionary:
	for person in _people:
		if int(person.id) == person_id:
			return person
	return {}
