## 描述: 用代码动态绘制 WiFi 信号弧形图标（3 格）
## 依赖: 挂载在 wifi信号 (Node2D) 节点上
## 状态: 完成
## 最后更新：2026-06-08
extends Node2D

## ===== 导出变量 =====

## 信号格数（0-3），控制亮几格；0=全暗，3=全亮
@export_range(0, 3, 1) var 信号格数: int = 3:
	set(value):
		信号格数 = clampi(value, 0, 3)
		queue_redraw()

## ===== 内部常量 =====

## 亮格颜色：纯白
const _亮色: Color = Color(1, 1, 1, 1)
## 暗格颜色：深灰 #3A3A3A
const _暗色: Color = Color(0.227, 0.227, 0.227, 1)

## 三格信号对应的半径（px），从内到外
const _半径数组: Array[float] = [8.0, 14.0, 20.0]
## 圆弧线宽（px）
const _线宽: float = 3.0

## 圆弧起始角度（度）：左上 225°
const _起始角度: float = 225.0
## 圆弧扫过角度（度）：从 225° 到 315°，共 90°
const _扫过角度: float = 90.0

## ===== 生命周期 =====

func _ready() -> void:
	# 初始绘制一次
	queue_redraw()

## ===== 绘制逻辑 =====

## 用 draw_arc() 绘制三道同心圆弧，缺口朝下，模拟 WiFi 信号格
func _draw() -> void:
	# 将度数转换为弧度
	var start_rad: float = deg_to_rad(_起始角度)
	# draw_arc 的 end_angle 参数接收的是"开始角度 + 扫过角度"的最终角度（弧度）
	var end_rad: float = deg_to_rad(_起始角度 + _扫过角度)

	# 依次绘制三格：索引 i 对应第 (i+1) 格
	for i in _半径数组.size():
		var radius: float = _半径数组[i]
		# 索引小于 信号格数 则为亮格，否则为暗格
		var color: Color = _亮色 if i < 信号格数 else _暗色
		draw_arc(Vector2.ZERO, radius, start_rad, end_rad, 32, color, _线宽, true)
