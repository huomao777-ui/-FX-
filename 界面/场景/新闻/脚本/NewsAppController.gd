extends Control
class_name NewsAppController

@export var filter_bar_path: NodePath = ^"大背景/底部按钮层"


func _ready() -> void:
	_initialize_page_state()


func 执行APP内部回退() -> bool:
	var filter_bar: Node = _get_filter_bar_controller()
	if filter_bar != null and filter_bar.has_method("关闭全部筛选弹窗"):
		return bool(filter_bar.call("关闭全部筛选弹窗"))
	return false


func 获取筛选栏控制器() -> Node:
	return _get_filter_bar_controller()


func _initialize_page_state() -> void:
	# Reserve this controller as the page-level coordinator for future news flows.
	pass


func _get_filter_bar_controller() -> Node:
	return get_node_or_null(filter_bar_path)
