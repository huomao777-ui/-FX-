## 描述: 手机界面使用状态绑定器，进入界面时设置手机使用状态和时间流动模式
## 依赖: GameDataManager.时间、GameDataManager.手机
## 状态: 初版
## 最后更新：2026-06-12
class_name PhoneUsageBinder
extends Node

## ===== 导出配置变量 =====

## 进入场景时是否设置为普通手机使用状态
@export var 进入时设置普通手机使用: bool = true
## 进入场景时是否设置为普通时间流动
@export var 进入时设置普通时间流动: bool = true
## 离开场景时是否设置为待机使用状态
@export var 离开时设置待机使用: bool = true

## ===== 生命周期 =====

func _ready() -> void:
	if not _has_game_data_manager():
		return
	if 进入时设置普通手机使用 and GameDataManager.手机 != null:
		GameDataManager.手机.进入普通手机使用状态()
	if 进入时设置普通时间流动 and GameDataManager.时间 != null:
		GameDataManager.时间.进入普通时间流动()

func _exit_tree() -> void:
	if not 离开时设置待机使用:
		return
	if not _has_game_data_manager():
		return
	if GameDataManager.手机 != null:
		GameDataManager.手机.进入待机使用状态()

## ===== 私有方法 =====

func _has_game_data_manager() -> bool:
	return get_node_or_null("/root/GameDataManager") != null
