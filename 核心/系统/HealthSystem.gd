## 描述: 健康系统，管理角色健康值的降低和恢复
## 依赖: 作为 GameDataManager 的子节点运行
## 状态: 完成
## 最后更新：2026-06-02
class_name HealthSystem
extends Node

## ===== 信号 =====

## 数值变化时发射，携带当前值、最大值、比例
signal value_changed(当前值: float, 最大值: float, 比例: float)

## ===== 常量 =====

const DEFAULT_MIN: float = 0.0
const DEFAULT_MAX: float = 100.0
const DEFAULT_CURRENT: float = 100.0

## ===== 内部变量 =====

var _current_value: float = DEFAULT_CURRENT
var _max_value: float = DEFAULT_MAX
var _min_value: float = DEFAULT_MIN

## ===== 生命周期 =====

func _ready() -> void:
	_current_value = DEFAULT_CURRENT
	_max_value = DEFAULT_MAX
	_min_value = DEFAULT_MIN
	_emit_value_changed()

## ===== 公共接口 =====

## 获取当前健康值
func get_value() -> float:
	return _current_value

## 获取健康上限
func get_max_value() -> float:
	return _max_value

## 获取健康下限
func get_min_value() -> float:
	return _min_value

## 获取当前比例 0.0~1.0
func get_ratio() -> float:
	var range_val: float = max(_max_value - _min_value, 0.01)
	return (_current_value - _min_value) / range_val

## 降低健康，val > 0
func 降低健康(val: float) -> void:
	if val <= 0:
		return
	var old: float = _current_value
	_current_value = clampf(_current_value - val, _min_value, _max_value)
	_emit_value_changed()
	if not is_equal_approx(old, _current_value):
		print("HealthSystem: 降低健康 ", val, "，当前 ", _current_value)

## 恢复健康，val > 0
func 恢复健康(val: float) -> void:
	if val <= 0:
		return
	var old: float = _current_value
	_current_value = clampf(_current_value + val, _min_value, _max_value)
	_emit_value_changed()
	if not is_equal_approx(old, _current_value):
		print("HealthSystem: 恢复健康 ", val, "，当前 ", _current_value)

## ===== 核心逻辑 =====

func _emit_value_changed() -> void:
	value_changed.emit(_current_value, _max_value, get_ratio())