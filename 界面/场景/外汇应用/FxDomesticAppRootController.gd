extends Control
class_name FxDomesticAppRootController

@export var 进入时启用汇率专注时间: bool = true
@export var 进入时启用盯盘耗电: bool = true
@export var 离开时恢复普通状态: bool = true

func _ready() -> void:
	# 页面级轻量主控：只负责进入/退出应用时的全局状态，不承载具体UI交互。
	if not _has_game_data_manager():
		return
	if 进入时启用汇率专注时间 and GameDataManager.时间 != null:
		GameDataManager.时间.进入汇率专注时间流动()
	if 进入时启用盯盘耗电 and GameDataManager.手机 != null:
		GameDataManager.手机.进入汇率盯盘使用状态()

func _exit_tree() -> void:
	if not 离开时恢复普通状态 or not _has_game_data_manager():
		return
	if GameDataManager.时间 != null:
		GameDataManager.时间.进入普通时间流动()
	if GameDataManager.手机 != null:
		GameDataManager.手机.进入普通手机使用状态()

func _has_game_data_manager() -> bool:
	return get_node_or_null("/root/GameDataManager") != null
