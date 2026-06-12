## 描述: 状态机基类，定义所有状态的接口规范
##  用途: IdleState / WalkState 继承此基类，实现 enter/exit/physics_update
##  依赖: 由 StateMachine 管理器自动调用，子类无需手动调用
##  状态: 稳定
class_name StateBase
extends Node

## 玩家引用（由 StateMachine.init() 注入）
var player: Player = null

## 状态机管理器引用（由 StateMachine.init() 注入）
var state_machine: StateMachine = null

## 进入状态时调用
## [prev_state] 上一个状态的名称，首次进入为空字符串
func enter(prev_state: String) -> void:
	pass

## 离开状态时调用
func exit() -> void:
	pass

## 物理帧更新（由 StateMachine 委托调用）
## [input_dir] 玩家输入方向向量
## [delta] 帧时间
## 返回: 目标状态名称，空字符串表示不切换
func physics_update(input_dir: Vector2, delta: float) -> String:
	return ""