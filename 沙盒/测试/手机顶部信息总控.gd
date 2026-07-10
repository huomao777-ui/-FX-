## 描述: 挂在“手机顶部信息”或其上层的小型总控，只负责监听全局手机/时间数据并分发给各显示脚本。
## 依赖:
## 1. GameDataManager.时间 / GameDataManager.手机
## 2. 子节点上挂载了对应显示脚本，并提供约定的方法
## 设计原则:
## - 总控不直接改任何 UI 样式
## - 总控只负责找节点、绑定信号、转发状态
## - 具体外观交给时间/日期/电池/信号各自脚本
extends Node

@export_group("节点查找")
## 手机顶部信息根节点；留空时自动尝试从当前节点和父节点附近查找。
@export var 顶部信息根节点路径: NodePath
## 是否在 _ready 时自动绑定全局系统。
@export var 自动绑定全局系统: bool = true

@export_group("子显示节点")
## 时间显示节点；留空时自动查找名为“时间”的节点。
@export var 时间显示节点路径: NodePath
## 日期显示节点；留空时自动查找名为“日期”的节点。
@export var 日期显示节点路径: NodePath
## 电量显示节点；留空时自动查找名为“电量”的节点。
@export var 电量显示节点路径: NodePath
## wifi 显示节点；留空时自动查找名为“wifi”的节点。
@export var wifi显示节点路径: NodePath
## 流量显示节点；留空时自动查找名为“流量”的节点。
@export var 流量显示节点路径: NodePath

var _top_root: Node = null
var _time_display: Node = null
var _date_display: Node = null
var _battery_display: Node = null
var _wifi_display: Node = null
var _mobile_signal_display: Node = null

func _ready() -> void:
	_cache_nodes()
	if 自动绑定全局系统:
		_bind_global_systems()
	_refresh_all()

func 刷新全部() -> void:
	_refresh_all()

func _cache_nodes() -> void:
	_top_root = _get_top_root()
	if _top_root == null:
		push_warning("手机顶部信息总控: 未找到顶部信息根节点")
		return

	_time_display = _resolve_display_node(时间显示节点路径, "时间")
	_date_display = _resolve_display_node(日期显示节点路径, "日期")
	_battery_display = _resolve_display_node(电量显示节点路径, "电量")
	_wifi_display = _resolve_display_node(wifi显示节点路径, "wifi")
	_mobile_signal_display = _resolve_display_node(流量显示节点路径, "流量")

func _get_top_root() -> Node:
	if String(顶部信息根节点路径) != "":
		return get_node_or_null(顶部信息根节点路径)

	if get_parent() != null:
		var direct_parent_root: Node = get_parent().get_node_or_null("手机顶部信息")
		if direct_parent_root != null:
			return direct_parent_root

		var grouped_root: Node = get_parent().get_node_or_null("手机相关节点/手机顶部信息")
		if grouped_root != null:
			return grouped_root

	if name == "手机顶部信息":
		return self

	return get_node_or_null("手机顶部信息")

func _resolve_display_node(path: NodePath, fallback_name: String) -> Node:
	if _top_root == null:
		return null
	if String(path) != "":
		return _top_root.get_node_or_null(path)
	return _top_root.get_node_or_null(fallback_name)

func _bind_global_systems() -> void:
	if not _has_game_data_manager():
		push_warning("手机顶部信息总控: 缺少 GameDataManager，无法绑定全局状态")
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

func _refresh_all() -> void:
	if not _has_game_data_manager():
		return

	if GameDataManager.时间 != null:
		_push_clock(
			GameDataManager.时间.获取当前钟表小时(),
			GameDataManager.时间.获取当前钟表分钟()
		)
		_push_date(GameDataManager.时间.获取手机日期文本())

	if GameDataManager.手机 != null:
		var battery_value: int = GameDataManager.手机.获取电量()
		var is_low: bool = GameDataManager.手机.是否低电量()
		var is_charging: bool = GameDataManager.手机.是否正在充电()
		var wifi_strength: int = GameDataManager.手机.获取wifi强度()
		var mobile_strength: int = GameDataManager.手机.获取流量强度()
		var use_wifi: bool = GameDataManager.手机.是否使用wifi()

		_push_battery(battery_value, is_low, is_charging)
		_push_wifi(wifi_strength, use_wifi)
		_push_mobile_signal(mobile_strength, not use_wifi)

func _push_clock(hour: int, minute: int) -> void:
	if _time_display != null and _time_display.has_method("更新时间显示"):
		_time_display.call("更新时间显示", hour, minute)

func _push_date(date_text: String) -> void:
	if _date_display != null and _date_display.has_method("更新日期显示"):
		_date_display.call("更新日期显示", date_text)

func _push_battery(value: int, is_low: bool, is_charging: bool) -> void:
	if _battery_display != null and _battery_display.has_method("更新电量显示"):
		_battery_display.call("更新电量显示", value, is_low, is_charging)

func _push_wifi(strength: int, is_visible: bool) -> void:
	if _wifi_display != null and _wifi_display.has_method("更新信号显示"):
		_wifi_display.call("更新信号显示", strength, is_visible)

func _push_mobile_signal(strength: int, is_visible: bool) -> void:
	if _mobile_signal_display != null and _mobile_signal_display.has_method("更新信号显示"):
		_mobile_signal_display.call("更新信号显示", strength, is_visible)

func _on_clock_changed(hour: int, minute: int, _slot_elapsed_minutes: float, _slot_total_minutes: int) -> void:
	_push_clock(hour, minute)

func _on_date_changed(_year: int, _month: int, _day: int) -> void:
	if GameDataManager.时间 != null:
		_push_date(GameDataManager.时间.获取手机日期文本())

func _on_slot_changed(_slot_index: int, _slot_name: String) -> void:
	if GameDataManager.时间 != null:
		_push_date(GameDataManager.时间.获取手机日期文本())

func _on_battery_changed(value: int, is_low: bool) -> void:
	var is_charging: bool = false
	if GameDataManager.手机 != null:
		is_charging = GameDataManager.手机.是否正在充电()
	_push_battery(value, is_low, is_charging)

func _on_charging_changed(is_charging: bool) -> void:
	if GameDataManager.手机 == null:
		return
	_push_battery(
		GameDataManager.手机.获取电量(),
		GameDataManager.手机.是否低电量(),
		is_charging
	)

func _on_wifi_changed(strength: int) -> void:
	var use_wifi: bool = true
	if GameDataManager.手机 != null:
		use_wifi = GameDataManager.手机.是否使用wifi()
	_push_wifi(strength, use_wifi)
	_push_mobile_signal(
		GameDataManager.手机.获取流量强度() if GameDataManager.手机 != null else 0,
		not use_wifi
	)

func _on_mobile_signal_changed(strength: int) -> void:
	var use_wifi: bool = false
	if GameDataManager.手机 != null:
		use_wifi = GameDataManager.手机.是否使用wifi()
	_push_mobile_signal(strength, not use_wifi)
