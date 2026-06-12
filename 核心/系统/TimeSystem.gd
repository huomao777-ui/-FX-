## 描述: 时间系统，统一管理回合、时段、日期和回合内钟表流动
## 依赖: 作为 GameDataManager 的子节点运行
## 状态: 初版
## 最后更新：2026-06-12
class_name TimeSystem
extends Node

## ===== 信号 =====

## 回合推进后发射，携带总回合、时段索引、时段名称
signal 回合推进(总回合: int, 时段索引: int, 时段名称: String)
## 时段变化后发射
signal 时段变化(时段索引: int, 时段名称: String)
## 日期变化后发射
signal 日期变化(年份: int, 月份: int, 日期: int)
## 月份变化后发射
signal 月份变化(年份: int, 月份: int)
## 新的一天开始时发射
signal 新的一天开始(年份: int, 月份: int, 日期: int)
## 从深夜跨入次日清晨前发射，供隔夜利息、睡眠、压力等系统结算
signal 深夜结算开始()
## 回合内钟表分钟变化时发射，供手机 UI 刷新
signal 钟表时间变化(小时: int, 分钟: int, 时段内分钟: float, 时段总分钟: int)
## 普通模式到达时段末尾且不自动推进时发射
signal 时段等待确认(时段索引: int, 时段名称: String)
## 时间流动模式变化时发射
signal 时间流动模式变化(模式: int)

## ===== 枚举 =====

enum TimeSlot {
	MORNING,
	NOON,
	DUSK,
	EVENING,
	LATE_NIGHT
}

enum FlowMode {
	PAUSED,
	NORMAL,
	MARKET_FOCUS
}

## ===== 常量 =====

const TURNS_PER_DAY: int = 5
const MINUTES_PER_DAY: int = 24 * 60
const SLOT_NAMES: Array[String] = ["清晨", "中午", "黄昏", "晚上", "深夜"]
const SLOT_START_MINUTES: Array[int] = [
	8 * 60,
	12 * 60,
	16 * 60,
	20 * 60,
	0
]
const SLOT_DURATIONS: Array[int] = [
	4 * 60,
	4 * 60,
	4 * 60,
	4 * 60,
	8 * 60
]

## ===== 导出配置变量 =====

@export_group("初始日期")
## 开局年份
@export var 初始年份: int = 2026
## 开局月份
@export_range(1, 12, 1) var 初始月份: int = 4
## 开局日期
@export_range(1, 31, 1) var 初始日期: int = 1
## 开局时段索引：0清晨 / 1中午 / 2黄昏 / 3晚上 / 4深夜
@export_range(0, 4, 1) var 初始时段索引: int = TimeSlot.MORNING

@export_group("回合内钟表流动")
## 普通手机界面流速：现实每秒推进的游戏分钟数。默认约80分钟现实时间走完4小时。
@export var 普通模式每秒推进分钟: float = 0.05
## 汇率软件专注流速：现实每秒推进的游戏分钟数。默认约13分20秒现实时间走完4小时。
@export var 汇率专注每秒推进分钟: float = 0.30
## 普通模式到达时段末尾时是否自动推进回合
@export var 普通模式允许自动推进: bool = false
## 汇率专注模式到达时段末尾时是否自动推进回合
@export var 汇率专注允许自动推进: bool = true
## 是否启用关键状态日志
@export var 启用时间日志: bool = true

## ===== 内部变量 =====

var _total_turns: int = 0
var _current_year: int = 2026
var _current_month: int = 4
var _current_day: int = 1
var _current_slot: int = TimeSlot.MORNING
var _slot_elapsed_minutes: float = 0.0
var _flow_mode: int = FlowMode.NORMAL
var _is_waiting_for_confirm: bool = false

## ===== 生命周期 =====

func _ready() -> void:
	_set_date_safely(初始年份, 初始月份, 初始日期, 初始时段索引)
	_emit_clock_changed()
	_log_time_state("初始化")

func _process(delta: float) -> void:
	_update_soft_clock(delta)

## ===== 公共接口：回合推进 =====

## 推进一个完整回合。玩家行动完成、汇率专注自动跨时段、确认时段结束时调用。
func 推进回合() -> void:
	var previous_slot: int = _current_slot
	var should_start_new_day: bool = _current_slot == TimeSlot.LATE_NIGHT

	if should_start_new_day:
		深夜结算开始.emit()

	_total_turns += 1
	_current_slot = (_current_slot + 1) % TURNS_PER_DAY
	_slot_elapsed_minutes = 0.0
	_is_waiting_for_confirm = false

	if should_start_new_day:
		_advance_day()

	if previous_slot != _current_slot:
		时段变化.emit(_current_slot, 获取时段名称())

	回合推进.emit(_total_turns, _current_slot, 获取时段名称())
	_emit_clock_changed()
	_log_time_state("推进回合")

## 普通模式到达时段末尾后，等待玩家确认时调用。
func 确认推进回合() -> void:
	if not _is_waiting_for_confirm:
		return
	推进回合()

