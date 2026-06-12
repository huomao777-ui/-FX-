## 描述: 外汇应用专注状态绑定，进入场景后切换为盯盘耗电和汇率专注时间流动
## 依赖: GameDataManager.时间、GameDataManager.手机
## 状态: 初版
## 最后更新：2026-06-12
extends Control

## ===== 导出配置变量 =====

## 进入场景时是否自动进入汇率专注时间流动
@export var 进入时启用汇率专注时间: bool = true
## 进入场景时是否自动切换手机为盯盘使用状态
@export var 进入时启用盯盘耗电: bool = true
## 离开场景树时是否恢复普通手机时间流动
@export var 离开时恢复普通状态: bool = true

## ===== 生命周期 =====

func _ready() -> void:
	if not _has_game_data_manager():
		return
	if 进入时启用汇率专注时间 and GameDataManager.时间 != null:
		GameDataManager.时间.进入汇率专注时间流动()
	if 进入时启用盯盘耗电 and GameDataManager.手机 != null:
		GameDataManager.手机.进入汇率盯盘使用状态()

func _exit_tree() -> void:
	if not 离开时恢复普通状态:
		return
	if not _has_game_data_manager():
		return
	if GameDataManager.时间 != null:
		GameDataManager.时间.进入普通时间流动()
	if GameDataManager.手机 != null:
		GameDataManager.手机.进入普通手机使用状态()

## ===== 私有方法 =====

func _has_game_data_manager() -> bool:
	return get_node_or_null("/root/GameDataManager") != null
