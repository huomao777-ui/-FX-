## 描述: 分钟级实时汇率引擎，基于市场状态生成盘中跳动报价
## 依赖: CurrencyState 数据由 MarketEngine 提供
## 状态: 第一阶段
## 最后更新: 2026-06-21
class_name MarketLiveQuoteEngine
extends RefCounted

const MINUTES_PER_DAY: int = 24 * 60

const DEFAULT_RULES := {
	"enabled": true,
	"minutes_per_tick": 1,
	"noise_scale": 0.35,
	"reversion_strength": 0.22,
	"max_deviation_ratio": 0.012
}

var _rules: Dictionary = DEFAULT_RULES.duplicate(true)
var _live_rates: Dictionary = {}
var _last_clock_minute: int = -1

func configure(config: Dictionary) -> void:
	_rules = DEFAULT_RULES.duplicate(true)
	for key in config.keys():
		_rules[key] = config[key]

func reset_from_states(currency_states: Dictionary, currency_order: Array[String]) -> void:
	_live_rates.clear()
	for code in currency_order:
		var state: CurrencyState = currency_states.get(code, null) as CurrencyState
		if state == null:
			continue
		_live_rates[code] = state.current_rate
	_last_clock_minute = -1

func sync_rates_to_states(currency_states: Dictionary, currency_order: Array[String]) -> void:
	for code in currency_order:
		var state: CurrencyState = currency_states.get(code, null) as CurrencyState
		if state == null:
			continue
		_live_rates[code] = state.current_rate

func apply_minute_tick(currency_states: Dictionary, currency_order: Array[String], rng: RandomNumberGenerator, clock_total_minutes: int) -> Array[String]:
	var changed_codes: Array[String] = []
	if not bool(_rules.get("enabled", true)):
		return changed_codes
	if clock_total_minutes == _last_clock_minute:
		return changed_codes
	var minutes_per_tick: int = max(int(_rules.get("minutes_per_tick", 1)), 1)
	if _last_clock_minute >= 0 and posmod(clock_total_minutes - _last_clock_minute, MINUTES_PER_DAY) < minutes_per_tick:
		return changed_codes
	_last_clock_minute = clock_total_minutes

	var noise_scale: float = max(float(_rules.get("noise_scale", 0.35)), 0.0)
	var reversion_strength: float = clampf(float(_rules.get("reversion_strength", 0.22)), 0.0, 1.0)
	var max_deviation_ratio: float = max(float(_rules.get("max_deviation_ratio", 0.012)), 0.0005)

	for code in currency_order:
		var state: CurrencyState = currency_states.get(code, null) as CurrencyState
		if state == null:
			continue
		var target_rate: float = max(state.current_rate, 0.000001)
		var live_rate: float = float(_live_rates.get(code, target_rate))
		var volatility: float = max(state.effective_volatility, 0.0001)
		var noise_delta: float = target_rate * volatility * noise_scale * rng.randfn(0.0, 1.0)
		var reversion_delta: float = (target_rate - live_rate) * reversion_strength
		var next_rate: float = live_rate + noise_delta + reversion_delta
		var max_deviation: float = max(target_rate * max_deviation_ratio, target_rate * volatility * 2.5)
		next_rate = clampf(next_rate, target_rate - max_deviation, target_rate + max_deviation)
		next_rate = max(next_rate, 0.000001)
		if not is_equal_approx(next_rate, live_rate):
			_live_rates[code] = next_rate
			changed_codes.append(code)
	return changed_codes

func get_rate(currency_code: String, fallback_rate: float) -> float:
	var live_rate: float = float(_live_rates.get(currency_code, fallback_rate))
	return live_rate if live_rate > 0.0 else fallback_rate

func collect_save_data() -> Dictionary:
	return {
		"live_rates": _live_rates.duplicate(true),
		"last_clock_minute": _last_clock_minute
	}

func restore_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	_live_rates = (data.get("live_rates", {}) as Dictionary).duplicate(true)
	_last_clock_minute = int(data.get("last_clock_minute", -1))
