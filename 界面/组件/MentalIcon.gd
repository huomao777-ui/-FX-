## 描述: 根据精神状态值动态切换显示对应的头像差分立绘
## 依赖: 挂载在 头像差分 (Node2D) 上，子节点为五个 Sprite2D（窘迫/飘飘然/忘乎所以/崩溃慌乱/心如死灰）
## 状态: 完成
## 最后更新：2026-06-06
extends Node2D

## ===== 节点引用 =====

@onready var _窘迫: Sprite2D = $窘迫
@onready var _飘飘然: Sprite2D = $飘飘然
@onready var _忘乎所以: Sprite2D = $忘乎所以
@onready var _崩溃慌乱: Sprite2D = $崩溃慌乱
@onready var _心如死灰: Sprite2D = $心如死灰

## ===== 生命周期 =====

func _ready() -> void:
	# 检查子节点是否完整
	if _窘迫 == null or _飘飘然 == null or _忘乎所以 == null or _崩溃慌乱 == null or _心如死灰 == null:
		push_warning("MentalIcon: 子节点不完整，请检查 头像差分 节点下的五个 Sprite2D")
		return

	# 检查 MentalSystem 是否可用
	if GameDataManager.精神 == null:
		push_warning("MentalIcon: GameDataManager.精神 不可用，默认显示 窘迫")
		_switch_icon(50.0)
		return

	# 读取初始精神状态值并显示对应差分
	var initial_mental: float = GameDataManager.精神.get_value()
	_switch_icon(initial_mental)

	# 连接信号（is_connected 防止重复绑定）
	if not GameDataManager.精神.value_changed.is_connected(_on_精神变化):
		GameDataManager.精神.connect("value_changed", _on_精神变化)

## ===== 信号回调 =====

## 监听精神状态值变化，实时切换头像差分
func _on_精神变化(当前值: float, _最大值: float, _比例: float) -> void:
	_switch_icon(当前值)

## ===== 核心逻辑 =====

## 根据精神状态值切换显示对应头像差分，其余隐藏
## 区间划分：81-100 忘乎所以 / 61-80 飘飘然 / 41-60 窘迫 / 21-40 崩溃慌乱 / 1-20 心如死灰
func _switch_icon(mental: float) -> void:
	# 先隐藏全部五个节点，避免多个同时显示
	_hide_all()

	# clamp 确保数值在有效范围内，防止越界
	var clamped: float = clampf(mental, 1.0, 100.0)

	# 从高到低逐级判断，边界值归属明确
	if clamped >= 81.0:
		_忘乎所以.visible = true
	elif clamped >= 61.0:
		_飘飘然.visible = true
	elif clamped >= 41.0:
		_窘迫.visible = true
	elif clamped >= 21.0:
		_崩溃慌乱.visible = true
	else:
		_心如死灰.visible = true

## ===== 工具函数 =====

## 隐藏所有头像差分节点
func _hide_all() -> void:
	_窘迫.visible = false
	_飘飘然.visible = false
	_忘乎所以.visible = false
	_崩溃慌乱.visible = false
	_心如死灰.visible = false