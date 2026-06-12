## 描述: 根据健康值动态切换显示对应的健康状态小人
## 依赖: 挂载在 健康值 (Node2D) 上，子节点为五个 Sprite2D（强健的/健康的/还行的/疲惫的/燃尽的）
## 状态: 完成
## 最后更新：2026-06-03
extends Node2D

## ===== 节点引用 =====

@onready var _强健的: Sprite2D = $强健的
@onready var _健康的: Sprite2D = $健康的
@onready var _还行的: Sprite2D = $还行的
@onready var _疲惫的: Sprite2D = $疲惫的
@onready var _燃尽的: Sprite2D = $燃尽的

## ===== 生命周期 =====

func _ready() -> void:
	# 检查子节点是否完整
	if _强健的 == null or _健康的 == null or _还行的 == null or _疲惫的 == null or _燃尽的 == null:
		push_warning("HealthIcon: 子节点不完整，请检查 健康值 节点下的五个 Sprite2D")
		return

	# 检查 HealthSystem 是否可用
	if GameDataManager.健康 == null:
		push_warning("HealthIcon: GameDataManager.健康 不可用，默认显示 还行的")
		_switch_icon(40.0)
		return

	# 读取初始健康值并显示对应小人
	var initial_health: float = GameDataManager.健康.get_value()
	_switch_icon(initial_health)

	# 连接信号（is_connected 防止重复绑定）
	if not GameDataManager.健康.value_changed.is_connected(_on_健康变化):
		GameDataManager.健康.connect("value_changed", _on_健康变化)

## ===== 信号回调 =====

## 监听健康值变化，实时切换小人
func _on_健康变化(当前值: float, _最大值: float, _比例: float) -> void:
	_switch_icon(当前值)

## ===== 核心逻辑 =====

## 根据健康值切换显示对应小人，其余隐藏
## 区间划分：80-100 强健的 / 60-79 健康的 / 40-59 还行的 / 20-39 疲惫的 / 0-19 燃尽的
func _switch_icon(health: float) -> void:
	# 先隐藏全部五个节点，避免多个同时显示
	_hide_all()

	# clamp 确保数值在有效范围内，防止越界
	var clamped: float = clampf(health, 0.0, 100.0)

	# 从高到低逐级判断，边界值归属明确
	if clamped >= 80.0:
		_强健的.visible = true
	elif clamped >= 60.0:
		_健康的.visible = true
	elif clamped >= 40.0:
		_还行的.visible = true
	elif clamped >= 20.0:
		_疲惫的.visible = true
	else:
		_燃尽的.visible = true

## ===== 工具函数 =====

## 隐藏所有健康小人节点
func _hide_all() -> void:
	_强健的.visible = false
	_健康的.visible = false
	_还行的.visible = false
	_疲惫的.visible = false
	_燃尽的.visible = false