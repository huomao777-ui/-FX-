extends Panel
class_name NewsBottomFilterBarController

const UNDERLINE_NAME: String = "TextUnderline"
const UNDERLINE_HEIGHT: float = 2.0
const UNDERLINE_GAP: float = 3.0

const NORMAL_TEXT_COLOR: Color = Color(0.98, 0.95, 0.91, 0.92)
const HOVER_TEXT_COLOR: Color = Color(1.0, 0.96, 0.90, 1.0)
const PRESSED_TEXT_COLOR: Color = Color(1.0, 0.93, 0.84, 1.0)
const NORMAL_LINE_COLOR: Color = Color(0.98, 0.95, 0.91, 0.82)
const HOVER_LINE_COLOR: Color = Color(1.0, 0.96, 0.90, 0.96)
const PRESSED_LINE_COLOR: Color = Color(1.0, 0.93, 0.84, 1.0)

@export var hide_popups_on_ready: bool = true
@export var button_row_path: NodePath
@export var popup_controller_path: NodePath

var _button_infos: Array[Dictionary] = []
var _popup_by_button_name: Dictionary = {}


func _ready() -> void:
	_collect_popups()
	_collect_buttons()
	if hide_popups_on_ready:
		_hide_all_popups()
	_sync_all_button_states()


func _process(_delta: float) -> void:
	_sync_all_button_states()


func _collect_popups() -> void:
	_popup_by_button_name.clear()

	var popup_controller: Node = _resolve_popup_controller()
	if popup_controller == null:
		push_warning("NewsBottomFilterBarController: missing popup controller")
		return

	var popup_controls: Array[Control] = []
	for child: Node in popup_controller.get_children():
		if child is Control:
			popup_controls.append(child as Control)

	if popup_controls.size() < 3:
		push_warning("NewsBottomFilterBarController: not enough popup controls")
		return

	var button_row: HBoxContainer = _resolve_button_row()
	if button_row == null:
		return

	var buttons: Array[Button] = _get_buttons_from_row(button_row)
	if buttons.size() < 3:
		push_warning("NewsBottomFilterBarController: not enough buttons")
		return

	_popup_by_button_name[buttons[0].name] = popup_controls[0]
	_popup_by_button_name[buttons[1].name] = popup_controls[2]
	_popup_by_button_name[buttons[2].name] = popup_controls[1]


func _collect_buttons() -> void:
	_button_infos.clear()

	var button_row: HBoxContainer = _resolve_button_row()
	if button_row == null:
		push_warning("NewsBottomFilterBarController: missing button row")
		return

	for button: Button in _get_buttons_from_row(button_row):
		var text_label: Label = _find_button_text_label(button)
		if text_label == null:
			continue

		var underline: ColorRect = _ensure_underline(button, text_label)
		var info: Dictionary = {
			"button": button,
			"text_label": text_label,
			"underline": underline,
		}
		_button_infos.append(info)
		_connect_button_signals(button)


func _resolve_button_row() -> HBoxContainer:
	if not button_row_path.is_empty():
		return get_node_or_null(button_row_path) as HBoxContainer
	for child: Node in get_children():
		if child is HBoxContainer:
			return child as HBoxContainer
	return null


func _resolve_popup_controller() -> Node:
	if not popup_controller_path.is_empty():
		return get_node_or_null(popup_controller_path)
	if get_parent() != null:
		for sibling: Node in get_parent().get_children():
			if sibling == self or not sibling is Control:
				continue
			var popup_like_children: int = 0
			for child: Node in sibling.get_children():
				if child is Control:
					popup_like_children += 1
			if popup_like_children >= 3:
				return sibling
	return null


func _get_buttons_from_row(button_row: HBoxContainer) -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in button_row.get_children():
		if child is Button:
			buttons.append(child as Button)
	return buttons


func _find_button_text_label(button: Button) -> Label:
	var labels: Array[Label] = _find_labels(button)
	if labels.is_empty():
		return null
	var best_label: Label = null
	var best_y: float = -INF
	for label: Label in labels:
		if best_label == null or label.position.y > best_y:
			best_label = label
			best_y = label.position.y
	return best_label


func _find_labels(root: Node) -> Array[Label]:
	var labels: Array[Label] = []
	for child: Node in root.get_children():
		if child is Label:
			labels.append(child as Label)
		labels.append_array(_find_labels(child))
	return labels


func _ensure_underline(button: Button, text_label: Label) -> ColorRect:
	var underline: ColorRect = button.get_node_or_null(UNDERLINE_NAME) as ColorRect
	if underline == null:
		underline = ColorRect.new()
		underline.name = UNDERLINE_NAME
		underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(underline)

	_update_underline_geometry(underline, text_label)
	underline.color = NORMAL_LINE_COLOR
	return underline


