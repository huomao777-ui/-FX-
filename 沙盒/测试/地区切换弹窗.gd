extends Control

const DRAG_SWITCH_THRESHOLD: float = 72.0

var _current_index: int = 2
var _dragging: bool = false
var _drag_start_x: float = 0.0

var _title_label: Label
var _belt_area: Control
var _left_button: Control
var _right_button: Control
var _slots: Array[Dictionary] = []
var _countries: Array[Dictionary] = []

func _ready() -> void:
	_cache_nodes()
	_cache_countries_from_scene()
	_bind_input()
	_refresh_display()

func _cache_nodes() -> void:
	_title_label = get_node("弹窗主体/顶部栏/当前地区标题") as Label
	_belt_area = get_node("弹窗主体/地区传送带区") as Control
	_left_button = get_node("弹窗主体/顶部栏/左切换按钮") as Control
	_right_button = get_node("弹窗主体/顶部栏/右切换按钮") as Control

	_slots = [
		_build_slot("弹窗主体/地区传送带区/徽章轨道/地区项1"),
		_build_slot("弹窗主体/地区传送带区/徽章轨道/地区项2"),
		_build_slot("弹窗主体/地区传送带区/徽章轨道/当前地区项"),
		_build_slot("弹窗主体/地区传送带区/徽章轨道/地区项4"),
		_build_slot("弹窗主体/地区传送带区/徽章轨道/地区项5"),
		_build_slot("弹窗主体/地区传送带区/徽章轨道/地区项6"),
		_build_slot("弹窗主体/地区传送带区/徽章轨道/地区项7"),
	]

	if _belt_area != null:
		_belt_area.clip_children = CanvasItem.CLIP_CHILDREN_ONLY

func _build_slot(base_path: String) -> Dictionary:
	return {
		"panel": get_node(base_path) as Panel,
		"icon": get_node(base_path + "/徽章") as TextureRect,
		"name": get_node(base_path + "/名称") as Label,
		"code": get_node(base_path + "/简称") as Label,
	}

func _cache_countries_from_scene() -> void:
	_countries.clear()
	for slot: Dictionary in _slots:
		var icon_node: TextureRect = slot["icon"] as TextureRect
		var name_node: Label = slot["name"] as Label
		var code_node: Label = slot["code"] as Label
		_countries.append({
			"name": name_node.text,
			"code": code_node.text,
			"icon": icon_node.texture,
		})

func _bind_input() -> void:
	if _left_button != null:
		_left_button.gui_input.connect(_on_left_button_input)
	if _right_button != null:
		_right_button.gui_input.connect(_on_right_button_input)
	if _belt_area != null:
		_belt_area.gui_input.connect(_on_belt_area_input)

func _on_left_button_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_shift_current(-1)

func _on_right_button_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_shift_current(1)

func _on_belt_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start_x = event.position.x
			accept_event()
		else:
			_finish_drag(event.position.x)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var delta: float = event.position.x - _drag_start_x
		if absf(delta) >= DRAG_SWITCH_THRESHOLD:
			var step: int = -1 if delta > 0.0 else 1
			_shift_current(step)
			_drag_start_x = event.position.x
			accept_event()

func _finish_drag(end_x: float) -> void:
	if not _dragging:
		return
	_dragging = false
	var delta: float = end_x - _drag_start_x
	if absf(delta) >= DRAG_SWITCH_THRESHOLD:
		var step: int = -1 if delta > 0.0 else 1
		_shift_current(step)

func _shift_current(step: int) -> void:
	if _countries.is_empty():
		return
	_current_index = posmod(_current_index + step, _countries.size())
	_refresh_display()

func _refresh_display() -> void:
	if _countries.is_empty():
		return

	for i: int in range(_slots.size()):
		var slot: Dictionary = _slots[i]
		var country_index: int = posmod(_current_index + i - 2, _countries.size())
		var country: Dictionary = _countries[country_index]
		(slot["icon"] as TextureRect).texture = country["icon"]
		(slot["name"] as Label).text = country["name"]
		(slot["code"] as Label).text = country["code"]

	if _title_label != null:
		var current_country: Dictionary = _countries[_current_index]
		_title_label.text = "<%s>" % current_country["name"]
