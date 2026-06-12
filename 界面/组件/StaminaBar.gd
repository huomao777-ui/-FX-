## 描述: 体力条控件，实现动态填充、多段变色、变化角度可配置
## 依赖: 父节点需包含名为"体力条填充"的 Polygon2D 子节点
## 状态: 完成
## 最后更新：2026-06-02
class_name StaminaBar
extends Node2D

## ===== 信号 =====

## 数值变化时发射，携带当前比例 0.0~1.0
signal value_changed(ratio: float)

## ===== 导出变量 =====

## 变色比例节点，升序排列，如 [0.3, 0.7, 1.0]
@export var 体力阈值: Array[float] = [0.3, 0.7, 1.0]
## 与阈值一一对应的颜色，长度需与阈值一致
@export var 体力颜色: Array[Color] = [Color(1, 0, 0), Color(1, 1, 0), Color(0, 1, 0)]
## 裁切方向角度（度），0=水平向左裁切（右侧被切掉），90=垂直向下裁切，180=水平向右，270=垂直向上
@export var 体力裁切角度: float = 0.0

## ===== 内部变量 =====

var _current_value: float = 100.0
var _max_value: float = 100.0
var _current_ratio: float = 1.0

var _original_polygon: PackedVector2Array = []
var _direction: Vector2 = Vector2.RIGHT

## ===== 节点引用 =====

## 子节点：体力条填充 (Polygon2D)
@onready var _填充: Polygon2D = $体力条填充

## ===== 生命周期 =====

func _ready() -> void:
	if _填充 == null:
		push_warning("StaminaBar: 未找到子节点 '体力条填充'（Polygon2D），体力条将无法工作")
		return

	# 保存初始多边形（满值形状）
	_original_polygon = _填充.polygon

	if _original_polygon.is_empty():
		push_warning("StaminaBar: '体力条填充' 的 polygon 为空，体力条将无法工作")
		return

	# 计算方向向量和基准投影
	_更新方向()

	# 初始化为满值
	set_ratio(1.0)

	# 连接 GameData 信号，自动响应体力变化
	if not GameDataManager.体力.is_connected("value_changed", _on_体力变化):
		GameDataManager.体力.connect("value_changed", _on_体力变化)

## ===== 公共接口 =====

## 直接设置百分比 0.0~1.0
func set_ratio(ratio: float) -> void:
	_current_ratio = clampf(ratio, 0.0, 1.0)
	_update_fill()
	_update_color()
	value_changed.emit(_current_ratio)

## 通过当前值和最大值设置（自动换算为百分比）
func set_value(current: float, max_val: float) -> void:
	_current_value = current
	_max_value = max(max_val, 0.01)
	set_ratio(_current_value / _max_value)

## 返回当前百分比 0.0~1.0
func get_ratio() -> float:
	return _current_ratio

## 返回当前体力值
func get_value() -> float:
	return _current_value

## 返回体力上限
func get_max_value() -> float:
	return _max_value

## ===== GameData 回调 =====

## 监听 GameData 体力变化信号，自动更新 UI
func _on_体力变化(当前值: float, 最大值: float, _比例: float) -> void:
	set_value(当前值, 最大值)

## ===== 核心填充逻辑 =====

## 沿裁切方向精确裁切体力条（Sutherland-Hodgman 多边形裁剪）
func _update_fill() -> void:
	if _填充 == null or _original_polygon.is_empty():
		return

	# 沿裁切方向找出投影范围
	var min_proj: float = _original_polygon[0].dot(_direction)
	var max_proj: float = min_proj
	for vertex in _original_polygon:
		var p: float = vertex.dot(_direction)
		if p < min_proj:
			min_proj = p
		if p > max_proj:
			max_proj = p

	# 裁切平面位置（从 max 端向 min 端推进）
	var cut_proj: float = min_proj + (max_proj - min_proj) * _current_ratio
	var count: int = _original_polygon.size()

	# Sutherland-Hodgman 多边形裁剪：用裁切平面对每条边做裁剪
	var input: PackedVector2Array = _original_polygon
	var output: PackedVector2Array = []

	for i in range(count):
		var current: Vector2 = input[i]
		var next: Vector2 = input[(i + 1) % count]
		var cur_proj: float = current.dot(_direction)
		var next_proj: float = next.dot(_direction)

		var cur_inside: bool = cur_proj <= cut_proj
		var next_inside: bool = next_proj <= cut_proj

		if cur_inside:
			output.append(current)

		if cur_inside != next_inside:
			# 边穿过了裁切平面 → 计算精确交点
			var t: float = (cut_proj - cur_proj) / (next_proj - cur_proj)
			var intersect: Vector2 = current + (next - current) * t
			output.append(intersect)

	_填充.polygon = output

## ===== 颜色计算 =====

## 根据当前比例从阈值数组中选取对应颜色（相邻区间线性插值）
func _update_color() -> void:
	if _填充 == null:
		return

	# 保护：数组为空时使用白色
	if 体力阈值.is_empty() or 体力颜色.is_empty():
		_填充.color = Color.WHITE
		return

	# 保护：数组长度不一致时使用白色
	var count: int = min(体力阈值.size(), 体力颜色.size())
	if count == 0:
		_填充.color = Color.WHITE
		return

	# 遍历阈值，找到当前比例所在的区间
	for i in range(count):
		if _current_ratio <= 体力阈值[i]:
			if i == 0:
				_填充.color = 体力颜色[0]
			else:
				# 在两段之间线性插值，实现平滑过渡
				var prev_t: float = 体力阈值[i - 1]
				var next_t: float = 体力阈值[i]
				var t: float = inverse_lerp(prev_t, next_t, _current_ratio)
				t = clampf(t, 0.0, 1.0)
				_填充.color = 体力颜色[i - 1].lerp(体力颜色[i], t)
			return

	# 超出最大阈值，使用最后一个颜色
	_填充.color = 体力颜色[count - 1]

## ===== 工具函数 =====

## 自动检测右边方向，计算裁切方向（右边垂线），体力裁切角度作为微调偏移
func _更新方向() -> void:
	if _original_polygon.is_empty():
		return

	# 找出 X 坐标最大的两个顶点 → 右边方向
	var best: Vector2 = _original_polygon[0]
	var second: Vector2 = _original_polygon[1]
	if second.x > best.x:
		var tmp: Vector2 = best
		best = second
		second = tmp
	for i in range(2, _original_polygon.size()):
		var v: Vector2 = _original_polygon[i]
		if v.x > best.x:
			second = best
			best = v
		elif v.x > second.x:
			second = v
	var right_edge: Vector2 = second - best

	# 基础裁切方向 = 右边方向的垂直方向（顺时针旋转 90°，指向固定端）
	var base_dir: Vector2 = Vector2(right_edge.y, -right_edge.x).normalized()

	# 体力裁切角度作为偏移叠加
	var offset_rad: float = deg_to_rad(体力裁切角度)
	var cos_a: float = cos(offset_rad)
	var sin_a: float = sin(offset_rad)
	_direction = Vector2(
		base_dir.x * cos_a - base_dir.y * sin_a,
		base_dir.x * sin_a + base_dir.y * cos_a
	)
