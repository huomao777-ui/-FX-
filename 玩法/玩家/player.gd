## 描述: 玩家角色移动控制器
##  功能: 处理WASD/方向键输入、八方向移动、摄像机跟随、动画状态预留
##  依赖: 需要在场景中创建以下节点结构:
##    Player (CharacterBody2D)
##    ├── CollisionShape2D (矩形或圆形碰撞形状)
##    ├── Sprite2D (或 AnimatedSprite2D)
##    └── Camera2D (可选，用于摄像机跟随)
##  信号: 移动状态改变(是否行走中)、朝向改变(新朝向)
##  状态: idle(静止)、walking(行走)
class_name Player
extends CharacterBody2D

## ===== 导出配置变量 =====

## 移动参数
@export_group("移动参数")
## 最大移动速度（像素/秒）
@export var 最大移动速度: float = 200.0
## 地面加速度（数值越大起步越快）
@export var 地面加速度: float = 800.0
## 摩擦阻力（数值越大停止越快）
@export var 摩擦阻力: float = 1000.0
## 速度清零阈值（低于此速度时直接归零，避免微小滑动）
@export var 速度清零阈值: float = 1.0

## 手柄/输入设置
@export_group("手柄/输入设置")
## 手柄摇杆死区（小于此值的输入视为零，避免摇杆漂移）
@export var 摇杆死区: float = 0.15

## 输入映射
@export_group("输入映射")
## 向左移动的动作名称
@export var 向左动作: StringName = &"left"
## 向右移动的动作名称
@export var 向右动作: StringName = &"right"
## 向上移动的动作名称
@export var 向上动作: StringName = &"up"
## 向下移动的动作名称
@export var 向下动作: StringName = &"down"

## 摄像机跟随
@export_group("摄像机跟随")
## 是否启用摄像机跟随
@export var 启用摄像机跟随: bool = false
## 摄像机节点（拖入Camera2D）
@export var 摄像机: Camera2D = null
## 摄像机跟随平滑度（数值越大跟随越快）
@export var 摄像机平滑度: float = 5.0

## 动画配置
@export_group("动画配置")
## 动画播放器节点（拖入AnimationPlayer）
@export var 动画播放器: AnimationPlayer = null
## 精灵节点（拖入Sprite2D）
@export var 精灵节点: Sprite2D = null

## 阴影设置
@export_group("阴影设置")
## 是否启用动态阴影
@export var 启用阴影: bool = true
## 待机时阴影大小
@export var 阴影待机大小: Vector2 = Vector2(50, 16)
## 行走时阴影大小
@export var 阴影行走大小: Vector2 = Vector2(70, 22)
## 行走时阴影偏移距离（方向为移动反方向）
@export var 阴影行走偏移量: float = 20.0
## 阴影透明度（0.0 ~ 1.0）
@export var 阴影透明度: float = 0.25
## 阴影呼吸浮动速度
@export var 阴影浮动速度: float = 2.0
## 阴影呼吸浮动幅度（像素）
@export var 阴影浮动幅度: float = 1.5
## 阴影垂直偏移量（正值往下移，负值往上移）
@export var 阴影垂直偏移量: float = 0.0
## 阴影动画过渡平滑度
@export var 阴影平滑度: float = 8.0

## 模糊设置
@export_group("模糊设置")
## 角色边缘模糊强度（0 = 关闭，越大越模糊）
@export var 模糊强度: float = 1.5

## 透视修正
@export_group("透视修正")
## 是否启用透视缩放
@export var 启用透视修正: bool = true
## 透视缩放强度（Y位置每像素的缩放变化率）
@export var 透视缩放强度: float = 0.0005
## Y轴额外压缩比（< 1.0 产生俯瞰压扁效果）
@export var Y轴压缩比: float = 0.95

## 调试
@export_group("调试")
## 是否在控制台显示调试信息
@export var 显示调试信息: bool = false

## ===== 信号定义 =====

signal 移动状态改变(是否行走中: bool)
signal 朝向改变(新朝向: Vector2)

## ===== 状态枚举 =====

enum 移动状态 { IDLE, WALKING }

## ===== 公共变量 =====

