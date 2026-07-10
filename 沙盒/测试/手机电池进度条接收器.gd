## 描述: 挂在“电池”ProgressBar 上，接收外层“电量”节点发出的状态信号。
## 设计原则:
## - 只控制当前 ProgressBar 的 value
## - 只同步数字文本
## - 颜色只作用于当前 ProgressBar 的 fill 填充层
## - 不修改端点、边框等其他视觉样式
extends ProgressBar

@export_group("节点")
## 数字节点路径；留空时默认查找子节点“数字”。
@export var 数字节点路径: NodePath

@export_group("电量颜色")
## 低于该电量值时，填充切换为低电量颜色。
@export_range(0, 100, 1) var 低电量阈值: int = 20
## 低电量时的填充基准颜色，透明度会自动沿用当前 fill 的透明度。
@export var 低电量填充颜色: Color = Color(1.0, 0.08, 0.08, 1.0)
## 充电时的填充基准颜色，透明度会自动沿用当前 fill 的透明度。
@export var 充电填充颜色: Color = Color(0.1, 0.9, 0.25, 1.0)

var _number_label: Label = null
var _fill_style: StyleBoxFlat = null
var _normal_fill_color: Color = Color(1.0, 1.0, 1.0, 1.0)

func _ready() -> void:
	初始化接收器()

func 初始化接收器() -> void:
	_cache_nodes()
	_prepare_fill_style()
	_connect_battery_signal()

func _cache_nodes() -> void:
	if String(数字节点路径) != "":
		_number_label = get_node_or_null(数字节点路径) as Label
	else:
		_number_label = get_node_or_null("数字") as Label

func _prepare_fill_style() -> void:
	var fill_style: StyleBox = get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		_fill_style = (fill_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		_normal_fill_color = _fill_style.bg_color
		add_theme_stylebox_override("fill", _fill_style)

func _connect_battery_signal() -> void:
	var battery_container: Node = get_parent()
	if battery_container == null:
		return
	if not battery_container.has_signal("电量状态已更新"):
		return

	var callback: Callable = Callable(self, "_on_battery_state_updated")
	if not battery_container.is_connected("电量状态已更新", callback):
		battery_container.connect("电量状态已更新", callback)

func _on_battery_state_updated(battery_value: int, _is_low: bool, is_charging: bool) -> void:
	var clamped_battery_value: int = clampi(battery_value, 0, 100)
	max_value = 100
	value = clamped_battery_value
	if _number_label != null:
		_number_label.text = str(clamped_battery_value)
	_apply_fill_color(clamped_battery_value, is_charging)

func _apply_fill_color(battery_value: int, is_charging: bool) -> void:
	if _fill_style == null:
		return

	var target_color: Color = _normal_fill_color
	if is_charging:
		target_color = _with_fill_alpha(充电填充颜色)
	elif battery_value < 低电量阈值:
		target_color = _with_fill_alpha(低电量填充颜色)

	_fill_style.bg_color = target_color

func _with_fill_alpha(base_color: Color) -> Color:
	return Color(base_color.r, base_color.g, base_color.b, _normal_fill_color.a)
