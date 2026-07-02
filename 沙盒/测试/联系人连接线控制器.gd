extends Control

@export_group("连接线")
@export var min_middle_length: float = 24.0
@export var extra_line_shrink: float = 0.0
@export var end_inset: float = 0.0

var left_avatar: Control = null
var right_avatar: Control = null

var left_cap: Sprite2D = null
var middle_segment: Sprite2D = null
var right_cap: Sprite2D = null

var left_cap_base_scale: Vector2 = Vector2.ONE
var middle_segment_base_scale: Vector2 = Vector2.ONE
var right_cap_base_scale: Vector2 = Vector2.ONE

var left_cap_base_pos: Vector2 = Vector2.ZERO
var middle_segment_base_pos: Vector2 = Vector2.ZERO
var right_cap_base_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cache_parts()
	cache_avatars()
	set_process(true)


func _process(_delta: float) -> void:
	if left_cap == null or middle_segment == null or right_cap == null:
		cache_parts()
	if left_avatar == null or right_avatar == null:
		cache_avatars()
	update_line_visual()


func cache_parts() -> void:
	left_cap = null
	middle_segment = null
	right_cap = null

	var sprites: Array[Sprite2D] = []
	for child: Node in get_children():
		if child is Sprite2D:
			sprites.append(child as Sprite2D)

	if sprites.size() > 0:
		left_cap = sprites[0]
		left_cap_base_scale = left_cap.scale
		left_cap_base_pos = left_cap.position
	if sprites.size() > 1:
		middle_segment = sprites[1]
		middle_segment_base_scale = middle_segment.scale
		middle_segment_base_pos = middle_segment.position
	if sprites.size() > 2:
		right_cap = sprites[2]
		right_cap_base_scale = right_cap.scale
		right_cap_base_pos = right_cap.position


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


func update_line_visual() -> void:
	if left_avatar == null or right_avatar == null:
		visible = false
		return
	if left_cap == null or middle_segment == null or right_cap == null:
		visible = false
		return

	var left_center: Vector2 = get_avatar_center(left_avatar)
	var right_center: Vector2 = get_avatar_center(right_avatar)
	var center_delta: Vector2 = right_center - left_center
	var center_distance: float = center_delta.length()
	if center_distance <= 0.001:
		visible = false
		return

	var direction: Vector2 = center_delta / center_distance
	var left_radius: float = get_avatar_radius(left_avatar)
	var right_radius: float = get_avatar_radius(right_avatar)
	var start_point: Vector2 = left_center + direction * maxf(left_radius - end_inset, 0.0)
	var end_point: Vector2 = right_center - direction * maxf(right_radius - end_inset, 0.0)
	var line_delta: Vector2 = end_point - start_point
	var line_distance: float = line_delta.length()
	if line_distance <= 1.0:
		visible = false
		return

	visible = true
	position = start_point
	rotation = line_delta.angle()

	var left_width: float = get_sprite_display_width(left_cap, left_cap_base_scale)
	var right_width: float = get_sprite_display_width(right_cap, right_cap_base_scale)
	var middle_length: float = maxf(line_distance - left_width - right_width - extra_line_shrink, min_middle_length)
	var middle_texture_width: float = get_sprite_texture_width(middle_segment)

	left_cap.scale = left_cap_base_scale
	left_cap.position = Vector2(left_width * 0.5, left_cap_base_pos.y)

	right_cap.scale = right_cap_base_scale
	right_cap.position = Vector2(line_distance - right_width * 0.5, right_cap_base_pos.y)

	middle_segment.scale = middle_segment_base_scale
	if middle_texture_width > 0.001:
		middle_segment.scale.x = middle_segment_base_scale.x * (middle_length / middle_texture_width)
	middle_segment.position = Vector2(left_width + middle_length * 0.5, middle_segment_base_pos.y)


func get_sprite_texture_width(sprite: Sprite2D) -> float:
	if sprite == null or sprite.texture == null:
		return 0.0
	return sprite.texture.get_size().x


func get_sprite_display_width(sprite: Sprite2D, base_scale: Vector2) -> float:
	if sprite == null or sprite.texture == null:
		return 0.0
	return sprite.texture.get_size().x * absf(base_scale.x)


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
		return 0.0

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
