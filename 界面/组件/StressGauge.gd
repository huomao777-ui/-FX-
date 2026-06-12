## 描述: 压力计控件，实现动态填充、多段变色、变化角度可配置，支持最小保留长度
## 依赖: 父节点需包含名为"压力条填充"的 Polygon2D 子节点
## 状态: 完成
## 最后更新：2026-06-02
class_name StressGauge
extends Node2D

## ===== 信号 =====

## 数值变化时发射，携带当前比例 0.0~1.0
signal value_changed(ratio: float)

## ===== 导出变量 =====

## 变色比例节点，升序排列，如 [0.4, 0.7, 1.0]
@export var 压力阈值: Array[float] = [0.4, 0.7, 1.0]
## 与阈值一一对应的颜色，长度需与阈值一致
@export var 压力颜色: Array[Color] = [Color(0, 1, 0), Color(1, 1, 0), Color(1, 0, 0)]
## 收缩方向角度（度），0=水平向右，90=垂直向下，270=垂直向上
@export var 压力变化角度: float = 270.0
## 压力值最小时条保留的显示比例（0.0~1.0），如 0.25 表示最低保留25%长度
@export var 压力最小比例: float = 0.25
## 对应最低显示比例的数值，如 75
@export var 压力最小数值: float = 75.0
## 对应满值（100%显示）的数值，如 300
@export var 压力最大数值: float = 300.0

## ===== 内部变量 =====

var _current_value: float = 75.0
var _max_value: float = 300.0
var _current_ratio: float = 0.25

var _original_polygon: PackedVector2Array = []
var _direction: Vector2 = Vector2.UP
var _min_projection: float = 0.0

## ===== 节点引用 =====

## 子节点：压力条填充 (Polygon2D)
@onready var _填充: Polygon2D = $压力条填充

## ===== 生命周期 =====

func _ready() -> void:
	if _填充 == null:
		push_warning("StressGauge: 未找到子节点 '压力条填充'（Polygon2D），压力计将无法工作")
		return

	# 保存初始多边形（满值形状）
	_original_polygon = _填充.polygon

	if _original_polygon.is_empty():
		push_warning("StressGauge: '压力条填充' 的 polygon 为空，压力计将无法工作")
		return

	# 计算方向向量和基准投影
	_更新方向()

	# 初始化为最小值对应的比例
	set_value(压力最小数值, 压力最大数值)

	# 连接 GameData 信号，自动响应压力变化
	if not GameDataManager.压力.is_connected("value_changed", _on_压力变化):
		GameDataManager.压力.connect("value_changed", _on_压力变化)

## ===== 公共接口 =====

## 直接设置百分比 0.0~1.0（不会自动应用最小比例，如需约束请用 set_value）
func set_ratio(ratio: float) -> void:
	_current_ratio = clampf(ratio, 0.0, 1.0)
	_update_fill()
	_update_color()
	value_changed.emit(_current_ratio)

## 通过当前值和最大值设置，自动将数值映射到可视范围（考虑最小保留长度）
func set_value(current: float, max_val: float) -> void:
	_current_value = current
	_max_value = max(max_val, 0.01)

	# 将数值钳制到配置范围内
	var clamped: float = clampf(current, 压力最小数值, 压力最大数值)
	# 在数值范围内计算进度 t (0.0~1.0)
	var value_range: float = max(压力最大数值 - 压力最小数值, 0.01)
	var t: float = (clamped - 压力最小数值) / value_range
	# 映射到可视比例
	var visual_ratio: float = 压力最小比例 + t * (1.0 - 压力最小比例)
	set_ratio(visual_ratio)

## 返回当前百分比 0.0~1.0
func get_ratio() -> float:
	return _current_ratio

## 返回当前压力值
func get_value() -> float:
	return _current_value

## 返回压力上限
func get_max_value() -> float:
	return _max_value

## ===== GameData 回调 =====

## 监听 GameData 压力变化信号，自动更新 UI
func _on_压力变化(当前值: float, 最大值: float, _比例: float) -> void:
	set_value(当前值, 最大值)

## ===== 核心填充逻辑 =====

## 根据当前比例裁切压力条：底部固定不动，顶部沿 Y 轴缩放
func _update_fill() -> void:
	if _填充 == null or _original_polygon.is_empty():
		return

	# 找出 Y 坐标最大值作为底部基准线
	var bottom_y: float = _original_polygon[0].y
	for vertex in _original_polygon:
		if vertex.y > bottom_y:
			bottom_y = vertex.y

	var new_polygon: PackedVector2Array = []
	for vertex in _original_polygon:
		if vertex.y >= bottom_y - 0.5:
			# 底部顶点完全不动
			new_polygon.append(vertex)
		else:
			# 顶部顶点沿 Y 轴缩向底部，X 坐标不变
			var new_y: float = bottom_y - (bottom_y - vertex.y) * _current_ratio
			# 取整消除锯齿
			new_polygon.append(Vector2(round(vertex.x), round(new_y)))

	_填充.polygon = new_polygon

## ===== 颜色计算 =====

## 根据当前比例从阈值数组中选取对应颜色（相邻区间线性插值）
func _update_color() -> void:
	if _填充 == null:
		return

	# 保护：数组为空时使用白色
	if 压力阈值.is_empty() or 压力颜色.is_empty():
		_填充.color = Color.WHITE
		return

	# 保护：数组长度不一致时使用白色
	var count: int = min(压力阈值.size(), 压力颜色.size())
	if count == 0:
		_填充.color = Color.WHITE
		return

	# 遍历阈值，找到当前比例所在的区间
	for i in range(count):
		if _current_ratio <= 压力阈值[i]:
			if i == 0:
				_填充.color = 压力颜色[0]
			else:
				# 在两段之间线性插值，实现平滑过渡
				var prev_t: float = 压力阈值[i - 1]
				var next_t: float = 压力阈值[i]
				var t: float = inverse_lerp(prev_t, next_t, _current_ratio)
				t = clampf(t, 0.0, 1.0)
				_填充.color = 压力颜色[i - 1].lerp(压力颜色[i], t)
			return

	# 超出最大阈值，使用最后一个颜色
	_填充.color = 压力颜色[count - 1]

## ===== 工具函数 =====

## 根据变化角度更新方向向量和基准投影
func _更新方向() -> void:
	var angle_rad: float = deg_to_rad(压力变化角度)
	_direction = Vector2(cos(angle_rad), sin(angle_rad))

	if _original_polygon.is_empty():
		return

	_min_projection = _original_polygon[0].dot(_direction)
	for i in range(1, _original_polygon.size()):
		var proj: float = _original_polygon[i].dot(_direction)
		if proj < _min_projection:
			_min_projection = proj
