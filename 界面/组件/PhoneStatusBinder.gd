## 描述: 手机状态栏显示绑定器，统一刷新时间、日期、电量、WiFi 和流量显示
## 依赖: 场景内存在 时间、日期、电量/电池、wifi、流量 等节点时会自动绑定
## 状态: 初版
## 最后更新：2026-06-12
class_name PhoneStatusBinder
extends Node

## ===== 导出配置变量 =====

@export_group("节点查找")
## 手机状态根节点路径；为空时自动查找 手机相关节点/手机顶部信息、手机唤醒状态 或 手机进入状态
@export var 手机状态根节点: NodePath
## 是否在 _ready 时自动绑定 GameDataManager
@export var 自动绑定全局系统: bool = true

@export_group("颜色")
## 正常电量颜色
@export var 正常电量颜色: Color = Color(1.0, 1.0, 1.0, 1.0)
## 低电量颜色
@export var 低电量颜色: Color = Color(1.0, 0.08, 0.08, 1.0)
## 充电颜色
@export var 充电颜色: Color = Color(0.1, 0.9, 0.25, 1.0)

## ===== 内部变量 =====

var _root_node: Node = null
var _time_label: RichTextLabel = null
var _date_label: Label = null
var _battery_bar: ProgressBar = null
var _battery_number: Label = null
var _wifi_root: Node = null
var _mobile_signal_root: Node = null
var _battery_fill_style: StyleBoxFlat = null

## ===== 生命周期 =====

func _ready() -> void:
	_cache_nodes()
	_prepare_battery_style()
	if 自动绑定全局系统:
		_bind_global_systems()
	_refresh_all()

## ===== 公共接口 =====

func 刷新全部() -> void:
	_refresh_all()

## ===== 私有方法：绑定 =====

func _cache_nodes() -> void:
	_root_node = _get_status_root()
	if _root_node == null:
		push_warning("PhoneStatusBinder: 未找到手机状态根节点")
		return

	_time_label = _root_node.get_node_or_null("时间") as RichTextLabel
	_date_label = _root_node.get_node_or_null("日期") as Label
	_battery_bar = _root_node.get_node_or_null("电量/电池") as ProgressBar
	_wifi_root = _root_node.get_node_or_null("wifi")
	_mobile_signal_root = _root_node.get_node_or_null("流量")

	if _battery_bar != null:
		_battery_number = _battery_bar.get_node_or_null("数字") as Label

func _get_status_root() -> Node:
	if String(手机状态根节点) != "":
		return get_node_or_null(手机状态根节点)

	var parent_node: Node = get_parent()
	if parent_node == null:
		return null

	var grouped_phone_root: Node = parent_node.get_node_or_null("手机相关节点/手机顶部信息")
	if grouped_phone_root != null:
		return grouped_phone_root

	var phone_info_root: Node = parent_node.get_node_or_null("手机顶部信息")
	if phone_info_root != null:
		return phone_info_root

	var wake_root: Node = parent_node.get_node_or_null("手机唤醒状态")
	if wake_root != null:
		return wake_root

	return parent_node.get_node_or_null("手机进入状态")

func _prepare_battery_style() -> void:
	if _battery_bar == null:
		return
	var style: StyleBox = _battery_bar.get_theme_stylebox("fill")
	if style is StyleBoxFlat:
		_battery_fill_style = (style as StyleBoxFlat).duplicate() as StyleBoxFlat
		_battery_bar.add_theme_stylebox_override("fill", _battery_fill_style)

func _bind_global_systems() -> void:
	if not _has_game_data_manager():
		push_warning("PhoneStatusBinder: 缺少 GameDataManager，无法绑定全局手机状态")
		return

	if GameDataManager.时间 != null:
		if not GameDataManager.时间.钟表时间变化.is_connected(_on_clock_changed):
			GameDataManager.时间.钟表时间变化.connect(_on_clock_changed)
		if not GameDataManager.时间.日期变化.is_connected(_on_date_changed):
			GameDataManager.时间.日期变化.connect(_on_date_changed)
		if not GameDataManager.时间.时段变化.is_connected(_on_slot_changed):
			GameDataManager.时间.时段变化.connect(_on_slot_changed)

	if GameDataManager.手机 != null:
		if not GameDataManager.手机.电量变化.is_connected(_on_battery_changed):
			GameDataManager.手机.电量变化.connect(_on_battery_changed)
		if not GameDataManager.手机.充电状态变化.is_connected(_on_charging_changed):
			GameDataManager.手机.充电状态变化.connect(_on_charging_changed)
		if not GameDataManager.手机.wifi信号变化.is_connected(_on_wifi_changed):
			GameDataManager.手机.wifi信号变化.connect(_on_wifi_changed)
		if not GameDataManager.手机.流量信号变化.is_connected(_on_mobile_signal_changed):
			GameDataManager.手机.流量信号变化.connect(_on_mobile_signal_changed)

