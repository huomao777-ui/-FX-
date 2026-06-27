extends Control
class_name FxDomesticAppRootController

## 页面级轻量主控：负责跨模块信号转发和弹窗管理。
## 按钮连接由 FxCurrencyPanelController 统一处理，符合项目既有模式。
## 弹窗确认信号由本控制器中转至货币面板控制器的数据更新方法。

@export var 进入时启用汇率专注时间: bool = true
@export var 进入时启用盯盘耗电: bool = true
@export var 离开时恢复普通状态: bool = true

var _currency_panel_controller: Node = null
var _reduce_panel: Node = null
var _add_panel: Node = null
var _close_all_panel: Node = null

func _ready() -> void:
	if _has_game_data_manager():
		if 进入时启用汇率专注时间 and GameDataManager.时间 != null:
			GameDataManager.时间.进入汇率专注时间流动()
		if 进入时启用盯盘耗电 and GameDataManager.手机 != null:
			GameDataManager.手机.进入汇率盯盘使用状态()
	_initialize_panels()

func _exit_tree() -> void:
	if not 离开时恢复普通状态 or not _has_game_data_manager():
		return
	if GameDataManager.时间 != null:
		GameDataManager.时间.进入普通时间流动()
	if GameDataManager.手机 != null:
		GameDataManager.手机.进入普通手机使用状态()

## ===== 弹窗初始化与信号连接 =====

func _initialize_panels() -> void:
	_reduce_panel = _find_descendant_by_name(self, "减仓弹窗")
	_add_panel = _find_descendant_by_name(self, "补仓弹窗")
	_close_all_panel = _find_descendant_by_name(self, "一键平仓弹窗")
	_currency_panel_controller = _find_descendant_by_name(self, "货币种类")
	# 连接弹窗确认信号 → 转发到货币面板控制器
	if _reduce_panel != null and _reduce_panel.has_signal("reduce_confirmed"):
		if not _reduce_panel.is_connected("reduce_confirmed", _on_reduce_confirmed):
			_reduce_panel.connect("reduce_confirmed", _on_reduce_confirmed)
	if _add_panel != null and _add_panel.has_signal("add_confirmed"):
		if not _add_panel.is_connected("add_confirmed", _on_add_confirmed):
			_add_panel.connect("add_confirmed", _on_add_confirmed)
	if _close_all_panel != null and _close_all_panel.has_signal("close_all_confirmed"):
		if not _close_all_panel.is_connected("close_all_confirmed", _on_close_all_confirmed):
			_close_all_panel.connect("close_all_confirmed", _on_close_all_confirmed)

## ===== 弹窗确认 → 货币面板数据处理 =====

func _on_reduce_confirmed(slot: Dictionary, reduce_lots: float) -> void:
	if _currency_panel_controller != null and _currency_panel_controller.has_method("处理减仓"):
		_currency_panel_controller.call("处理减仓", slot, reduce_lots)

func _on_add_confirmed(slot: Dictionary, add_lots: float) -> void:
	if _currency_panel_controller != null and _currency_panel_controller.has_method("处理补仓"):
		_currency_panel_controller.call("处理补仓", slot, add_lots)

func _on_close_all_confirmed(slot: Dictionary) -> void:
	if _currency_panel_controller != null and _currency_panel_controller.has_method("处理一键平仓"):
		_currency_panel_controller.call("处理一键平仓", slot)

## ===== 工具 =====

func _has_game_data_manager() -> bool:
	return get_node_or_null("/root/GameDataManager") != null

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
