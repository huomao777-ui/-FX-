## 描述: 挂在“wifi”或“流量”节点上，按子节点顺序控制信号格显隐。
extends Node

@export_group("节点")
## 留空时优先把当前节点当成信号根节点。
@export var 信号根节点路径: NodePath

@export_group("规则")
## 是否在初始化时按“1格信号、2格信号...”自动收集。
@export var 使用连续命名收集: bool = true
## 自动收集失败时，是否递归收集所有名为“X格信号”的节点。
@export var 自动递归补充收集: bool = true

var _signal_root: Node = null
var _bars: Array[CanvasItem] = []

func _ready() -> void:
	_cache_nodes()

func 更新信号显示(strength: int, is_visible: bool) -> void:
	if _signal_root != null:
		_signal_root.visible = is_visible
	if _bars.is_empty():
		return

	var clamped_strength: int = clampi(strength, 0, _bars.size())
	for i in range(_bars.size()):
		var bar: CanvasItem = _bars[i]
		if bar != null:
			bar.visible = i < clamped_strength

func _cache_nodes() -> void:
	if String(信号根节点路径) != "":
		_signal_root = get_node_or_null(信号根节点路径)
	elif String(name) == "wifi" or String(name) == "流量":
		_signal_root = self
	else:
		_signal_root = get_parent()
	if _signal_root == null:
		return

	_bars.clear()
	if 使用连续命名收集:
		_collect_named_bars()
	if _bars.is_empty() and 自动递归补充收集:
		_collect_recursive_bars(_signal_root)

func _collect_named_bars() -> void:
	var current: Node = _signal_root.get_node_or_null("1格信号")
	var index: int = 1
	while current != null:
		var bar: CanvasItem = current as CanvasItem
		if bar != null:
			_bars.append(bar)
		index += 1
		current = current.get_node_or_null("%d格信号" % index)

func _collect_recursive_bars(root: Node) -> void:
	for child in root.get_children():
		var child_node: Node = child as Node
		if child_node == null:
			continue
		if String(child_node.name).contains("格信号"):
			var bar: CanvasItem = child_node as CanvasItem
			if bar != null:
				_bars.append(bar)
		_collect_recursive_bars(child_node)
