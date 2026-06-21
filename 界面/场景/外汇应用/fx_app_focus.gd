## 描述: 外汇应用专注状态绑定，进入场景后切换为盯盘耗电和汇率专注时间流动
## 依赖: GameDataManager.时间、GameDataManager.手机
## 状态: 初版
## 最后更新：2026-06-12
extends Control

const KLineChartLayerScript = preload("res://界面/场景/外汇应用/FxKLineChartLayer.gd")

@export var 默认显示货币代码: String = "YHB"

var _chart_layer: FxKLineChartLayer = null

## ===== 导出配置变量 =====

## 进入场景时是否自动进入汇率专注时间流动
@export var 进入时启用汇率专注时间: bool = true
## 进入场景时是否自动切换手机为盯盘使用状态
@export var 进入时启用盯盘耗电: bool = true
## 离开场景树时是否恢复普通手机时间流动
@export var 离开时恢复普通状态: bool = true

## ===== 生命周期 =====

func _ready() -> void:
	_setup_kline_chart()
	if not _has_game_data_manager():
		return
	if 进入时启用汇率专注时间 and GameDataManager.时间 != null:
		GameDataManager.时间.进入汇率专注时间流动()
	if 进入时启用盯盘耗电 and GameDataManager.手机 != null:
		GameDataManager.手机.进入汇率盯盘使用状态()

func _exit_tree() -> void:
	if not 离开时恢复普通状态:
		return
	if not _has_game_data_manager():
		return
	if GameDataManager.时间 != null:
		GameDataManager.时间.进入普通时间流动()
	if GameDataManager.手机 != null:
		GameDataManager.手机.进入普通手机使用状态()

## ===== 私有方法 =====

func _has_game_data_manager() -> bool:
	return get_node_or_null("/root/GameDataManager") != null

func _setup_kline_chart() -> void:
	var canvas: Control = _find_descendant_by_name(self, "k线图画布") as Control
	if canvas == null:
		push_warning("fx_app_focus: 未找到 k线图画布，无法初始化 K 线绘图层")
		return

	_chart_layer = KLineChartLayerScript.new() as FxKLineChartLayer
	_chart_layer.name = "KLineChartLayer"
	_chart_layer.默认货币代码 = 默认显示货币代码
	_chart_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_chart_layer)
	_chart_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chart_layer.offset_left = 0.0
	_chart_layer.offset_top = 0.0
	_chart_layer.offset_right = 0.0
	_chart_layer.offset_bottom = 0.0

	_connect_timeframe_button(canvas, "一分钟")
	_connect_timeframe_button(canvas, "一小时")
	_connect_timeframe_button(canvas, "一天")
	_connect_timeframe_button(canvas, "一周")
	_connect_timeframe_button(canvas, "一月")
	_connect_timeframe_button(canvas, "一年")
	_update_pair_label(canvas)

func _connect_timeframe_button(root: Node, button_name: String) -> void:
	var button: Button = _find_descendant_by_name(root, button_name) as Button
	if button == null:
		return
	var callback: Callable = _on_timeframe_button_pressed.bind(button_name)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

func _on_timeframe_button_pressed(button_name: String) -> void:
	if _chart_layer == null:
		return
	_chart_layer.设置周期(button_name)

func _update_pair_label(canvas: Node) -> void:
	for child in canvas.get_children():
		if child is Label:
			var label: Label = child as Label
			label.text = "RMB/" + 默认显示货币代码
			return

func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var result: Node = _find_descendant_by_name(child, target_name)
		if result != null:
			return result
	return null