## 最后朝向的方向（供状态机读取，默认朝下）
var last_facing_direction: Vector2 = Vector2.DOWN

## ===== 私有变量 =====

var _当前状态: 移动状态 = 移动状态.IDLE
var _上一帧是否行走中: bool = false
var _上一帧朝向: Vector2 = Vector2.ZERO
## 阴影呼吸浮动累计时间
var _阴影浮动时间: float = 0.0
## 精灵原始缩放（供透视修正叠加）
var _base_sprite_scale: Vector2 = Vector2.ONE

## ===== 节点引用 =====

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _state_machine: StateMachine = $StateMachine
@onready var 阴影: ColorRect = $阴影

## ===== 生命周期方法 =====

func _ready() -> void:
	_initialize_warnings()
	_state_machine.init(self)
	_initialize_visuals()

func _process(delta: float) -> void:
	_update_shadow(delta)
	_update_perspective()

func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = _获取输入方向()

	_处理移动(input_dir, delta)
	_state_machine.physics_update(input_dir, delta)
	_emit_state_signals()
	_handle_camera_follow(delta)

	if 显示调试信息:
		_输出调试信息()

## ===== 私有方法: 输入处理 =====

func _获取输入方向() -> Vector2:
	var input_dir: Vector2 = Input.get_vector(
		向左动作, 向右动作, 向上动作, 向下动作
	)
	input_dir = _应用摇杆死区(input_dir)
	return input_dir.normalized()

func _应用摇杆死区(dir: Vector2) -> Vector2:
	if absf(dir.x) < 摇杆死区:
		dir.x = 0.0
	if absf(dir.y) < 摇杆死区:
		dir.y = 0.0
	return dir

## ===== 私有方法: 移动物理 =====

func _处理移动(dir: Vector2, delta: float) -> void:
	if dir.length() > 0:
		velocity = velocity.move_toward(dir * 最大移动速度, 地面加速度 * delta)
		_当前状态 = 移动状态.WALKING
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 摩擦阻力 * delta)
		_当前状态 = 移动状态.IDLE

	_应用速度清零阈值()
	move_and_slide()

func _应用速度清零阈值() -> void:
	if velocity.length() < 速度清零阈值:
		velocity = Vector2.ZERO

## ===== 私有方法: 摄像机跟随 =====

func _handle_camera_follow(delta: float) -> void:
	if not 启用摄像机跟随 or 摄像机 == null:
		return
	摄像机.global_position = 摄像机.global_position.lerp(global_position, 摄像机平滑度 * delta)

## ===== 私有方法: 视觉初始化 =====

func _initialize_visuals() -> void:
	# 保存精灵原始缩放，供透视修正叠加
	if 精灵节点 != null:
		_base_sprite_scale = 精灵节点.scale

	# 加载并应用高斯模糊 Shader 到精灵
	var blur_shader: Shader = load("res://玩法/玩家/着色器/角色模糊.gdshader")
	if blur_shader != null and 精灵节点 != null:
		var blur_material := ShaderMaterial.new()
		blur_material.shader = blur_shader
		if 精灵节点.texture != null:
			var texture_size: Vector2 = 精灵节点.texture.get_size()
			blur_material.set_shader_parameter("纹理尺寸", texture_size)
		blur_material.set_shader_parameter("模糊强度", 模糊强度)
		精灵节点.material = blur_material
	elif 精灵节点 == null:
		push_warning("Player: 精灵节点为空，无法应用模糊材质")

	# 加载并应用阴影椭圆裁切 Shader
	var shadow_shader: Shader = load("res://玩法/玩家/着色器/阴影.gdshader")
	if shadow_shader != null and 阴影 != null:
		var shadow_material := ShaderMaterial.new()
		shadow_material.shader = shadow_shader
		阴影.material = shadow_material
		阴影.modulate = Color(0, 0, 0, 阴影透明度)

## ===== 私有方法: 阴影更新 =====

