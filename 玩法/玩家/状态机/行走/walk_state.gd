## 描述: 行走状态 — 有移动输入时播放对应方向的奔跑动画
##  用途: 根据输入方向播放 Run 动画，带左右翻转；输入归零时切换到 IdleState
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
	# 进入时立即根据当前输入方向播放动画
	var input_dir: Vector2 = player.get_input_dir()
	_update_run_animation(input_dir)
	print("WalkState: 进入行走状态")

func exit() -> void:
	pass

func physics_update(input_dir: Vector2, delta: float) -> String:
	# 输入归零，切换到待机状态
	if input_dir == Vector2.ZERO:
		return "StateIdle"

	# 更新朝向和动画
	player.last_facing_direction = input_dir
	_update_run_animation(input_dir)

	return ""

## ===== 私有方法 =====

func _update_run_animation(dir: Vector2) -> void:
	var anim_player: AnimationPlayer = player.动画播放器
	var sprite: Sprite2D = player.精灵节点
	if anim_player == null:
		push_warning("WalkState: 动画播放器为空，请在Player检查器中绑定动画播放器节点")
		return
	if sprite == null:
		push_warning("WalkState: 精灵节点为空，请在Player检查器中绑定精灵节点")
		return

	# 垂直优先判定方向
	var anim_name: String = ""
	if dir.y < 0:
		# 上方向
		anim_name = "RunUp"
	elif dir.y > 0:
		# 下方向
		anim_name = "RunDown"
	elif dir.x < 0:
		# 左方向
		anim_name = "RunSide"
		sprite.flip_h = false
	elif dir.x > 0:
		# 右方向 — 翻转精灵实现
		anim_name = "RunSide"
		sprite.flip_h = true

	if anim_player.has_animation(anim_name):
		if _last_animation != anim_name:
			anim_player.play(anim_name)
			_last_animation = anim_name
	else:
		push_warning("WalkState: 缺少动画 ", anim_name)