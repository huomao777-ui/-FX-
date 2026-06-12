## 描述: 全局游戏数据管理器，所有子系统的容器和初始化入口
## 依赖: 子节点 StaminaSystem、StressSystem、AssetSystem、HealthSystem、MentalSystem、TimeSystem、PhoneSystem
## 状态: 完成
## 最后更新：2026-06-12
extends Node

## ===== 节点引用 =====

## 引用子节点：体力系统
@onready var 体力: StaminaSystem = $StaminaSystem
## 引用子节点：压力系统
@onready var 压力: StressSystem = $StressSystem
## 引用子节点：资产系统
@onready var 资产: AssetSystem = $AssetSystem
## 引用子节点：健康系统
@onready var 健康: HealthSystem = $HealthSystem
## 引用子节点：精神系统
@onready var 精神: MentalSystem = $MentalSystem
## 引用子节点：时间系统
@onready var 时间: TimeSystem = $TimeSystem
## 引用子节点：手机系统
@onready var 手机: PhoneSystem = $PhoneSystem

## ===== 生命周期 =====

func _ready() -> void:
	_验证子系统()
	_连接子系统信号()

## ===== 私有方法 =====

func _验证子系统() -> void:
	if 体力 == null:
		push_warning("GameDataManager: 缺少 StaminaSystem 子节点")
	if 压力 == null:
		push_warning("GameDataManager: 缺少 StressSystem 子节点")
	if 资产 == null:
		push_warning("GameDataManager: 缺少 AssetSystem 子节点")
	if 健康 == null:
		push_warning("GameDataManager: 缺少 HealthSystem 子节点")
	if 精神 == null:
		push_warning("GameDataManager: 缺少 MentalSystem 子节点")
	if 时间 == null:
		push_warning("GameDataManager: 缺少 TimeSystem 子节点")
	if 手机 == null:
		push_warning("GameDataManager: 缺少 PhoneSystem 子节点")

func _连接子系统信号() -> void:
	if 时间 == null or 手机 == null:
		return
	if not 时间.回合推进.is_connected(_on_时间_回合推进):
		时间.回合推进.connect(_on_时间_回合推进)

func _on_时间_回合推进(_总回合: int, _时段索引: int, _时段名称: String) -> void:
	手机.处理回合耗电()

## ===== 配置加载接口（预留） =====

## 预留：将来从 JSON 文件加载配置后，通过此函数更新各系统的初始值
func 加载初始配置(_data: Dictionary = {}) -> void:
	pass

## 预留：收集所有子系统当前数据，供存档使用
func 收集存档数据() -> Dictionary:
	var data: Dictionary = {
		体力 = _序列化子系统(体力),
		压力 = _序列化子系统(压力),
		资产 = _序列化资产(),
		健康 = _序列化子系统(健康),
		精神 = _序列化子系统(精神),
		时间 = 时间.收集存档数据() if 时间 != null else {},
		手机 = 手机.收集存档数据() if 手机 != null else {}
	}
	return data

## 预留：从存档数据恢复所有子系统状态
func 恢复存档数据(data: Dictionary) -> void:
	if data.is_empty():
		return
	if 时间 != null and data.has("时间"):
		时间.恢复存档数据(data["时间"])
	if 手机 != null and data.has("手机"):
		手机.恢复存档数据(data["手机"])

## ===== 工具函数 =====

func _序列化子系统(system: Node) -> Dictionary:
	return {
		"current": system.get_value(),
		"max": system.get_max_value(),
		"min": system.get_min_value()
	}

func _序列化资产() -> Dictionary:
	return {
		"current": 资产.get_value(),
		"max": 资产.get_max_value(),
		"cash": 资产.get_value(),
		"total_assets": 资产.get_max_value()
	}