## 调试接口：按回合数前进或后退时间。负数会回退日期和时段，但不会反向撤销其他系统结算。
func 调试变动回合(turn_delta: int) -> void:
	if turn_delta == 0:
		return
	if turn_delta > 0:
		for i in range(turn_delta):
			推进回合()
		return

	for i in range(abs(turn_delta)):
		_retreat_one_turn_for_debug()

## 直接设置游戏时间，主要用于新游戏、读档和调试。
func 设置时间(year: int, month: int, day: int, slot: int = TimeSlot.MORNING, elapsed_minutes: float = 0.0) -> void:
	_set_date_safely(year, month, day, slot)
	_slot_elapsed_minutes = clampf(elapsed_minutes, 0.0, float(获取当前时段总分钟()))
	_is_waiting_for_confirm = false
	_emit_all_time_changed()
	_log_time_state("设置时间")

## ===== 公共接口：流动模式 =====

## 暂停回合内钟表流动，用于设置界面、剧情停顿等。
func 暂停时间流动() -> void:
	_set_flow_mode(FlowMode.PAUSED)

## 设置为普通流动，用于普通手机界面或需要轻微走钟的界面。
func 进入普通时间流动() -> void:
	_set_flow_mode(FlowMode.NORMAL)

## 设置为汇率专注流动，仅建议在打开汇率软件、盯盘等待波动时调用。
func 进入汇率专注时间流动() -> void:
	_set_flow_mode(FlowMode.MARKET_FOCUS)

func 获取时间流动模式() -> int:
	return _flow_mode

func 是否等待确认() -> bool:
	return _is_waiting_for_confirm

## ===== 公共接口：查询 =====

func 获取总回合数() -> int:
	return _total_turns

func 获取当前年份() -> int:
	return _current_year

func 获取当前月份() -> int:
	return _current_month

func 获取当前日期() -> int:
	return _current_day

func 获取当前时段索引() -> int:
	return _current_slot

func 获取时段名称() -> String:
	if _current_slot < 0 or _current_slot >= SLOT_NAMES.size():
		return "未知"
	return SLOT_NAMES[_current_slot]

func 获取当前时段总分钟() -> int:
	if _current_slot < 0 or _current_slot >= SLOT_DURATIONS.size():
		return SLOT_DURATIONS[TimeSlot.MORNING]
	return SLOT_DURATIONS[_current_slot]

func 获取时段内分钟() -> float:
	return _slot_elapsed_minutes

func 获取当月天数(year: int = -1, month: int = -1) -> int:
	if year <= 0:
		year = _current_year
	if month <= 0:
		month = _current_month
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if _is_leap_year(year) else 28
		_:
			push_warning("TimeSystem: 月份非法，已按30天处理: " + str(month))
			return 30

func 获取当月总回合数() -> int:
	return 获取当月天数() * TURNS_PER_DAY

func 是否深夜() -> bool:
	return _current_slot == TimeSlot.LATE_NIGHT

func 是否月末() -> bool:
	return _current_day == 获取当月天数()

func 是否年末() -> bool:
	return _current_month == 12 and 是否月末()

func 获取当前钟表分钟总数() -> int:
	var start_minutes: int = SLOT_START_MINUTES[_current_slot]
	var total_minutes: int = start_minutes + int(floor(_slot_elapsed_minutes))
	return total_minutes % MINUTES_PER_DAY

func 获取当前钟表小时() -> int:
	return 获取当前钟表分钟总数() / 60

func 获取当前钟表分钟() -> int:
	return 获取当前钟表分钟总数() % 60

func 获取时间文本() -> String:
	return "%04d/%02d/%02d %s %02d:%02d" % [
		_current_year,
		_current_month,
		_current_day,
		获取时段名称(),
		获取当前钟表小时(),
		获取当前钟表分钟()
	]

func 获取当前日期数据() -> Dictionary:
	return {
		"year": _current_year,
		"month": _current_month,
		"day": _current_day,
		"slot": _current_slot,
		"slot_name": 获取时段名称(),
		"slot_elapsed_minutes": _slot_elapsed_minutes,
		"clock_hour": 获取当前钟表小时(),
		"clock_minute": 获取当前钟表分钟(),
		"total_turns": _total_turns,
		"flow_mode": _flow_mode,
		"is_waiting_for_confirm": _is_waiting_for_confirm
	}

## ===== 存档接口 =====

func 收集存档数据() -> Dictionary:
	return {
		"total_turns": _total_turns,
		"year": _current_year,
		"month": _current_month,
		"day": _current_day,
		"slot": _current_slot,
		"slot_elapsed_minutes": _slot_elapsed_minutes,
		"flow_mode": _flow_mode,
		"is_waiting_for_confirm": _is_waiting_for_confirm
	}