func _connect_button_signals(button: Button) -> void:
	if not button.mouse_entered.is_connected(_on_button_mouse_entered.bind(button)):
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	if not button.mouse_exited.is_connected(_on_button_mouse_exited.bind(button)):
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
	if not button.button_down.is_connected(_on_button_button_down.bind(button)):
		button.button_down.connect(_on_button_button_down.bind(button))
	if not button.pressed.is_connected(_on_button_pressed.bind(button)):
		button.pressed.connect(_on_button_pressed.bind(button))
	if not button.resized.is_connected(_on_button_resized.bind(button)):
		button.resized.connect(_on_button_resized.bind(button))


func _on_button_mouse_entered(button: Button) -> void:
	var info: Dictionary = _find_button_info(button)
	if info.is_empty():
		return
	_apply_hover_state(info)


func _on_button_mouse_exited(button: Button) -> void:
	var info: Dictionary = _find_button_info(button)
	if info.is_empty():
		return
	_apply_normal_state(info)


func _on_button_button_down(button: Button) -> void:
	var info: Dictionary = _find_button_info(button)
	if info.is_empty():
		return
	_apply_pressed_state(info)


func _on_button_pressed(button: Button) -> void:
	_toggle_popup_for_button(button.name)
	_sync_all_button_states()


func _on_button_resized(button: Button) -> void:
	var info: Dictionary = _find_button_info(button)
	if info.is_empty():
		return
	var text_label: Label = info.get("text_label", null) as Label
	var underline: ColorRect = info.get("underline", null) as ColorRect
	if text_label == null or underline == null:
		return
	_update_underline_geometry(underline, text_label)


func _toggle_popup_for_button(button_name: String) -> void:
	var target_popup: Control = _popup_by_button_name.get(button_name, null) as Control
	if target_popup == null:
		return
	var should_show: bool = not target_popup.visible
	_hide_all_popups()
	target_popup.visible = should_show


func _hide_all_popups() -> void:
	for popup_value: Variant in _popup_by_button_name.values():
		var popup: Control = popup_value as Control
		if popup != null:
			popup.visible = false


func _sync_all_button_states() -> void:
	for info: Dictionary in _button_infos:
		_sync_button_state(info)


func _sync_button_state(info: Dictionary) -> void:
	var button: Button = info.get("button", null) as Button
	if button == null or not is_instance_valid(button):
		return
	if button.button_pressed:
		_apply_pressed_state(info)
		return
	if _is_button_hovered(button):
		_apply_hover_state(info)
		return
	_apply_normal_state(info)


func _apply_normal_state(info: Dictionary) -> void:
	_apply_visual_state(info, NORMAL_TEXT_COLOR, NORMAL_LINE_COLOR)


func _apply_hover_state(info: Dictionary) -> void:
	_apply_visual_state(info, HOVER_TEXT_COLOR, HOVER_LINE_COLOR)


func _apply_pressed_state(info: Dictionary) -> void:
	_apply_visual_state(info, PRESSED_TEXT_COLOR, PRESSED_LINE_COLOR)


func _apply_visual_state(info: Dictionary, text_color: Color, line_color: Color) -> void:
	var text_label: Label = info.get("text_label", null) as Label
	var underline: ColorRect = info.get("underline", null) as ColorRect
	if text_label != null:
		text_label.add_theme_color_override("font_color", text_color)
	if underline != null:
		underline.color = line_color
		if text_label != null:
			_update_underline_geometry(underline, text_label)


func _update_underline_geometry(underline: ColorRect, text_label: Label) -> void:
	var label_width: float = maxf(text_label.size.x, text_label.get_minimum_size().x)
	var label_height: float = maxf(text_label.size.y, text_label.get_minimum_size().y)
	underline.custom_minimum_size = Vector2(label_width, UNDERLINE_HEIGHT)
	underline.size = underline.custom_minimum_size
	underline.position = Vector2(text_label.position.x, text_label.position.y + label_height + UNDERLINE_GAP)


func _is_button_hovered(button: Button) -> bool:
	if not button.is_visible_in_tree():
		return false
	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	var current: Control = hovered_control
	while current != null:
		if current == button:
			return true
		current = current.get_parent() as Control
	return false


func _find_button_info(button: Button) -> Dictionary:
	for info: Dictionary in _button_infos:
		if info.get("button", null) == button:
			return info
	return {}


func close_all_popups() -> bool:
	var had_visible_popup: bool = false
	for popup_value: Variant in _popup_by_button_name.values():
		var popup: Control = popup_value as Control
		if popup != null and popup.visible:
			popup.visible = false
			had_visible_popup = true
	if had_visible_popup:
		_sync_all_button_states()
	return had_visible_popup


func execute_app_back() -> bool:
	return close_all_popups()
