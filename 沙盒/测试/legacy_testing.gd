## 描述: 调试测试模块，通过按钮增删体力和压力，验证 GameData → UI 联动
## 依赖: 父节点为 Control（Testing），子节点为四个 Button
## 状态: 完成
## 最后更新：2026-06-02
extends Control

## ===== 导出变量（检查器可调） =====

## 每次点击"加体力"或"扣体力"的变动量
@export var 体力变动量: float = 20.0
## 每次点击"加压力"或"扣压力"的变动量
@export var 压力变动量: float = 30.0

## ===== 节点引用 =====

@onready var _加体力按钮: Button = $加体力
@onready var _扣体力按钮: Button = $扣体力
@onready var _加压力按钮: Button = $加压力
@onready var _扣压力按钮: Button = $扣压力

## ===== 生命周期 =====

func _ready() -> void:
	_连接按钮()

## ===== 私有方法 =====

func _连接按钮() -> void:
	if _加体力按钮 == null or _扣体力按钮 == null or _加压力按钮 == null or _扣压力按钮 == null:
		push_warning("Testing: 按钮子节点不完整，请检查 Testing 场景结构")
		return

	_加体力按钮.pressed.connect(_on_加体力_pressed)
	_扣体力按钮.pressed.connect(_on_扣体力_pressed)
	_加压力按钮.pressed.connect(_on_加压力_pressed)
	_扣压力按钮.pressed.connect(_on_扣压力_pressed)

## ===== 按钮事件 =====

func _on_加体力_pressed() -> void:
	if 体力变动量 <= 0:
		return
	GameDataManager.体力.恢复体力(体力变动量)
	print("Testing: 增加体力 ", 体力变动量, " → 当前 ", GameDataManager.体力.get_value())

func _on_扣体力_pressed() -> void:
	if 体力变动量 <= 0:
		return
	GameDataManager.体力.消耗体力(体力变动量)
	print("Testing: 扣除体力 ", 体力变动量, " → 当前 ", GameDataManager.体力.get_value())

func _on_加压力_pressed() -> void:
	if 压力变动量 <= 0:
		return
	GameDataManager.压力.增加压力(压力变动量)
	print("Testing: 增加压力 ", 压力变动量, " → 当前 ", GameDataManager.压力.get_value())

func _on_扣压力_pressed() -> void:
	if 压力变动量 <= 0:
		return
	GameDataManager.压力.减少压力(压力变动量)
	print("Testing: 扣除压力 ", 压力变动量, " → 当前 ", GameDataManager.压力.get_value())