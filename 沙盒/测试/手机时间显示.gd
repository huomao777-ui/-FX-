## 描述: 挂在“时间”节点上，只负责更新时间文本，不负责查找全局系统。
extends Node

@export_group("节点")
## 留空时默认取当前节点的父节点下名为“时间”的节点。
@export var 时间文本节点路径: NodePath

@export_group("显示")
## 是否在支持 BBCode 的 RichTextLabel 上包一层粗体标签。
@export var 使用粗体标签: bool = false

var _time_label: RichTextLabel = null

func _ready() -> void:
	_cache_nodes()

func 更新时间显示(hour: int, minute: int) -> void:
	if _time_label == null:
		return

	var time_text: String = "%02d:%02d" % [hour, minute]
	if _time_label.bbcode_enabled and 使用粗体标签:
		_time_label.text = "[b]" + time_text
	else:
		_time_label.text = time_text

func _cache_nodes() -> void:
	var current_node: Node = self
	if String(时间文本节点路径) != "":
		_time_label = get_node_or_null(时间文本节点路径) as RichTextLabel
	elif current_node is RichTextLabel:
		_time_label = current_node as RichTextLabel
	else:
		_time_label = get_parent().get_node_or_null("时间") as RichTextLabel if get_parent() != null else null
