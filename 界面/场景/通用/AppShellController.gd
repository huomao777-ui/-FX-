extends Control
class_name AppShellController

## 通用 APP 容器壳：负责手机状态切换与统一退回 FullMobile。
## 具体 APP 内部的弹窗/业务回退交给 APP 节点自己的脚本处理。

const FULL_MOBILE_SCENE_PATH := "res://界面/场景/手机/full_mobile.tscn"

@export var 进入时启用汇率专注时间: bool = true
@export var 进入时启用盯盘耗电: bool = true
@export var 离开时恢复普通状态: bool = true

var _app_root: Node = null

func _ready() -> void:
	if _has_game_data_manager():
		if 进入时启用汇率专注时间 and GameDataManager.时间 != null:
			GameDataManager.时间.进入汇率专注时间流动()
		if 进入时启用盯盘耗电 and GameDataManager.手机 != null:
			GameDataManager.手机.进入汇率盯盘使用状态()
	_app_root = _find_descendant_by_name(self, "APP")

func _exit_tree() -> void:
	if not 离开时恢复普通状态 or not _has_game_data_manager():
		return
	if GameDataManager.时间 != null:
		GameDataManager.时间.进入普通时间流动()
	if GameDataManager.手机 != null:
		GameDataManager.手机.进入普通手机使用状态()

## ===== 工具 =====

func 执行外部双击回退() -> String:
	if _app_root != null and _app_root.has_method("执行APP内部回退"):
		if bool(_app_root.call("执行APP内部回退")):
			return "popup"
	if _return_to_full_mobile():
		return "scene"
	return ""

func _return_to_full_mobile() -> bool:
	if ResourceLoader.exists(FULL_MOBILE_SCENE_PATH):
		get_tree().change_scene_to_file(FULL_MOBILE_SCENE_PATH)
		return true
	return false

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