func _update_shadow(delta: float) -> void:
	if not 启用阴影 or 阴影 == null:
		return

	var is_walking: bool = _当前状态 == 移动状态.WALKING
	var target_size: Vector2
	var target_offset: Vector2

	if is_walking:
		# 行走时阴影放大并向移动反方向偏移
		target_size = 阴影行走大小
		var move_dir: Vector2 = last_facing_direction
		if move_dir != Vector2.ZERO:
			target_offset = -move_dir.normalized() * 阴影行走偏移量
	else:
		# 待机时阴影较小，紧贴脚下
		target_size = 阴影待机大小
		# 呼吸浮动
		_阴影浮动时间 += delta
		var float_offset := sin(_阴影浮动时间 * 阴影浮动速度) * 阴影浮动幅度
		target_offset = Vector2(0.0, float_offset + 阴影垂直偏移量)

	# 透视缩放因子影响阴影大小
	var perspective_scale: float = _get_perspective_scale()
	target_size *= perspective_scale

	# 平滑过渡
	阴影.size = 阴影.size.lerp(target_size, 阴影平滑度 * delta)
	阴影.position = 阴影.position.lerp(target_offset, 阴影平滑度 * delta)

## ===== 私有方法: 透视修正 =====

func _get_perspective_scale() -> float:
	var screen_height: float = get_viewport_rect().size.y
	if screen_height <= 0.0:
		return 1.0
	var mid_y: float = screen_height / 2.0
	var scale_factor: float = 1.0 + (mid_y - global_position.y) * 透视缩放强度
	scale_factor = clampf(scale_factor, 0.9, 1.1)
	return scale_factor

func _update_perspective() -> void:
	if not 启用透视修正 or 精灵节点 == null:
		return

	var scale_factor: float = _get_perspective_scale()
	精灵节点.scale.x = _base_sprite_scale.x * scale_factor
	精灵节点.scale.y = _base_sprite_scale.y * scale_factor * Y轴压缩比

## ===== 私有方法: 信号发射 =====

func _emit_state_signals() -> void:
	var is_walking: bool = _当前状态 != 移动状态.IDLE
	if is_walking != _上一帧是否行走中:
		_上一帧是否行走中 = is_walking
		移动状态改变.emit(is_walking)

	var current_dir: Vector2 = velocity.normalized() if velocity.length() > 0 else Vector2.ZERO
	if current_dir != _上一帧朝向 and current_dir.length() > 0:
		_上一帧朝向 = current_dir
		朝向改变.emit(current_dir)

## ===== 私有方法: 调试 =====

func _输出调试信息() -> void:
	var state_names: Dictionary = {
		移动状态.IDLE: "IDLE",
		移动状态.WALKING: "WALKING"
	}
	var debug_text: String = "速度: %.1f | 位置: %s | 状态: %s" % [
		velocity.length(),
		position,
		state_names.get(_当前状态, "UNKNOWN")
	]
	print_rich("[color=yellow][Player Debug][/color] ", debug_text)

func _initialize_warnings() -> void:
	if 精灵节点 == null:
		精灵节点 = $Sprite2D
		push_warning("Player: 未在Inspector中指定精灵节点，将自动尝试获取Sprite2D子节点")

	if 动画播放器 == null:
		动画播放器 = $AnimationPlayer
		if 动画播放器 == null:
			push_warning("Player: 未找到AnimationPlayer节点，动画将无法播放")
		else:
			push_warning("Player: 未在Inspector中指定动画播放器，将自动尝试获取AnimationPlayer子节点")

	if 启用摄像机跟随 and 摄像机 == null:
		摄像机 = $Camera2D
		if 摄像机 == null:
			push_warning("Player: 启用了摄像机跟随但未找到Camera2D节点")

	if 启用摄像机跟随 and 摄像机 != null:
		if not 摄像机.is_current():
			摄像机.make_current()
			print("Player: Camera2D 已设为当前摄像机")

## ===== 公共方法 =====

func 获取玩家状态() -> Dictionary:
	return {
		"位置": position,
		"速度": velocity,
		"朝向": _上一帧朝向,
		"状态": 移动状态.keys()[_当前状态],
		"是否行走中": _当前状态 != 移动状态.IDLE
	}

func 获取动画方向() -> Vector2:
	return last_facing_direction

## 供状态机获取原始输入方向
func get_input_dir() -> Vector2:
	return _获取输入方向()

func 强制停止() -> void:
	velocity = Vector2.ZERO
	_当前状态 = 移动状态.IDLE
