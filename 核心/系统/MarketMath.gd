## 描述: 汇率市场第一阶段的纯数学工具
## 依赖: CurrencyState
## 状态: 第一阶段
## 最后更新: 2026-06-12
class_name MarketMath
extends RefCounted

static func calculate_regression_strength(pressure_abs: float) -> float:
	if pressure_abs < 0.01:
		return 0.05
	if pressure_abs < 0.03:
		return 0.10
	if pressure_abs < 0.05:
		return 0.18
	return 0.25

static func update_pressure_and_tsb(state: CurrencyState) -> void:
	state.exchange_rate_pressure = (state.current_rate - state.equilibrium_rate) / max(state.equilibrium_rate, 0.000001)
	state.structural_trade_bias_effective = clampf(
		state.structural_trade_bias_base - state.exchange_rate_pressure * 0.15,
		-0.5,
		0.5
	)
	state.structural_trade_bias_smooth = state.structural_trade_bias_smooth * 0.95 + state.structural_trade_bias_effective * 0.05

static func update_fair_value(state: CurrencyState, fair_value_noise: float) -> void:
	var drift: float = state.structural_trade_bias_smooth * 0.0005 + fair_value_noise * 0.0008
	state.fair_value = max(state.fair_value * (1.0 + drift), 0.000001)

static func update_equilibrium_rate_if_needed(state: CurrencyState, total_days: int) -> void:
	if total_days <= 0 or total_days % 60 != 0:
		return
	if state.smooth_tsb_sample_days <= 0:
		return
	var average_tsb: float = state.smooth_tsb_sum_60_days / float(state.smooth_tsb_sample_days)
	state.equilibrium_rate = max(state.equilibrium_rate * (1.0 + average_tsb * 0.01), 0.000001)
	state.smooth_tsb_sum_60_days = 0.0
	state.smooth_tsb_sample_days = 0

static func update_emotion(state: CurrencyState, random_noise: float) -> void:
	var shock: float = random_noise * 0.2
	state.emotion = clampf(state.emotion * state.effective_emotion_decay + shock, -100.0, 100.0)

static func try_extreme_emotion_reversal(state: CurrencyState, rng: RandomNumberGenerator) -> void:
	var emotion_abs: float = absf(state.emotion)
	if emotion_abs <= 80.0:
		return
	var reversal_probability: float = clampf((emotion_abs - 80.0) * 0.05, 0.0, 1.0)
	if rng.randf() > reversal_probability:
		return
	if state.emotion > 0.0:
		state.emotion = rng.randf_range(-40.0, -20.0)
	else:
		state.emotion = rng.randf_range(20.0, 40.0)

static func calculate_turn_rate_delta(state: CurrencyState, random_noise: float) -> Dictionary:
	if state.suspended_today:
		return {
			"base_delta": 0.0,
			"fair_value_delta": 0.0,
			"total_delta": 0.0
		}

	var emotion_component: float = clampf(state.emotion / 100.0 * 0.6, -1.0, 1.0)
	var base_delta: float = state.current_rate * state.effective_volatility * (emotion_component + random_noise * 0.4)
	var pressure_abs: float = absf((state.current_rate - state.fair_value) / max(state.fair_value, 0.000001))
	var regression_strength: float = calculate_regression_strength(pressure_abs)
	var fair_value_delta: float = (state.fair_value - state.current_rate) * regression_strength
	return {
		"base_delta": base_delta,
		"fair_value_delta": fair_value_delta,
		"total_delta": base_delta + fair_value_delta
	}

static func apply_circuit_breaker(state: CurrencyState) -> void:
	state.daily_cumulative_change = absf((state.current_rate - state.daily_open_rate) / max(state.daily_open_rate, 0.000001))
	if state.daily_cumulative_change > 0.15:
		state.suspended_today = true
		return
	if state.daily_cumulative_change > 0.08:
		state.effective_volatility = min(state.effective_volatility, 0.0005)
	else:
		state.effective_volatility = state.get_base_volatility()
