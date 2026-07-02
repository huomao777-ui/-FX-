extends Control
class_name APPController

var _currency_panel_controller: Node = null
var _open_account_panel: Node = null
var _reduce_panel: Node = null
var _add_panel: Node = null
var _close_all_panel: Node = null

func _ready() -> void:
	_initialize_panels()

func _initialize_panels() -> void:
	_open_account_panel = _find_descendant_by_name(self, "开户面板")
	_reduce_panel = _find_descendant_by_name(self, "减仓弹窗")
	_add_panel = _find_descendant_by_name(self, "补仓弹窗")
	_close_all_panel = _find_descendant_by_name(self, "一键平仓弹窗")
	_currency_panel_controller = _find_descendant_by_name(self, "货币种类")
	if _reduce_panel != null and _reduce_panel.has_signal("reduce_confirmed"):
		if not _reduce_panel.is_connected("reduce_confirmed", _on_reduce_confirmed):
			_reduce_panel.connect("reduce_confirmed", _on_reduce_confirmed)
	if _add_panel != null and _add_panel.has_signal("add_confirmed"):
		if not _add_panel.is_connected("add_confirmed", _on_add_confirmed):
			_add_panel.connect("add_confirmed", _on_add_confirmed)
	if _close_all_panel != null and _close_all_panel.has_signal("close_all_confirmed"):
		if not _close_all_panel.is_connected("close_all_confirmed", _on_close_all_confirmed):
			_close_all_panel.connect("close_all_confirmed", _on_close_all_confirmed)

func _on_reduce_confirmed(slot: Dictionary, reduce_lots: float) -> void:
	if _currency_panel_controller != null and _currency_panel_controller.has_method("处理减仓"):
		_currency_panel_controller.call("处理减仓", slot, reduce_lots)

func _on_add_confirmed(slot: Dictionary, add_lots: float) -> void:
	if _currency_panel_controller != null and _currency_panel_controller.has_method("处理补仓"):
		_currency_panel_controller.call("处理补仓", slot, add_lots)

func _on_close_all_confirmed(slot: Dictionary) -> void:
	if _currency_panel_controller != null and _currency_panel_controller.has_method("处理一键平仓"):
		_currency_panel_controller.call("处理一键平仓", slot)

func 执行APP内部回退() -> bool:
	if _close_top_visible_popup():
		return true
	return false

func _close_top_visible_popup() -> bool:
	var popup_candidates: Array = [
		_open_account_panel,
		_reduce_panel,
		_add_panel,
		_close_all_panel
	]
	var top_popup: CanvasItem = null
	var top_z: int = -2147483648
	for candidate in popup_candidates:
		if not _is_popup_visible(candidate):
			continue
		var item := candidate as CanvasItem
		if item.z_index >= top_z:
			top_z = item.z_index
			top_popup = item
	if top_popup != null and top_popup.has_method("close_panel"):
		top_popup.call("close_panel")
		return true
	if _currency_panel_controller != null and _is_currency_picker_visible():
		if _currency_panel_controller.has_method("_close_currency_picker"):
			_currency_panel_controller.call("_close_currency_picker")
			return true
	return false

func _is_popup_visible(popup: Node) -> bool:
	return popup is CanvasItem and (popup as CanvasItem).visible

func _is_currency_picker_visible() -> bool:
	if _currency_panel_controller == null:
		return false
	var picker := _find_descendant_by_name(self, "货币选择") as CanvasItem
	return picker != null and picker.visible

func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found: Node = _find_descendant_by_name(child, target_name)
		if found != null:
			return found
	return null
