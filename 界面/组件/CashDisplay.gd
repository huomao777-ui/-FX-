## 描述: 现金与总资产数字跳动显示控件
## 依赖: 挂载在 现金与账户 (Sprite2D) 节点上，子节点需包含 现金数字 和 总资产数字 两个 Label
## 状态: 完成
## 最后更新：2026-06-03
extends Sprite2D

## ===== 导出变量 =====

## 数字跳动动画的持续时间（秒）
@export var 跳动时长: float = 0.3

## ===== 内部变量 =====

## 当前现金值（动画目标完成后更新）
var _current_cash: float = 0.0
## 当前总资产值（动画目标完成后更新）
var _current_assets: float = 0.0
## 现金数字的 Tween 实例
var _cash_tween: Tween = null
## 总资产数字的 Tween 实例
var _assets_tween: Tween = null

## ===== 节点引用 =====

## 子节点：现金数字 Label
@onready var _cash_label: Label = $现金数字
## 子节点：总资产数字 Label
@onready var _assets_label: Label = $总资产数字

## ===== 生命周期 =====

func _ready() -> void:
	if _cash_label == null:
		push_warning("CashDisplay: 未找到子节点 '现金数字'（Label），现金数字将无法显示")
	if _assets_label == null:
		push_warning("CashDisplay: 未找到子节点 '总资产数字'（Label），总资产数字将无法显示")

	# 检查 AssetSystem 是否可用
	if GameDataManager.资产 == null:
		push_warning("CashDisplay: GameDataManager.资产 不可用，无法获取初始值")
		return

	# 读取初始值
	_current_cash = GameDataManager.资产.get_value()
	_current_assets = GameDataManager.资产.get_max_value()

	# 显示初始格式化值
	if _cash_label != null:
		_cash_label.text = _format_number(_current_cash)
	if _assets_label != null:
		_assets_label.text = _format_number(_current_assets)

	# 连接信号（使用 is_connected 防止重复连接）
	if not GameDataManager.资产.value_changed.is_connected(_on_资产变化):
		GameDataManager.资产.connect("value_changed", _on_资产变化)

## ===== 信号回调 =====

## 监听 AssetSystem 数值变化，同时更新现金和总资产
func _on_资产变化(当前值: float, 最大值: float, _比例: float) -> void:
	# 现金启动跳动动画
	if _cash_label != null:
		_start_tween_cash(当前值)
	# 总资产启动跳动动画
	if _assets_label != null:
		_start_tween_assets(最大值)

## ===== 动画逻辑 =====

## 启动现金数字跳动动画
func _start_tween_cash(target_value: float) -> void:
	# 取消上一次未完成的 Tween，避免动画冲突
	if _cash_tween != null and _cash_tween.is_valid():
		_cash_tween.kill()

	var start_value: float = _current_cash
	_cash_tween = create_tween()
	_cash_tween.tween_method(
		_update_cash_display,
		start_value,
		target_value,
		跳动时长
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_cash_tween.finished.connect(_on_cash_tween_done.bind(target_value), CONNECT_ONE_SHOT)

## 启动总资产数字跳动动画
func _start_tween_assets(target_value: float) -> void:
	# 取消上一次未完成的 Tween，避免动画冲突
	if _assets_tween != null and _assets_tween.is_valid():
		_assets_tween.kill()

	var start_value: float = _current_assets
	_assets_tween = create_tween()
	_assets_tween.tween_method(
		_update_assets_display,
		start_value,
		target_value,
		跳动时长
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_assets_tween.finished.connect(_on_assets_tween_done.bind(target_value), CONNECT_ONE_SHOT)

## ===== 显示更新 =====

## Tween 逐帧回调：更新现金 Label 文本
func _update_cash_display(value: float) -> void:
	if _cash_label != null:
		_cash_label.text = _format_number(value)

## Tween 逐帧回调：更新总资产 Label 文本
func _update_assets_display(value: float) -> void:
	if _assets_label != null:
		_assets_label.text = _format_number(value)

## Tween 完成回调：记录现金最终值并清理引用
func _on_cash_tween_done(target_value: float) -> void:
	_current_cash = target_value
	_cash_tween = null

## Tween 完成回调：记录总资产最终值并清理引用
func _on_assets_tween_done(target_value: float) -> void:
	_current_assets = target_value
	_assets_tween = null

## ===== 工具函数 =====

## 将数值格式化为千位逗号字符串
## 整数不显示小数点，有小数时保留一位
func _format_number(value: float) -> String:
	var abs_value: float = abs(value)
	var sign: String = "-" if value < 0 else ""

	# 保留一位小数（snapped 代替已弃用的 stepify）
	var snapped_val: float = snapped(abs_value, 0.1)

	# 分离整数和小数部分
	var int_part: int = int(floor(snapped_val))
	var frac_part: int = int(round((snapped_val - floor(snapped_val)) * 10.0))

	# 格式化整数部分：从右向左每隔三位加逗号
	var int_str: String = str(int_part)
	var formatted_int: String = ""
	var len: int = int_str.length()
	for i in range(len):
		if i > 0 and (len - i) % 3 == 0:
			formatted_int += ","
		formatted_int += int_str[i]

	# 组装结果：有小数时拼接 .X，无小数时只返回整数部分
	if frac_part > 0:
		return sign + formatted_int + "." + str(frac_part)
	else:
		return sign + formatted_int