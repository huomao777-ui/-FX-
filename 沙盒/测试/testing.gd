## 描述: 调试测试模块，通过按钮增删体力、压力、现金、资产、健康、精神、时间，验证 GameData → UI 联动
## 依赖: 父节点为 Control（Testing），子节点为调试 Button
## 状态: 完成
## 最后更新：2026-06-12
extends Control

## ===== 导出变量（检查器可调） =====

## 每次点击"加体力"或"扣体力"的变动量
@export var 体力变动量: float = 20.0
## 每次点击"加压力"或"扣压力"的变动量
@export var 压力变动量: float = 30.0
## 每次点击"加现金"或"扣现金"的变动量
@export var 现金变动量: float = 1000.0
## 每次点击"加资产"或"扣资产"的变动量
@export var 资产变动量: float = 1000.0
## 每次点击"加健康"或"扣健康"的变动量
@export var 健康变动量: float = 10.0
## 每次点击"加精神"或"扣精神"的变动量
@export var 精神变动量: float = 10.0
## 每次点击"前进时间"或"后退时间"的变动回合数
@export var 时间变动回合数: int = 1

## ===== 节点引用 =====

@onready var _加体力按钮: Button = $加体力
@onready var _扣体力按钮: Button = $扣体力
@onready var _加压力按钮: Button = $加压力
@onready var _扣压力按钮: Button = $扣压力
@onready var _加现金按钮: Button = $加现金
@onready var _扣现金按钮: Button = $扣现金
@onready var _加资产按钮: Button = $加资产
@onready var _扣资产按钮: Button = $扣资产
@onready var _加健康按钮: Button = $加健康
@onready var _扣健康按钮: Button = $扣健康
@onready var _加精神按钮: Button = $加精神
@onready var _扣精神按钮: Button = $扣精神
@onready var _前进时间按钮: Button = get_node_or_null("前进时间") as Button
@onready var _后退时间按钮: Button = get_node_or_null("后退时间") as Button

## ===== 生命周期 =====

func _ready() -> void:
	_连接按钮()

## ===== 私有方法 =====

func _连接按钮() -> void:
	if _加体力按钮 == null or _扣体力按钮 == null or _加压力按钮 == null or _扣压力按钮 == null:
		push_warning("Testing: 体力/压力按钮子节点不完整，请检查 Testing 场景结构")
		return
	if _加现金按钮 == null or _扣现金按钮 == null or _加资产按钮 == null or _扣资产按钮 == null:
		push_warning("Testing: 现金/资产按钮子节点不完整，请检查 Testing 场景结构")
		return
	if _加健康按钮 == null or _扣健康按钮 == null:
		push_warning("Testing: 健康按钮子节点不完整，请检查 Testing 场景结构")
		return
	if _加精神按钮 == null or _扣精神按钮 == null:
		push_warning("Testing: 精神按钮子节点不完整，请检查 Testing 场景结构")
		return
	if _前进时间按钮 == null or _后退时间按钮 == null:
		push_warning("Testing: 时间按钮子节点不完整，请检查是否存在 前进时间 / 后退时间")

	_加体力按钮.pressed.connect(_on_加体力_pressed)
	_扣体力按钮.pressed.connect(_on_扣体力_pressed)
	_加压力按钮.pressed.connect(_on_加压力_pressed)
	_扣压力按钮.pressed.connect(_on_扣压力_pressed)
	_加现金按钮.pressed.connect(_on_加现金_pressed)
	_扣现金按钮.pressed.connect(_on_扣现金_pressed)
	_加资产按钮.pressed.connect(_on_加资产_pressed)
	_扣资产按钮.pressed.connect(_on_扣资产_pressed)
	_加健康按钮.pressed.connect(_on_加健康_pressed)
	_扣健康按钮.pressed.connect(_on_扣健康_pressed)
	_加精神按钮.pressed.connect(_on_加精神_pressed)
	_扣精神按钮.pressed.connect(_on_扣精神_pressed)

	if _前进时间按钮 != null:
		_前进时间按钮.pressed.connect(_on_前进时间_pressed)
	if _后退时间按钮 != null:
		_后退时间按钮.pressed.connect(_on_后退时间_pressed)

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

## ===== 现金按钮事件 =====

func _on_加现金_pressed() -> void:
	if 现金变动量 <= 0:
		return
	GameDataManager.资产.增加现金(现金变动量)
	print("Testing: 增加现金 ", 现金变动量, " → 当前 ", GameDataManager.资产.get_value())

func _on_扣现金_pressed() -> void:
	if 现金变动量 <= 0:
		return
	GameDataManager.资产.扣除现金(现金变动量)
	print("Testing: 扣除现金 ", 现金变动量, " → 当前 ", GameDataManager.资产.get_value())

## ===== 资产按钮事件 =====

func _on_加资产_pressed() -> void:
	if 资产变动量 <= 0:
		return
	var current: float = GameDataManager.资产.get_max_value()
	GameDataManager.资产.更新总资产(current + 资产变动量)
	print("Testing: 增加资产 ", 资产变动量, " → 当前 ", GameDataManager.资产.get_max_value())

func _on_扣资产_pressed() -> void:
	if 资产变动量 <= 0:
		return
	var current: float = GameDataManager.资产.get_max_value()
	GameDataManager.资产.更新总资产(max(current - 资产变动量, 0.0))
	print("Testing: 扣除资产 ", 资产变动量, " → 当前 ", GameDataManager.资产.get_max_value())

## ===== 健康按钮事件 =====

func _on_加健康_pressed() -> void:
	if 健康变动量 <= 0:
		return
	GameDataManager.健康.恢复健康(健康变动量)
	print("Testing: 增加健康 ", 健康变动量, " → 当前 ", GameDataManager.健康.get_value())

func _on_扣健康_pressed() -> void:
	if 健康变动量 <= 0:
		return
	GameDataManager.健康.降低健康(健康变动量)
	print("Testing: 扣除健康 ", 健康变动量, " → 当前 ", GameDataManager.健康.get_value())

## ===== 精神按钮事件 =====

func _on_加精神_pressed() -> void:
	if 精神变动量 <= 0:
		return
	GameDataManager.精神.增加精神(精神变动量)
	print("Testing: 增加精神 ", 精神变动量, " → 当前 ", GameDataManager.精神.get_value())

func _on_扣精神_pressed() -> void:
	if 精神变动量 <= 0:
		return
	GameDataManager.精神.降低精神(精神变动量)
	print("Testing: 扣除精神 ", 精神变动量, " → 当前 ", GameDataManager.精神.get_value())

## ===== 时间按钮事件 =====

func _on_前进时间_pressed() -> void:
	if 时间变动回合数 <= 0:
		return
	if GameDataManager.时间 == null:
		push_warning("Testing: 缺少 TimeSystem，无法前进时间")
		return
	GameDataManager.时间.调试变动回合(时间变动回合数)
	print("Testing: 前进时间 ", 时间变动回合数, " 回合 → 当前 ", GameDataManager.时间.获取时间文本())

func _on_后退时间_pressed() -> void:
	if 时间变动回合数 <= 0:
		return
	if GameDataManager.时间 == null:
		push_warning("Testing: 缺少 TimeSystem，无法后退时间")
		return
	GameDataManager.时间.调试变动回合(-时间变动回合数)
	print("Testing: 后退时间 ", 时间变动回合数, " 回合 → 当前 ", GameDataManager.时间.获取时间文本())
