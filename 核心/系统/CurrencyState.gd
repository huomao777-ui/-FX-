## 描述: 单个外币相对 RMB 的市场状态数据
## 依赖: MarketEngine 加载配置后创建
## 状态: 第一阶段
## 最后更新: 2026-06-12
class_name CurrencyState
extends RefCounted

const DEFAULT_EFFECTIVE_VOLATILITY: float = 0.0015
const DEFAULT_EMOTION_DECAY: float = 0.80

var code: String = ""
var display_name: String = ""
var reference_currency: String = ""
var volatility_profile: String = "标准"
var intervention_tendency: String = "中等干预"

var initial_rate: float = 1.0
var current_rate: float = 1.0
var fair_value: float = 1.0
var equilibrium_rate: float = 1.0
var emotion: float = 0.0
var structural_trade_bias_base: float = 0.0
var structural_trade_bias_effective: float = 0.0
var structural_trade_bias_smooth: float = 0.0
var exchange_rate_pressure: float = 0.0
var effective_volatility: float = DEFAULT_EFFECTIVE_VOLATILITY
var effective_emotion_decay: float = DEFAULT_EMOTION_DECAY
var foreign_interest_rate: float = 0.0
var interest_rate_diff: float = 0.0
var one_way_concentration: float = 0.5
var saturation: float = 0.5
var intervention_fail_count: int = 0
var intervention_aftershock_count: int = 0
var daily_open_rate: float = 1.0
var daily_cumulative_change: float = 0.0
var suspended_today: bool = false
var smooth_tsb_sum_60_days: float = 0.0
var smooth_tsb_sample_days: int = 0

static func from_config(config: Dictionary, rmb_interest_rate: float) -> CurrencyState:
	var state: CurrencyState = CurrencyState.new()
	state.code = str(config.get("code", ""))
	state.display_name = str(config.get("display_name", state.code))
	state.reference_currency = str(config.get("reference_currency", state.code))
	state.initial_rate = max(float(config.get("initial_rate", 1.0)), 0.000001)
	state.current_rate = state.initial_rate
	state.fair_value = state.initial_rate
	state.equilibrium_rate = state.initial_rate
	state.daily_open_rate = state.initial_rate
	state.structural_trade_bias_base = clampf(float(config.get("TSB0", 0.0)), -0.5, 0.5)
	state.structural_trade_bias_effective = state.structural_trade_bias_base
	state.structural_trade_bias_smooth = state.structural_trade_bias_base
	state.foreign_interest_rate = float(config.get("foreign_interest_rate", 0.0))
	state.interest_rate_diff = rmb_interest_rate - state.foreign_interest_rate
	state.volatility_profile = str(config.get("volatility_profile", "标准"))
	state.intervention_tendency = str(config.get("intervention_tendency", "中等干预"))
	state.effective_volatility = state.get_base_volatility()
	return state

func get_base_volatility() -> float:
	match volatility_profile:
		"趋势型":
			return 0.0018
		"跳跃型":
			return 0.0012
		_:
			return 0.0015

func begin_new_day() -> void:
	daily_open_rate = current_rate
	daily_cumulative_change = 0.0
	suspended_today = false
	smooth_tsb_sum_60_days += structural_trade_bias_smooth
	smooth_tsb_sample_days += 1

func collect_save_data() -> Dictionary:
	return {
		"code": code,
		"current_rate": current_rate,
		"fair_value": fair_value,
		"equilibrium_rate": equilibrium_rate,
		"emotion": emotion,
		"structural_trade_bias_effective": structural_trade_bias_effective,
		"structural_trade_bias_smooth": structural_trade_bias_smooth,
		"exchange_rate_pressure": exchange_rate_pressure,
		"effective_volatility": effective_volatility,
		"effective_emotion_decay": effective_emotion_decay,
		"interest_rate_diff": interest_rate_diff,
		"one_way_concentration": one_way_concentration,
		"saturation": saturation,
		"intervention_fail_count": intervention_fail_count,
		"intervention_aftershock_count": intervention_aftershock_count,
		"daily_open_rate": daily_open_rate,
		"daily_cumulative_change": daily_cumulative_change,
		"suspended_today": suspended_today,
		"smooth_tsb_sum_60_days": smooth_tsb_sum_60_days,
		"smooth_tsb_sample_days": smooth_tsb_sample_days
	}

func restore_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	current_rate = max(float(data.get("current_rate", current_rate)), 0.000001)
	fair_value = max(float(data.get("fair_value", fair_value)), 0.000001)
	equilibrium_rate = max(float(data.get("equilibrium_rate", equilibrium_rate)), 0.000001)
	emotion = clampf(float(data.get("emotion", emotion)), -100.0, 100.0)
	structural_trade_bias_effective = clampf(float(data.get("structural_trade_bias_effective", structural_trade_bias_effective)), -0.5, 0.5)
	structural_trade_bias_smooth = clampf(float(data.get("structural_trade_bias_smooth", structural_trade_bias_smooth)), -0.5, 0.5)
	exchange_rate_pressure = float(data.get("exchange_rate_pressure", exchange_rate_pressure))
	effective_volatility = max(float(data.get("effective_volatility", effective_volatility)), 0.0)
	effective_emotion_decay = clampf(float(data.get("effective_emotion_decay", effective_emotion_decay)), 0.0, 1.0)
	interest_rate_diff = float(data.get("interest_rate_diff", interest_rate_diff))
	one_way_concentration = clampf(float(data.get("one_way_concentration", one_way_concentration)), 0.0, 1.0)
	saturation = max(float(data.get("saturation", saturation)), 0.0)
	intervention_fail_count = clampi(int(data.get("intervention_fail_count", intervention_fail_count)), 0, 3)
	intervention_aftershock_count = clampi(int(data.get("intervention_aftershock_count", intervention_aftershock_count)), 0, 5)
	daily_open_rate = max(float(data.get("daily_open_rate", daily_open_rate)), 0.000001)
	daily_cumulative_change = absf(float(data.get("daily_cumulative_change", daily_cumulative_change)))
	suspended_today = bool(data.get("suspended_today", suspended_today))
	smooth_tsb_sum_60_days = float(data.get("smooth_tsb_sum_60_days", smooth_tsb_sum_60_days))
	smooth_tsb_sample_days = max(int(data.get("smooth_tsb_sample_days", smooth_tsb_sample_days)), 0)
