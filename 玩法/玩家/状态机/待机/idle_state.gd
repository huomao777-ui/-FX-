## 描述: 待机状态 — 输入为零时播放对应方向的待机动画
##  用途: 监听输入方向，检测到移动输入时切换到 WalkState
##  依赖: StateMachine 管理生命周期，player 引用通过基类注入
##  状态: 稳定
extends StateBase

## ===== 私有变量 =====

## 上次播放的动画名称，避免重复播放
var _last_animation: String = ""

## ===== 生命周期（由 StateMachine 调用） =====

func enter(prev_state: String) -> void:
	# 重置动画缓存，确保每次进入都强制播放动画
	_last_animation = ""
	_play_idle_animation(player.last_facing_direction)
	print("IdleState: 进入待机状态")

func exit() -> void:
	pass

func physics_update(input_dir: Vector2, delta: float) -> String:
	# 检测到移动输入，切换到行走状态
	if input_dir != Vector2.ZERO:
		return "StateWalk"

	return ""

## ===== 私有方法 =====

func _play_idle_animation(dir: Vector2) -> void:
	var anim_player: AnimationPlayer = player.动画播放器
	var sprite: Sprite2D = player.精灵节点
	if anim_player == null:
		push_warning("IdleState: 动画播放器为空，请在Player检查器中绑定动画播放器节点")
		return
	if sprite == null:
		push_warning("IdleState: 精灵节点为空，请在Player检查器中绑定精灵节点")
		return

	# 垂直优先判定方向
	var anim_name: String = ""
	if dir.y < 0:
		anim_name = "IdelUp"
	elif dir.y > 0:
		anim_name = "IdelDown"
	elif dir.x < 0:
		anim_name = "IdelSide"
		sprite.flip_h = false
	elif dir.x > 0:
		anim_name = "IdelSide"
		sprite.flip_h = true
	else:
		# 默认朝下
		anim_name = "IdelDown"

	if anim_player.has_animation(anim_name):
		if _last_animation != anim_name:
			anim_player.play(anim_name)
			_last_animation = anim_name
	else:
		push_warning("IdleState: 缺少动画 ", anim_name)