func _has_game_data_manager() -> bool:
	return get_node_or_null("/root/GameDataManager") != null

## ===== 私有方法：刷新 =====

func _refresh_all() -> void:
	if not _has_game_data_manager():
		return

	if GameDataManager.时间 != null:
		_update_clock(GameDataManager.时间.获取当前钟表小时(), GameDataManager.时间.获取当前钟表分钟())
		_update_date()

	if GameDataManager.手机 != null:
		_update_battery(GameDataManager.手机.获取电量(), GameDataManager.手机.是否低电量())
		_update_signal_visibility()
		_update_wifi(GameDataManager.手机.获取wifi强度())
		_update_mobile_signal(GameDataManager.手机.获取流量强度())

func _update_clock(hour: int, minute: int) -> void:
	if _time_label == null:
		return
	var time_text: String = "%02d:%02d" % [hour, minute]
	if _time_label.bbcode_enabled:
		_time_label.text = "[b]" + time_text
	else:
		_time_label.text = time_text + "\n"

func _update_date() -> void:
	if _date_label == null or GameDataManager.时间 == null:
		return
	_date_label.text = GameDataManager.时间.获取手机日期文本()

func _update_battery(value: int, is_low: bool) -> void:
	if _battery_bar != null:
		_battery_bar.value = value
		_battery_bar.max_value = 100
	if _battery_number != null:
		_battery_number.text = str(value)

	if _battery_fill_style == null or GameDataManager.手机 == null:
		return

	if GameDataManager.手机.是否正在充电():
		_battery_fill_style.bg_color = 充电颜色
	elif is_low:
		_battery_fill_style.bg_color = 低电量颜色
	else:
		_battery_fill_style.bg_color = 正常电量颜色

func _update_signal_visibility() -> void:
	if GameDataManager.手机 == null:
		return
	if _wifi_root != null:
		_wifi_root.visible = GameDataManager.手机.是否使用wifi()
	if _mobile_signal_root != null:
		_mobile_signal_root.visible = not GameDataManager.手机.是否使用wifi()

func _update_wifi(strength: int) -> void:
	if _wifi_root == null:
		return
	_set_signal_children_visible(_wifi_root, strength)
	_update_signal_visibility()

func _update_mobile_signal(strength: int) -> void:
	if _mobile_signal_root == null:
		return
	_set_signal_children_visible(_mobile_signal_root, strength)
	_update_signal_visibility()

func _set_signal_children_visible(root: Node, strength: int) -> void:
	var bars: Array[Node] = _collect_signal_bars(root)
	for i in range(bars.size()):
		bars[i].visible = i < strength

func _collect_signal_bars(root: Node) -> Array[Node]:
	var bars: Array[Node] = []
	var current: Node = root.get_node_or_null("1格信号")
	while current != null:
		bars.append(current)
		var next_name: String = str(bars.size() + 1) + "格信号"
		current = current.get_node_or_null(next_name)
	return bars

## ===== 信号回调 =====

func _on_clock_changed(hour: int, minute: int, _slot_elapsed_minutes: float, _slot_total_minutes: int) -> void:
	_update_clock(hour, minute)

func _on_date_changed(_year: int, _month: int, _day: int) -> void:
	_update_date()

func _on_slot_changed(_slot_index: int, _slot_name: String) -> void:
	_update_date()

func _on_battery_changed(value: int, is_low: bool) -> void:
	_update_battery(value, is_low)

func _on_charging_changed(_is_charging: bool) -> void:
	if GameDataManager.手机 != null:
		_update_battery(GameDataManager.手机.获取电量(), GameDataManager.手机.是否低电量())

func _on_wifi_changed(strength: int) -> void:
	_update_wifi(strength)

func _on_mobile_signal_changed(strength: int) -> void:
	_update_mobile_signal(strength)
