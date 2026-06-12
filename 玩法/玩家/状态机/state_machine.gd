## 描述: 状态机管理器，负责状态注册、切换和调度
##  用途: 统一管理 IdleState / WalkState 等子节点的生命周期
##  依赖: 子节点需继承 StateBase，场景结构如下:
##    StateMachine (Node)
##    ├── StateIdle (Node)  → idle_state.gd
##    └── StateWalk (Node)  → walk_state.gd
##  状态: 稳定
class_name StateMachine
extends Node

## 当前活跃状态节点
var current_state: StateBase = null

## 当前状态名称
var current_state_name: String = ""

## 所有已注册的状态表（状态名 → 节点）
var _states: Dictionary = {}

## 初始化状态机（由 Player._ready() 调用）
## [player_node] 玩家根节点引用
func init(player_node: Player) -> void:
	for child in get_children():
		if child is StateBase:
			var state: StateBase = child as StateBase
			state.player = player_node
			state.state_machine = self
			_states[child.name] = state
			print("StateMachine: 已注册状态 ", child.name)

	if _states.size() == 0:
		push_error("StateMachine: 未找到任何 StateBase 子节点")
		return

	# 以第一个注册的状态为初始状态
	var first_state_name: String = _states.keys()[0]
	transition_to(first_state_name)

## 切换到指定状态
## [state_name] 目标状态节点名称
func transition_to(state_name: String) -> void:
	if not _states.has(state_name):
		push_error("StateMachine: 未知状态 ", state_name)
		return

	var prev_state_name: String = current_state_name

	# 退出当前状态
	if current_state != null:
		current_state.exit()

	# 进入新状态
	current_state = _states[state_name]
	current_state_name = state_name
	current_state.enter(prev_state_name)
	print("StateMachine: 切换到 ", state_name)

## 物理帧更新入口（由 Player._physics_process() 调用）
## [input_dir] 玩家输入方向向量
## [delta] 帧时间
func physics_update(input_dir: Vector2, delta: float) -> void:
	if current_state == null:
		return

	var next_state: String = current_state.physics_update(input_dir, delta)
	if next_state != "":
		transition_to(next_state)

## 获取当前状态名称
func get_current_state_name() -> String:
	return current_state_name