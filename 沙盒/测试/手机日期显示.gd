## 描述: 挂在“日期”节点上，只负责更新日期文本。
extends Node

@export_group("节点")
## 留空时默认取当前节点的父节点下名为“日期”的节点。
@export var 日期文本节点路径: NodePath

var _date_label: Label = null

func _ready() -> void:
	_cache_nodes()

func 更新日期显示(date_text: String) -> void:
	if _date_label == null:
		return
	_date_label.text = date_text

func _cache_nodes() -> void:
	var current_node: Node = self
	if String(日期文本节点路径) != "":
		_date_label = get_node_or_null(日期文本节点路径) as Label
	elif current_node is Label:
		_date_label = current_node as Label
	else:
		_date_label = get_parent().get_node_or_null("日期") as Label if get_parent() != null else null
