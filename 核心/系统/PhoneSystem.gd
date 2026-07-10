## 描述: 手机系统，统一管理电量、充电、WiFi/流量信号和手机使用状态
## 依赖: 作为 GameDataManager 的子节点运行，可监听 TimeSystem 回合推进
## 状态: 初版
## 最后更新：2026-06-12
class_name PhoneSystem
extends Node

## ===== 信号 =====

## 电量变化时发射
signal 电量变化(当前电量: int, 是否低电量: bool)
## 充电状态变化时发射
signal 充电状态变化(是否充电: bool)
## WiFi 信号变化时发射，强度 0~3
signal wifi信号变化(强度: int)
## 流量信号变化时发射，强度 0~4
signal 流量信号变化(强度: int)
## 手机使用状态变化时发射
signal 使用状态变化(状态: int)

## ===== 枚举 =====

enum UsageMode {
	IDLE,
	NORMAL_PHONE,
	MARKET_FOCUS
}

## ===== 导出配置变量 =====

@export_group("电量")
## 初始电量百分比
@export_range(1, 100, 1) var 初始电量: int = 99
## 最低电量，任何消耗都不会低于该值
@export_range(1, 20, 1) var 最低电量: int = 1
## 低电量阈值，低于或等于该值时显示红色
@export_range(1, 50, 1) var 低电量阈值: int = 20
## 未使用手机且完整流逝 4 小时时的目标耗电。
@export_range(0.0, 30.0, 0.1) var 待机每四小时耗电: float = 4.0
## 普通打开手机且完整流逝 4 小时时的目标耗电。
@export_range(0.0, 30.0, 0.1) var 普通使用每四小时耗电: float = 11.5
## 外汇盯盘且完整流逝 4 小时时的目标耗电。
@export_range(0.0, 30.0, 0.1) var 盯盘每四小时耗电: float = 19.0
## 玩家直接推进回合、未完整经历时间流逝时的待机补偿耗电。
@export_range(0.0, 12.0, 0.1) var 待机回合补偿耗电: float = 1.5
## 玩家直接推进回合、未完整经历时间流逝时的普通使用补偿耗电。
@export_range(0.0, 12.0, 0.1) var 普通使用回合补偿耗电: float = 3.0
## 玩家直接推进回合、未完整经历时间流逝时的盯盘补偿耗电。
@export_range(0.0, 12.0, 0.1) var 盯盘回合补偿耗电: float = 4.5
## 兜底用的回合补偿基准分钟。若外部没有传入当前时段总分钟，则使用这个值。
@export_range(30.0, 480.0, 1.0) var 回合补偿兜底分钟: float = 240.0
## 是否启用手机系统日志
@export var 启用手机日志: bool = true

@export_group("信号")
## 默认 WiFi 信号强度，0~3
@export_range(0, 3, 1) var 默认wifi强度: int = 3
## 默认流量信号强度，0~4
@export_range(0, 4, 1) var 默认流量强度: int = 4
## 默认是否显示 WiFi，关闭后显示流量
@export var 默认使用wifi: bool = true

## ===== 内部变量 =====

var _battery: int = 99
var _is_charging: bool = false
var _wifi_strength: int = 3
var _mobile_signal_strength: int = 4
var _use_wifi: bool = true
var _usage_mode: int = UsageMode.IDLE
var _clock_drain_accumulator: float = 0.0
var _minutes_since_turn_settlement: float = 0.0

## ===== 生命周期 =====

func _ready() -> void:
	_battery = clampi(初始电量, 最低电量, 100)
	_wifi_strength = clampi(默认wifi强度, 0, 3)
	_mobile_signal_strength = clampi(默认流量强度, 0, 4)
	_use_wifi = 默认使用wifi
	_emit_all_changed()
	_log_phone_state("初始化")

## ===== 公共接口：耗电结算 =====

## 由 TimeSystem 的钟表分钟变化调用。根据当前手机使用状态累积耗电。
func 处理钟表耗电(delta_minutes: float) -> void:
	if delta_minutes <= 0.0:
		return
	if _is_charging:
		return

	_minutes_since_turn_settlement += delta_minutes
	_clock_drain_accumulator += _get_minute_battery_drain_rate() * delta_minutes
	_flush_accumulated_battery_drain("钟表耗电")

## 由 TimeSystem 回合推进后调用。对直接跳时段的行为做补偿耗电结算。
func 处理回合耗电(时段总分钟: float = -1.0) -> void:
	if _is_charging:
		_minutes_since_turn_settlement = 0.0
		_log_phone_state("正在充电，跳过回合耗电")
		return

	var supplemental_drain: int = _get_turn_supplemental_drain(时段总分钟)
	_minutes_since_turn_settlement = 0.0
	if supplemental_drain <= 0:
		_log_phone_state("回合补偿耗电为0")
		return

	消耗电量(supplemental_drain)
	_log_phone_state("回合补偿耗电")

func 消耗电量(amount: int) -> void:
	if amount <= 0:
		return
	_set_battery(_battery - amount)

func 恢复电量(amount: int) -> void:
	if amount <= 0:
		return
	_set_battery(_battery + amount)

func 设置电量(value: int) -> void:
	_set_battery(value)

func 获取电量() -> int:
	return _battery

func 是否低电量() -> bool:
	return _battery <= 低电量阈值

func 设置充电状态(is_charging: bool) -> void:
	if _is_charging == is_charging:
		return
	_is_charging = is_charging
	充电状态变化.emit(_is_charging)
	电量变化.emit(_battery, 是否低电量())
	_log_phone_state("充电状态变化")

func 是否正在充电() -> bool:
	return _is_charging

## ===== 公共接口：使用状态 =====

