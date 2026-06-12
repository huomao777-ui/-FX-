## 描述: 通用按钮交互组件，处理悬停/按下变色、点击冷却和鼠标指针切换
## 依赖: 父节点必须是 Area2D，且包含名为"按钮浮层"的 Polygon2D 子节点
## 状态: 完成
## 最后更新：2026-05-23
extends Node

## ===== 信号 =====

signal 按钮被点击(按钮名称: String)

## ===== 导出变量 =====

## 鼠标悬停时浮层的颜色
@export var 悬停颜色: Color = Color(1, 1, 1, 0.08)
## 鼠标按下时浮层的颜色
@export var 按下颜色: Color = Color(1, 1, 1, 0.18)
## 颜色过渡平滑速度（越大越快）
@export var 颜色过渡速度: float = 8.0
## 两次点击之间的最小间隔（秒）
@export var 冷却时间: float = 0.3

## ===== 节点引用 =====

## 通过 ../按钮浮层 获取父节点(Area2D)下的 Polygon2D 节点
@onready var 按钮浮层: Polygon2D = $"../按钮浮层"
@onready var _parent_area: Area2D = $".."

## ===== 私有变量 =====

var _目标颜色: Color = Color(1, 1, 1, 0)
var _是否悬停: bool = false
var _是否按下: bool = false
var _冷却剩余: float = 0.0

## ===== 生命周期方法 =====

func _ready() -> void:
	if 按钮浮层 == null:
		push_warning("UIButton: 未找到父节点的 Polygon2D 节点 '按钮浮层'，按钮交互将无法工作")
		return
	if _parent_area == null:
		push_warning("UIButton: 父节点不是 Area2D，按钮交互将无法工作")
		return

	# 确保浮层可见以接收颜色变化
	按钮浮层.visible = true

	# 连接 Area2D 的鼠标事件信号
	_parent_area.mouse_entered.connect(_on_mouse_entered)
	_parent_area.mouse_exited.connect(_on_mouse_exited)
	_parent_area.input_event.connect(_on_input_event)

	# 确保 Area2D 可接收输入
	_parent_area.input_pickable = true

func _process(delta: float) -> void:
	if 按钮浮层 == null:
		return

	# 冷却倒计时
	if _冷却剩余 > 0:
		_冷却剩余 -= delta

	# 平滑颜色过渡
	按钮浮层.color = 按钮浮层.color.lerp(_目标颜色, 颜色过渡速度 * delta)

## ===== 私有方法：信号处理 =====

func _on_mouse_entered() -> void:
	_是否悬停 = true
	_目标颜色 = 按下颜色 if _是否按下 else 悬停颜色
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_mouse_exited() -> void:
	_是否悬停 = false
	_是否按下 = false
	_目标颜色 = Color(1, 1, 1, 0)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if 按钮浮层 == null:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_是否按下 = true
				_目标颜色 = 按下颜色
			else:
				_是否按下 = false
				_目标颜色 = 悬停颜色 if _是否悬停 else Color(1, 1, 1, 0)
				_尝试触发点击()

## ===== 私有方法：点击逻辑 =====

func _尝试触发点击() -> void:
	if _冷却剩余 > 0:
		return
	_冷却剩余 = 冷却时间
	按钮被点击.emit(_parent_area.name)