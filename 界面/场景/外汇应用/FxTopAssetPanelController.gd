## 描述: 顶部资产面板控制器，展示账户总资产/保证金/浮动盈亏/已实现盈亏
## 依赖: 父节点为国内炒汇场景；监听 GameDataManager/TradingSystem.账户变化 信号
## 状态: 第一阶段
## 最后更新: 2026-06-25
extends Panel
class_name FxTopAssetPanelController

const PROFIT_COLOR := Color(0.93, 0.24, 0.18, 0.95)
const LOSS_COLOR := Color(0.14, 0.76, 0.34, 0.95)
const NORMAL_TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)

var _equity_label: Label = null
var _used_margin_label: Label = null
var _available_margin_label: Label = null
var _margin_ratio_label: Label = null
var _floating_pnl_label: Label = null
var _realized_pnl_label: Label = null
var _trading_system: Node = null

func _ready() -> void:
	_trading_system = get_node_or_null("/root/GameDataManager/TradingSystem")
	_cache_labels()
	_connect_trading_signals()
	_refresh_all()

func _cache_labels() -> void:
	# 账户总资产 → Label2（子节点）
	var equity_group: Node = _find_descendant_by_name(self, "账户总资产")
	if equity_group != null:
		_equity_label = _find_descendant_by_name(equity_group, "Label2") as Label
	# 已用保证金 → Label3 / Label5 / Label4
	var margin_group: Node = _find_descendant_by_name(self, "已用保证金")
	if margin_group != null:
		_used_margin_label = _find_descendant_by_name(margin_group, "Label3") as Label
		_available_margin_label = _find_descendant_by_name(margin_group, "Label5") as Label
		_margin_ratio_label = _find_descendant_by_name(margin_group, "Label4") as Label
	# 总浮动盈亏 → Label2（子节点）
	var floating_group: Node = _find_descendant_by_name(self, "总浮动盈亏")
	if floating_group != null:
		_floating_pnl_label = _find_descendant_by_name(floating_group, "Label2") as Label
	# 已实现盈亏 → Label2（子节点）
	var realized_group: Node = _find_descendant_by_name(self, "已实现盈亏")
	if realized_group != null:
		_realized_pnl_label = _find_descendant_by_name(realized_group, "Label2") as Label

func _connect_trading_signals() -> void:
	if _trading_system == null or not _trading_system.has_signal("账户变化"):
		return
	var callback := Callable(self, "_on_account_changed")
	if not _trading_system.is_connected("账户变化", callback):
		_trading_system.connect("账户变化", callback)

## 公开方法：外部可手动触发刷新（如开仓后）
func refresh_display() -> void:
	_refresh_all()

func _on_account_changed(_snapshot: Dictionary) -> void:
	_refresh_all()

func _refresh_all() -> void:
	if _trading_system == null:
		_set_defaults()
		return
	if not _trading_system.has_method("获取账户快照"):
		_set_defaults()
		return
	var snapshot: Dictionary = _trading_system.call("获取账户快照") as Dictionary
	if snapshot.is_empty():
		_set_defaults()
		return
	var equity: float = float(snapshot.get("equity", 0.0))
	var used_margin: float = float(snapshot.get("used_margin", 0.0))
	var floating_pnl: float = float(snapshot.get("floating_pnl", 0.0))
	var margin_ratio: float = float(snapshot.get("margin_ratio", 0.0))
	var cash: float = float(snapshot.get("cash", 0.0))
	var debt: float = float(snapshot.get("debt", 0.0))
	var realized_pnl: float = cash - 10000.0  # 初始现金 10000

	_set_equity(equity)
	_set_used_margin(used_margin)
	_set_available_margin(equity - used_margin)
	_set_margin_ratio(margin_ratio)
	_set_floating_pnl(floating_pnl)
	_set_realized_pnl(realized_pnl)

func _set_defaults() -> void:
	_set_equity(10000.0)
	_set_used_margin(0.0)
	_set_available_margin(10000.0)
	_set_margin_ratio(0.0)
	_set_floating_pnl(0.0)
	_set_realized_pnl(0.0)

func _set_equity(value: float) -> void:
	if _equity_label != null:
		_equity_label.text = _format_number(value)

func _set_used_margin(value: float) -> void:
	if _used_margin_label != null:
		_used_margin_label.text = "已用保证金：%s" % _format_number(value)

func _set_available_margin(value: float) -> void:
	if _available_margin_label != null:
		_available_margin_label.text = "可用保证金：%s" % _format_number(max(value, 0.0))

func _set_margin_ratio(value: float) -> void:
	if _margin_ratio_label != null:
		if value >= 999.0:
			_margin_ratio_label.text = "保证金比例：∞"
		else:
			_margin_ratio_label.text = "保证金比例：%d%%" % int(round(value * 100.0))

func _set_floating_pnl(value: float) -> void:
	if _floating_pnl_label == null:
		return
	if value >= 0.0:
		_floating_pnl_label.text = "+%s" % _format_number(value)
		_floating_pnl_label.add_theme_color_override("font_color", PROFIT_COLOR)
	else:
		_floating_pnl_label.text = "-%s" % _format_number(absf(value))
		_floating_pnl_label.add_theme_color_override("font_color", LOSS_COLOR)

func _set_realized_pnl(value: float) -> void:
	if _realized_pnl_label == null:
		return
	if value >= 0.0:
		_realized_pnl_label.text = "+%s" % _format_number(value)
		_realized_pnl_label.add_theme_color_override("font_color", PROFIT_COLOR)
	else:
		_realized_pnl_label.text = "-%s" % _format_number(absf(value))
		_realized_pnl_label.add_theme_color_override("font_color", LOSS_COLOR)

func _format_number(value: float) -> String:
	var rounded: int = int(round(value))
	var text: String = str(rounded)
	var result: String = ""
	var count: int = 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = text[i] + result
		count += 1
	return result

func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found: Node = _find_descendant_by_name(child, target_name)
		if found != null:
			return found
	return null