func 恢复存档数据(data: Dictionary) -> void:
	if data.is_empty():
		return
	_total_turns = max(int(data.get("total_turns", 0)), 0)
	_set_date_safely(
		int(data.get("year", 初始年份)),
		int(data.get("month", 初始月份)),
		int(data.get("day", 初始日期)),
		int(data.get("slot", 初始时段索引))
	)
	_slot_elapsed_minutes = clampf(
		float(data.get("slot_elapsed_minutes", 0.0)),
		0.0,
		float(获取当前时段总分钟())
	)
	_flow_mode = clampi(int(data.get("flow_mode", FlowMode.NORMAL)), FlowMode.PAUSED, FlowMode.MARKET_FOCUS)
	_is_waiting_for_confirm = bool(data.get("is_waiting_for_confirm", false))
	_emit_all_time_changed()
	_log_time_state("恢复存档")

## ===== 私有方法：钟表流动 =====

func _update_soft_clock(delta: float) -> void:
	if _flow_mode == FlowMode.PAUSED or _is_waiting_for_confirm:
		return

	var speed: float = _get_current_flow_speed()
	if speed <= 0.0:
		return

	var old_clock_minute: int = 获取当前钟表分钟总数()
	_slot_elapsed_minutes += delta * speed

	if _slot_elapsed_minutes >= float(获取当前时段总分钟()):
		_handle_slot_time_limit()
		return

	if old_clock_minute != 获取当前钟表分钟总数():
		_emit_clock_changed()

func _handle_slot_time_limit() -> void:
	_slot_elapsed_minutes = float(获取当前时段总分钟())
	_emit_clock_changed()

	if _should_auto_advance():
		推进回合()
		return

	_is_waiting_for_confirm = true
	时段等待确认.emit(_current_slot, 获取时段名称())
	_log_time_state("时段等待确认")

func _get_current_flow_speed() -> float:
	match _flow_mode:
		FlowMode.NORMAL:
			return max(普通模式每秒推进分钟, 0.0)
		FlowMode.MARKET_FOCUS:
			return max(汇率专注每秒推进分钟, 0.0)
		_:
			return 0.0

func _should_auto_advance() -> bool:
	match _flow_mode:
		FlowMode.NORMAL:
			return 普通模式允许自动推进
		FlowMode.MARKET_FOCUS:
			return 汇率专注允许自动推进
		_:
			return false

func _set_flow_mode(mode: int) -> void:
	if _flow_mode == mode:
		return
	_flow_mode = mode
	时间流动模式变化.emit(_flow_mode)
	_log_time_state("时间流动模式变化")

## ===== 私有方法：日期计算 =====

func _advance_day() -> void:
	var old_month: int = _current_month
	var old_year: int = _current_year

	_current_day += 1
	if _current_day > 获取当月天数():
		_current_day = 1
		_current_month += 1
		if _current_month > 12:
			_current_month = 1
			_current_year += 1

	日期变化.emit(_current_year, _current_month, _current_day)
	新的一天开始.emit(_current_year, _current_month, _current_day)

	if old_month != _current_month or old_year != _current_year:
		月份变化.emit(_current_year, _current_month)

func _retreat_one_turn_for_debug() -> void:
	var old_slot: int = _current_slot
	var old_month: int = _current_month
	var old_year: int = _current_year

	_total_turns = max(_total_turns - 1, 0)
	_slot_elapsed_minutes = 0.0
	_is_waiting_for_confirm = false

	if _current_slot > TimeSlot.MORNING:
		_current_slot -= 1
	else:
		_retreat_day_for_debug()
		_current_slot = TimeSlot.LATE_NIGHT

	if old_slot != _current_slot:
		时段变化.emit(_current_slot, 获取时段名称())

	日期变化.emit(_current_year, _current_month, _current_day)
	if old_month != _current_month or old_year != _current_year:
		月份变化.emit(_current_year, _current_month)

	_emit_clock_changed()
	_log_time_state("调试回退回合")

func _retreat_day_for_debug() -> void:
	_current_day -= 1
	if _current_day >= 1:
		return

	_current_month -= 1
	if _current_month < 1:
		_current_month = 12
		_current_year = max(_current_year - 1, 1)

	_current_day = 获取当月天数(_current_year, _current_month)

func _set_date_safely(year: int, month: int, day: int, slot: int) -> void:
	_current_year = max(year, 1)
	_current_month = clampi(month, 1, 12)
	_current_day = clampi(day, 1, 获取当月天数(_current_year, _current_month))
	_current_slot = clampi(slot, 0, TURNS_PER_DAY - 1)

func _is_leap_year(year: int) -> bool:
	if year % 400 == 0:
		return true
	if year % 100 == 0:
		return false
	return year % 4 == 0

## ===== 私有方法：信号与日志 =====

func _emit_clock_changed() -> void:
	钟表时间变化.emit(
		获取当前钟表小时(),
		获取当前钟表分钟(),
		_slot_elapsed_minutes,
		获取当前时段总分钟()
	)

func _emit_all_time_changed() -> void:
	日期变化.emit(_current_year, _current_month, _current_day)
	时段变化.emit(_current_slot, 获取时段名称())
	_emit_clock_changed()

func _log_time_state(reason: String) -> void:
	if not 启用时间日志:
		return
	print("TimeSystem: ", reason, " → ", 获取时间文本(), " | 总回合 ", _total_turns)
