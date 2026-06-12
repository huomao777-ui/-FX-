## 描述: 开始界面主逻辑，自动为四个按钮绑定交互组件并处理点击信号
## 依赖: 根节点为 Control，子节点路径为 新的开始按钮 等
## 状态: 完成
## 最后更新：2026-05-29
extends Control

## ===== 导出变量 =====

## 拖入 Maps/Maps_0/node_2d.tscn 文件，点击"新的开始"时自动加载
@export var 新游戏场景: PackedScene

## ===== 节点引用 =====

## 按钮路径：根节点下的四个平行四边形按钮 Area2D
@onready var _新的开始按钮: Area2D = $新的开始按钮
@onready var _继续游戏按钮: Area2D = $继续游戏按钮
@onready var _修改设置按钮: Area2D = $修改设置按钮
@onready var _退出按钮: Area2D = $退出按钮

const UIButtonScript = preload("res://界面/组件/UIButton.gd")

## ===== 生命周期方法 =====

func _ready() -> void:
	_为按钮添加交互(_新的开始按钮)
	_为按钮添加交互(_继续游戏按钮)
	_为按钮添加交互(_修改设置按钮)
	_为按钮添加交互(_退出按钮)

	# 将"新的开始按钮"的点击切换到新游戏跳转逻辑
	_重新连接新游戏按钮()

## ===== 私有方法 =====

## 为指定 Area2D 按钮添加 UIButton 交互组件，并连接点击信号
func _为按钮添加交互(button: Area2D) -> void:
	if not is_instance_valid(button):
		return

	# 创建 UIButton 节点作为子节点
	var ui_button: Node = UIButtonScript.new()
	ui_button.name = "UIButton"
	button.add_child(ui_button)

	# 连接点击信号（断开已有连接防止重复）
	if ui_button.按钮被点击.is_connected(_on_any_button_clicked):
		ui_button.按钮被点击.disconnect(_on_any_button_clicked)
	ui_button.按钮被点击.connect(_on_any_button_clicked)

## 将"新的开始按钮"的信号从通用处理切换到专用处理
func _重新连接新游戏按钮() -> void:
	if not is_instance_valid(_新的开始按钮):
		return

	var ui_button: Node = _新的开始按钮.get_node_or_null("UIButton")
	if ui_button == null:
		return

	if ui_button.按钮被点击.is_connected(_on_any_button_clicked):
		ui_button.按钮被点击.disconnect(_on_any_button_clicked)
	if ui_button.按钮被点击.is_connected(_on_新游戏_clicked):
		ui_button.按钮被点击.disconnect(_on_新游戏_clicked)
	ui_button.按钮被点击.connect(_on_新游戏_clicked)

## ===== 新游戏跳转逻辑（解耦入口） =====

## 实验功能：点击"新的开始"时加载地图并隐藏开始界面
## 后续改为正式逻辑时只需修改 _开始新游戏() 内部实现
func _on_新游戏_clicked(button_name: String) -> void:
	print("按钮被点击: 新的开始 → 实验跳转到地图")
	_开始新游戏()

## 新游戏流程的唯一入口，内部封装跳转逻辑
func _开始新游戏() -> void:
	if 新游戏场景 == null:
		push_warning("start_screen: 新游戏场景 未设置，请在检查器中拖入 Maps/Maps_0/node_2d.tscn")
		return

	# 实例化地图场景并挂到根节点
	var map_instance: Node = 新游戏场景.instantiate()
	get_tree().root.add_child(map_instance)

	# 隐藏开始界面，显示地图
	visible = false

## ===== 信号处理 =====

## 处理任意按钮点击事件，根据按钮名称分发
func _on_any_button_clicked(button_name: String) -> void:
	match button_name:
		"新的开始按钮":
			# 此按钮已被 _重新连接新游戏按钮() 接管，此处不会被执行
			print("按钮被点击: 新的开始")
		"继续游戏按钮":
			print("按钮被点击: 继续游戏")
		"修改设置按钮":
			print("按钮被点击: 修改设置")
		"退出按钮":
			print("按钮被点击: 退出")
		_:
			push_warning("start_screen: 未知按钮 ", button_name)