func 设置使用状态(mode: int) -> void:
	mode = clampi(mode, UsageMode.IDLE, UsageMode.MARKET_FOCUS)
	if _usage_mode == mode:
		return
	_usage_mode = mode
	使用状态变化.emit(_usage_mode)
	_log_phone_state("使用状态变化")

func 进入待机使用状态() -> void:
	设置使用状态(UsageMode.IDLE)

func 进入普通手机使用状态() -> void:
	设置使用状态(UsageMode.NORMAL_PHONE)

func 进入汇率盯盘使用状态() -> void:
	设置使用状态(UsageMode.MARKET_FOCUS)

func 获取使用状态() -> int:
	return _usage_mode

## ===== 公共接口：信号 =====

func 设置wifi强度(strength: int) -> void:
	_wifi_strength = clampi(strength, 0, 3)
	wifi信号变化.emit(_wifi_strength)

func 获取wifi强度() -> int:
	return _wifi_strength

func 设置流量强度(strength: int) -> void:
	_mobile_signal_strength = clampi(strength, 0, 4)
	流量信号变化.emit(_mobile_signal_strength)

func 获取流量强度() -> int:
	return _mobile_signal_strength

func 设置使用wifi(enabled: bool) -> void:
	if _use_wifi == enabled:
		return
	_use_wifi = enabled
	wifi信号变化.emit(_wifi_strength)
	流量信号变化.emit(_mobile_signal_strength)

func 是否使用wifi() -> bool:
	return _use_wifi

## 地图切换时可调用此接口统一刷新网络状态。
func 设置地图网络状态(wifi_strength: int, mobile_strength: int, use_wifi: bool) -> void:
	_wifi_strength = clampi(wifi_strength, 0, 3)
	_mobile_signal_strength = clampi(mobile_strength, 0, 4)
	_use_wifi = use_wifi
	wifi信号变化.emit(_wifi_strength)
	流量信号变化.emit(_mobile_signal_strength)
	_log_phone_state("地图网络状态变化")

## ===== 存档接口 =====

func 收集存档数据() -> Dictionary:
	return {
		"battery": _battery,
		"is_charging": _is_charging,
		"wifi_strength": _wifi_strength,
		"mobile_signal_strength": _mobile_signal_strength,
		"use_wifi": _use_wifi,
		"usage_mode": _usage_mode
	}

func 恢复存档数据(data: Dictionary) -> void:
	if data.is_empty():
		return
	_battery = clampi(int(data.get("battery", 初始电量)), 最低电量, 100)
	_is_charging = bool(data.get("is_charging", false))
	_wifi_strength = clampi(int(data.get("wifi_strength", 默认wifi强度)), 0, 3)
	_mobile_signal_strength = clampi(int(data.get("mobile_signal_strength", 默认流量强度)), 0, 4)
	_use_wifi = bool(data.get("use_wifi", 默认使用wifi))
	_usage_mode = clampi(int(data.get("usage_mode", UsageMode.IDLE)), UsageMode.IDLE, UsageMode.MARKET_FOCUS)
	_clock_drain_accumulator = 0.0
	_minutes_since_turn_settlement = 0.0
	_emit_all_changed()
	_log_phone_state("恢复存档")

## ===== 私有方法 =====

func _get_minute_battery_drain_rate() -> float:
	return _get_four_hour_battery_drain() / 240.0

func _get_four_hour_battery_drain() -> float:
	match _usage_mode:
		UsageMode.MARKET_FOCUS:
			return 盯盘每四小时耗电
		UsageMode.NORMAL_PHONE:
			return 普通使用每四小时耗电
		_:
			return 待机每四小时耗电

func _get_turn_base_supplement() -> float:
	match _usage_mode:
		UsageMode.MARKET_FOCUS:
			return 盯盘回合补偿耗电
		UsageMode.NORMAL_PHONE:
			return 普通使用回合补偿耗电
		_:
			return 待机回合补偿耗电

func _get_turn_supplemental_drain(时段总分钟: float) -> int:
	var base_supplement: float = _get_turn_base_supplement()
	if base_supplement <= 0.0:
		return 0

	var normalized_minutes: float = 时段总分钟
	if normalized_minutes <= 0.0:
		normalized_minutes = 回合补偿兜底分钟
	normalized_minutes = max(normalized_minutes, 1.0)
	var elapsed_ratio: float = clampf(_minutes_since_turn_settlement / normalized_minutes, 0.0, 1.0)
	var missing_ratio: float = 1.0 - elapsed_ratio
	if missing_ratio <= 0.0:
		return 0

	var drain_value: float = base_supplement * missing_ratio
	if drain_value <= 0.0:
		return 0
	return maxi(int(ceil(drain_value)), 1)

func _flush_accumulated_battery_drain(reason: String) -> void:
	if _clock_drain_accumulator < 1.0:
		return

	var drain_amount: int = int(floor(_clock_drain_accumulator))
	_clock_drain_accumulator -= float(drain_amount)
	消耗电量(drain_amount)
	_log_phone_state(reason)

func _set_battery(value: int) -> void:
	var old: int = _battery
	_battery = clampi(value, 最低电量, 100)
	if old == _battery:
		return
	电量变化.emit(_battery, 是否低电量())

func _emit_all_changed() -> void:
	电量变化.emit(_battery, 是否低电量())
	充电状态变化.emit(_is_charging)
	wifi信号变化.emit(_wifi_strength)
	流量信号变化.emit(_mobile_signal_strength)
	使用状态变化.emit(_usage_mode)

func _log_phone_state(reason: String) -> void:
	if not 启用手机日志:
		return
	print("PhoneSystem: ", reason, " → 电量 ", _battery, "% | 使用状态 ", _usage_mode)
