## 描述: 挂在“电量”节点上的占位脚本。
## 设计原则:
## - 当前不参与任何电池显示
## - 不直接修改 ProgressBar
## - 不直接修改数字、端点、颜色与进度
extends Node

signal 电量状态已更新(电量值: int, 是否低电量: bool, 是否充电: bool)

@export_group("运行时接线")
## 若“电池”节点未挂接收脚本，则在运行时自动挂上。
@export var 自动挂载电池接收脚本: bool = true
## 运行时自动挂载到“电池”节点的脚本路径。
@export var 电池接收脚本路径: String = "res://沙盒/测试/手机电池进度条接收器.gd"

var _battery_bar: ProgressBar = null

func _ready() -> void:
	_cache_nodes()
	_ensure_receiver_script()

func 更新电量显示(value: int, is_low: bool, is_charging: bool) -> void:
	电量状态已更新.emit(value, is_low, is_charging)

func _cache_nodes() -> void:
	var battery_node: Node = null
	if String(name) == "电量":
		battery_node = get_node_or_null("电池")
	elif get_parent() != null:
		battery_node = get_parent().get_node_or_null("电池")
	_battery_bar = battery_node as ProgressBar

func _ensure_receiver_script() -> void:
	if not 自动挂载电池接收脚本:
		return
	if _battery_bar == null:
		return
	if _battery_bar.has_method("_on_battery_state_updated"):
		return
	if 电池接收脚本路径 == "":
		return

	var receiver_script: Script = load(电池接收脚本路径) as Script
	if receiver_script == null:
		push_warning("手机电量显示: 无法加载电池接收脚本 %s" % 电池接收脚本路径)
		return

	_battery_bar.set_script(receiver_script)
	if _battery_bar.has_method("初始化接收器"):
		_battery_bar.call("初始化接收器")
