extends Panel
class_name NewsBottomFilterBarController

const UNDERLINE_NAME: String = "文字2下划线"
const UNDERLINE_HEIGHT: float = 2.0
const UNDERLINE_GAP: float = 3.0

const NORMAL_TEXT_COLOR: Color = Color(0.98, 0.95, 0.91, 0.92)
const HOVER_TEXT_COLOR: Color = Color(1.0, 0.96, 0.90, 1.0)
const PRESSED_TEXT_COLOR: Color = Color(1.0, 0.93, 0.84, 1.0)
const NORMAL_LINE_COLOR: Color = Color(0.98, 0.95, 0.91, 0.82)
const HOVER_LINE_COLOR: Color = Color(1.0, 0.96, 0.90, 0.96)
const PRESSED_LINE_COLOR: Color = Color(1.0, 0.93, 0.84, 1.0)

@export var hide_popups_on_ready: bool = true
@export var button_row_path: NodePath = ^"按钮行"
@export var popup_controller_path: NodePath = ^"../弹窗控制器"

var _button_infos: Array[Dictionary] = []
var _popups: Dictionary = {}


func _ready() -> void:
	_collect_popups()
	_collect_buttons()
	if hide_popups_on_ready:
		_hide_all_popups()
	_sync_all_button_states()


func _process(_delta: float) -> void:
	_sync_all_button_states()


func _collect_popups() -> void:
	_popups.clear()

	var popup_controller: Node = get_node_or_null(popup_controller_path)
	if popup_controller == null:
		push_warning("NewsBottomFilterBarController: missing popup controller")
		return

	_popups["日期按钮"] = popup_controller.get_node_or_null("时间切换弹窗") as Control
	_popups["地区按钮"] = popup_controller.get_node_or_null("地区切换弹窗") as Control
	_popups["分类按钮"] = popup_controller.get_node_or_null("咨询切换弹窗") as Control


func _collect_buttons() -> void:
	_button_infos.clear()

	var button_row: HBoxContainer = get_node_or_null(button_row_path) as HBoxContainer
	if button_row == null:
		push_warning("NewsBottomFilterBarController: missing 按钮行")
		return

	for child: Node in button_row.get_children():
		if not (child is Button):
			continue

		var button: Button = child as Button
		var text_label: Label = button.get_node_or_null("文字2") as Label
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
	var target_popup: Control = _popups.get(button_name, null) as Control
	if target_popup == null:
		return

	var should_show: bool = not target_popup.visible
	_hide_all_popups()
	target_popup.visible = should_show


func _hide_all_popups() -> void:
	for popup: Variant in _popups.values():
		var popup_control: Control = popup as Control
		if popup_control != null:
			popup_control.visible = false


func _sync_all_button_states() -> void:
	for info: Dictionary in _button_infos:
		_sync_button_state(info)


func _sync_button_state(info: Dictionary) -> void:
	var button: Button = info.get("button", null) as Button
	if button == null or not is_instance_valid(button):
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
	underline.position = Vector2(
		text_label.position.x,
		text_label.position.y + label_height + UNDERLINE_GAP
	)


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


func 执行APP内部回退() -> bool:
	return 关闭全部筛选弹窗()


func 关闭全部筛选弹窗() -> bool:
	var had_visible_popup: bool = false
	for popup: Variant in _popups.values():
		var popup_control: Control = popup as Control
		if popup_control != null and popup_control.visible:
			popup_control.visible = false
			had_visible_popup = true

	if had_visible_popup:
		_sync_all_button_states()
	return had_visible_popup
