## 描述: 角落手机入口控制器，负责息屏/唤醒状态切换、悬停唤醒和双击锁屏
## 依赖: 子节点 手机息屏状态、手机唤醒状态
## 状态: 初版
## 最后更新：2026-06-12
extends Control

## ===== 导出配置变量 =====

@export_group("悬停唤醒")
## 鼠标悬停超过该时间后亮屏
@export var 悬停唤醒时间: float = 0.65
## 鼠标离开后延迟息屏时间
@export var 离开后息屏延迟: float = 1.2
## 进入场景时是否默认息屏
@export var 初始是否息屏: bool = true
## 是否启用悬停唤醒
@export var 启用悬停唤醒: bool = true
## 是否启用双击亮屏/息屏
@export var 启用双击切换: bool = true

@export_group("检测范围")
## 检测范围额外扩张像素，方便玩家不必精准悬停在手机贴图上
@export var 悬停检测扩张: float = 18.0

@export_group("息屏显示")
## 息屏时状态栏透明度，避免 CanvasLayer 状态栏独立发亮
@export_range(0.0, 1.0, 0.01) var 息屏状态栏透明度: float = 0.18

## ===== 节点引用 =====

@onready var _screen_off: Sprite2D = $手机息屏状态
@onready var _screen_on: Sprite2D = $手机唤醒状态
@onready var _status_layer: CanvasLayer = get_node_or_null("手机唤醒状态/电量") as CanvasLayer
@onready var _battery_bar: ProgressBar = get_node_or_null("手机唤醒状态/电量/电池") as ProgressBar

## ===== 内部变量 =====

var _is_awake: bool = false
var _hover_timer: float = 0.0
var _leave_timer: float = 0.0

## ===== 生命周期 =====

func _ready() -> void:
	_set_awake(not 初始是否息屏)

func _process(delta: float) -> void:
	if not 启用悬停唤醒:
		return
	_update_hover_wake(delta)

func _input(event: InputEvent) -> void:
	if not 启用双击切换:
		return
	if not event is InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not mouse_event.double_click:
		return

	if _is_mouse_over_phone():
		_set_awake(true)
	else:
		_set_awake(false)

## ===== 公共接口 =====

func 唤醒手机() -> void:
	_set_awake(true)

func 息屏手机() -> void:
	_set_awake(false)

func 是否唤醒() -> bool:
	return _is_awake

## ===== 私有方法 =====

func _update_hover_wake(delta: float) -> void:
	var hovering: bool = _is_mouse_over_phone()

	if hovering:
		_leave_timer = 0.0
		_hover_timer += delta
		if not _is_awake and _hover_timer >= 悬停唤醒时间:
			_set_awake(true)
		return

	_hover_timer = 0.0
	if _is_awake:
		_leave_timer += delta
		if _leave_timer >= 离开后息屏延迟:
			_set_awake(false)

func _set_awake(value: bool) -> void:
	var changed: bool = _is_awake != value
	_is_awake = value
	if _screen_off != null:
		_screen_off.visible = not _is_awake
	if _screen_on != null:
		_screen_on.visible = _is_awake
	_update_screen_off_status_visibility()

	if changed and _has_game_data_manager() and GameDataManager.手机 != null:
		if _is_awake:
			GameDataManager.手机.进入普通手机使用状态()
		else:
			GameDataManager.手机.进入待机使用状态()

func _update_screen_off_status_visibility() -> void:
	# CanvasLayer 有可能独立于父节点显示，这里显式处理，避免息屏后电量仍然亮着。
	if _status_layer != null:
		_status_layer.visible = true
	if _battery_bar != null:
		_battery_bar.modulate = Color.WHITE if _is_awake else Color(1.0, 1.0, 1.0, 息屏状态栏透明度)

func _is_mouse_over_phone() -> bool:
	var target: Sprite2D = _screen_on if _is_awake else _screen_off
	if target == null or target.texture == null:
		return false

	var rect: Rect2 = _get_sprite_global_rect(target)
	return rect.has_point(get_global_mouse_position())

func _get_sprite_global_rect(sprite: Sprite2D) -> Rect2:
	var texture_size: Vector2 = sprite.texture.get_size()
	var scaled_size: Vector2 = Vector2(
		texture_size.x * absf(sprite.global_scale.x),
		texture_size.y * absf(sprite.global_scale.y)
	)
	var top_left: Vector2 = sprite.global_position - scaled_size * 0.5
	var rect: Rect2 = Rect2(top_left, scaled_size)
	return rect.grow(悬停检测扩张)

func _has_game_data_manager() -> bool:
	return get_node_or_null("/root/GameDataManager") != null
