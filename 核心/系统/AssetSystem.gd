## 描述: 资产系统，管理现金和总资产
## 依赖: 作为 GameDataManager 的子节点运行
## 状态: 完成
## 最后更新：2026-06-02
class_name AssetSystem
extends Node

## ===== 信号 =====

## 数值变化时发射，携带当前现金、总资产、比例
signal value_changed(当前值: float, 最大值: float, 比例: float)

## ===== 常量 =====

const DEFAULT_CASH: float = 10000.0
const DEFAULT_TOTAL_ASSETS: float = 10000.0

## ===== 内部变量 =====

var _当前现金: float = DEFAULT_CASH
var _总资产: float = DEFAULT_TOTAL_ASSETS

## ===== 生命周期 =====

func _ready() -> void:
	_当前现金 = DEFAULT_CASH
	_总资产 = DEFAULT_TOTAL_ASSETS
	_emit_value_changed()

## ===== 公共接口 =====

## 获取当前现金
func get_value() -> float:
	return _当前现金

## 获取总资产
func get_max_value() -> float:
	return _总资产

## 获取现金下限
func get_min_value() -> float:
	return 0.0

## 获取当前比例（现金/总资产）
func get_ratio() -> float:
	return _当前现金 / max(_总资产, 0.01)

## 增加现金，val > 0
func 增加现金(val: float) -> void:
	if val <= 0:
		return
	_当前现金 += val
	_emit_value_changed()
	print("AssetSystem: 增加现金 ", val, "，当前现金 ", _当前现金)

## 扣除现金，val > 0（不会低于 0）
func 扣除现金(val: float) -> void:
	if val <= 0:
		return
	var old: float = _当前现金
	_当前现金 = max(_当前现金 - val, 0.0)
	_emit_value_changed()
	if not is_equal_approx(old, _当前现金):
		print("AssetSystem: 扣除现金 ", val, "，当前现金 ", _当前现金)

## 更新总资产
func 更新总资产(val: float) -> void:
	if val < 0:
		return
	_总资产 = val
	_emit_value_changed()
	print("AssetSystem: 更新总资产为 ", _总资产)

## ===== 核心逻辑 =====

func _emit_value_changed() -> void:
	value_changed.emit(_当前现金, _总资产, get_ratio())