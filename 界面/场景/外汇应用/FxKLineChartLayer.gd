## 描述: 国内炒汇应用的 K 线画布绘制层，负责网格、K 线、成交量和周期切换
## 依赖: 父节点为 k线图画布；可选依赖 GameDataManager/MarketEngine
## 状态: 第一阶段
## 最后更新: 2026-06-12
class_name FxKLineChartLayer
extends Control

@export_group("行情")
## 默认显示货币代码，YHB 表示樱花币
@export var 默认货币代码: String = "YHB"
## 历史数据不足时自动生成的 K 线数量
@export var 演示K线数量: int = 64

@export_group("坐标轴")
## 右侧为未来行情预留的空白宽度，单位为 K 线根数
@export var 未来留白K线数: int = 6
## 价格轴分段数量
@export_range(3, 8, 1) var 价格轴分段数量: int = 4
## 底部时间坐标高度
@export var 时间坐标高度: float = 24.0

@export_group("绘制")
## 右侧价格坐标宽度
@export var 价格坐标宽度: float = 58.0
## 使用场景中预留的 k线图部分2 和 柱状图部分 作为绘制区域
@export var 使用预留画布区域: bool = true
## 顶部留白
@export var 顶部留白: float = 14.0
## 底部按钮区留白
@export var 底部按钮区留白: float = 48.0
## 柱状图区高度
@export var 柱状图区高度: float = 78.0
## K 线与柱状图间距
@export var 图区间距: float = 8.0
## 背景虚线颜色
@export var 虚线颜色: Color = Color(0.52, 0.74, 0.95, 0.22)
## 坐标文字颜色
@export var 坐标文字颜色: Color = Color(0.58, 0.79, 1.0, 0.82)
## 上涨颜色；本报价下表示 RMB 走强
@export var 上涨颜色: Color = Color(0.14, 0.86, 0.38, 0.95)
## 下跌颜色；本报价下表示 RMB 走弱、外币走强
@export var 下跌颜色: Color = Color(1.0, 0.23, 0.12, 0.95)

var _market_engine: Node = null
var _time_system: Node = null
var _timeframe: String = "一分钟"
var _candles: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 20260612
	_market_engine = get_node_or_null("/root/GameDataManager/MarketEngine")
	_time_system = get_node_or_null("/root/GameDataManager/TimeSystem")
	_generate_initial_candles()
	_connect_market_engine()
	queue_redraw()

func _draw() -> void:
	if _candles.is_empty():
		return
	var chart_rect: Rect2 = _get_chart_rect()
	var volume_rect: Rect2 = _get_volume_rect()
	if chart_rect.size.x <= 10.0 or chart_rect.size.y <= 10.0:
		return
	if volume_rect.size.x <= 10.0 or volume_rect.size.y <= 10.0:
		return

	_draw_grid(chart_rect, volume_rect)
	_draw_candles(chart_rect)
	_draw_volume(volume_rect)
	_draw_axis_labels(chart_rect, volume_rect)

func 设置周期(period_name: String) -> void:
	_timeframe = period_name
	_generate_initial_candles()
	queue_redraw()

func 获取周期() -> String:
	return _timeframe

func _connect_market_engine() -> void:
	if _market_engine == null or not _market_engine.has_signal("汇率变动"):
		return
	var callback: Callable = _on_market_rate_changed
	if not _market_engine.is_connected("汇率变动", callback):
		_market_engine.connect("汇率变动", callback)

func _on_market_rate_changed(currency_code: String, rate_snapshot: Dictionary) -> void:
	if currency_code != 默认货币代码:
		return
	var rate: float = float(rate_snapshot.get("rate", 0.0))
	if rate <= 0.0:
		return
	_append_live_price(rate)
	queue_redraw()

func _generate_initial_candles() -> void:
	_candles.clear()
	var base_rate: float = _get_current_market_rate()
	var profile: Dictionary = _get_timeframe_profile()
	var volatility: float = float(profile.get("volatility", 0.0012))
	var last_close: float = base_rate

	for i in range(max(演示K线数量, 12)):
		var drift: float = sin(float(i) * 0.21) * volatility * 0.35
		var shock: float = _rng.randfn(0.0, volatility)
		var open_price: float = last_close
		var close_price: float = max(open_price * (1.0 + drift + shock), 0.000001)
		var wick_scale: float = absf(_rng.randfn(volatility * 0.7, volatility * 0.35))
		var high_price: float = max(open_price, close_price) * (1.0 + wick_scale)
		var low_price: float = min(open_price, close_price) * max(1.0 - wick_scale, 0.000001)
		var volume: float = absf(_rng.randfn(1.0, 0.35)) * (1.0 + absf(close_price - open_price) / max(open_price, 0.000001) * 90.0)
		_candles.append(_make_candle(open_price, high_price, low_price, close_price, volume))
		last_close = close_price

func _append_live_price(rate: float) -> void:
	if _candles.is_empty():
		_generate_initial_candles()
		return
	var last: Dictionary = _candles[_candles.size() - 1]
	last["close"] = rate
	last["high"] = max(float(last.get("high", rate)), rate)
	last["low"] = min(float(last.get("low", rate)), rate)
	last["volume"] = float(last.get("volume", 1.0)) + 0.18
	_candles[_candles.size() - 1] = last

func _make_candle(open_price: float, high_price: float, low_price: float, close_price: float, volume: float) -> Dictionary:
	return {
		"open": open_price,
		"high": high_price,
		"low": low_price,
		"close": close_price,
		"volume": volume
	}

func _get_current_market_rate() -> float:
	if _market_engine != null and _market_engine.has_method("获取汇率"):
		var rate: float = float(_market_engine.call("获取汇率", 默认货币代码))
		if rate > 0.0:
			return rate
	match 默认货币代码:
		"YHB":
			return 20.0
		"USD":
			return 0.14
		"EUR":
			return 0.13
		_:
			return 1.0

func _get_timeframe_profile() -> Dictionary:
	match _timeframe:
		"一分钟":
			return {"count": 64, "volatility": 0.0008, "label": "1m", "unit": "m", "minutes": 1}
		"一小时":
			return {"count": 56, "volatility": 0.0014, "label": "1h", "unit": "h", "minutes": 60}
		"一天":
			return {"count": 48, "volatility": 0.0024, "label": "1d", "unit": "d", "minutes": 1440}
		"一周":
			return {"count": 42, "volatility": 0.0055, "label": "1w", "unit": "w", "minutes": 10080}
		"一月":
			return {"count": 36, "volatility": 0.0100, "label": "1M", "unit": "M", "minutes": 43200}
		"一年":
			return {"count": 30, "volatility": 0.0180, "label": "1Y", "unit": "Y", "minutes": 525600}
		_:
			return {"count": 64, "volatility": 0.0008, "label": "1m", "unit": "m", "minutes": 1}

func _get_chart_rect() -> Rect2:
	var reserved_rect: Rect2 = _get_reserved_plot_rect("k线图部分2")
	if 使用预留画布区域 and reserved_rect.size.x > 10.0 and reserved_rect.size.y > 10.0:
		return _with_price_axis_space(reserved_rect)
	var chart_height: float = max(size.y - 底部按钮区留白 - 时间坐标高度 - 柱状图区高度 - 图区间距 - 顶部留白, 40.0)
	return Rect2(
		Vector2(10.0, 顶部留白),
		Vector2(max(size.x - 价格坐标宽度 - 18.0, 40.0), chart_height)
	)

func _get_volume_rect() -> Rect2:
	var reserved_rect: Rect2 = _get_reserved_plot_rect("柱状图部分")
	if 使用预留画布区域 and reserved_rect.size.x > 10.0 and reserved_rect.size.y > 10.0:
		return _with_price_axis_space(reserved_rect)
	var chart_rect: Rect2 = _get_chart_rect()
	return Rect2(
		Vector2(chart_rect.position.x, chart_rect.end.y + 图区间距),
		Vector2(chart_rect.size.x, 柱状图区高度)
	)

func _get_reserved_plot_rect(node_name: String) -> Rect2:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return Rect2()
	var target: Control = _find_descendant_by_name(parent_node, node_name) as Control
	if target == null:
		return Rect2()
	return Rect2(target.position, target.size)

func _with_price_axis_space(rect: Rect2) -> Rect2:
	var horizontal_padding: float = 8.0
	var vertical_padding: float = 6.0
	return Rect2(
		rect.position + Vector2(horizontal_padding, vertical_padding),
		Vector2(
			max(rect.size.x - 价格坐标宽度 - horizontal_padding * 2.0, 20.0),
			max(rect.size.y - vertical_padding * 2.0, 20.0)
		)
	)

func _draw_grid(chart_rect: Rect2, volume_rect: Rect2) -> void:
	var price_axis: Dictionary = _get_price_axis_data(_get_visible_candles())
	var price_range: Vector2 = Vector2(float(price_axis.get("min", 0.0)), float(price_axis.get("max", 1.0)))
	for price in price_axis.get("labels", []):
		var y: float = _price_to_y(float(price), price_range, chart_rect)
		_draw_dashed_line(Vector2(chart_rect.position.x, y), Vector2(chart_rect.end.x, y), 虚线颜色)
	for i in range(6):
		var x: float = chart_rect.position.x + chart_rect.size.x * float(i) / 5.0
		_draw_dashed_line(Vector2(x, chart_rect.position.y), Vector2(x, volume_rect.end.y), 虚线颜色)
	_draw_dashed_line(Vector2(volume_rect.position.x, volume_rect.position.y), Vector2(volume_rect.end.x, volume_rect.position.y), 虚线颜色)

func _draw_candles(chart_rect: Rect2) -> void:
	var visible_candles: Array[Dictionary] = _get_visible_candles()
	var price_axis: Dictionary = _get_price_axis_data(visible_candles)
	var price_range: Vector2 = Vector2(float(price_axis.get("min", 0.0)), float(price_axis.get("max", 1.0)))
	var candle_gap: float = _get_candle_gap(chart_rect, visible_candles.size())
	var body_width: float = clampf(candle_gap * 0.56, 3.0, 12.0)

	for i in range(visible_candles.size()):
		var candle: Dictionary = visible_candles[i]
		var open_price: float = float(candle.get("open", 0.0))
		var high_price: float = float(candle.get("high", 0.0))
		var low_price: float = float(candle.get("low", 0.0))
		var close_price: float = float(candle.get("close", 0.0))
		var center_x: float = chart_rect.position.x + candle_gap * (float(i) + 0.5)
		var color: Color = 上涨颜色 if close_price >= open_price else 下跌颜色
		var high_y: float = _price_to_y(high_price, price_range, chart_rect)
		var low_y: float = _price_to_y(low_price, price_range, chart_rect)
		var open_y: float = _price_to_y(open_price, price_range, chart_rect)
		var close_y: float = _price_to_y(close_price, price_range, chart_rect)
		draw_line(Vector2(center_x, high_y), Vector2(center_x, low_y), color, 1.4)
		var body_top: float = min(open_y, close_y)
		var body_height: float = max(absf(open_y - close_y), 2.0)
		draw_rect(Rect2(Vector2(center_x - body_width * 0.5, body_top), Vector2(body_width, body_height)), color, true)

func _draw_volume(volume_rect: Rect2) -> void:
	var visible_candles: Array[Dictionary] = _get_visible_candles()
	var max_volume: float = 0.000001
	for candle in visible_candles:
		max_volume = max(max_volume, float(candle.get("volume", 0.0)))
	var candle_gap: float = _get_candle_gap(volume_rect, visible_candles.size())
	var bar_width: float = clampf(candle_gap * 0.56, 3.0, 12.0)
	for i in range(visible_candles.size()):
		var candle: Dictionary = visible_candles[i]
		var open_price: float = float(candle.get("open", 0.0))
		var close_price: float = float(candle.get("close", 0.0))
		var color: Color = 上涨颜色 if close_price >= open_price else 下跌颜色
		color.a = 0.42
		var bar_height: float = volume_rect.size.y * float(candle.get("volume", 0.0)) / max_volume
		var x: float = volume_rect.position.x + candle_gap * (float(i) + 0.5) - bar_width * 0.5
		draw_rect(Rect2(Vector2(x, volume_rect.end.y - bar_height), Vector2(bar_width, bar_height)), color, true)

func _draw_axis_labels(chart_rect: Rect2, volume_rect: Rect2) -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = 13
	var visible_candles: Array[Dictionary] = _get_visible_candles()
	var price_axis: Dictionary = _get_price_axis_data(visible_candles)
	var price_range: Vector2 = Vector2(float(price_axis.get("min", 0.0)), float(price_axis.get("max", 1.0)))
	for price in price_axis.get("labels", []):
		var y: float = _price_to_y(float(price), price_range, chart_rect) + 4.0
		draw_string(font, Vector2(chart_rect.end.x + 8.0, y), _format_price(float(price)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 坐标文字颜色)
	_draw_time_axis_labels(font, font_size, visible_candles, volume_rect)

func _draw_time_axis_labels(font: Font, font_size: int, visible_candles: Array[Dictionary], volume_rect: Rect2) -> void:
	if visible_candles.is_empty():
		return
	var label_count: int = 5
	var candle_gap: float = _get_candle_gap(volume_rect, visible_candles.size())
	var y: float = volume_rect.end.y + min(时间坐标高度, 20.0)
	for i in range(label_count):
		var candle_index: int = roundi(float(visible_candles.size() - 1) * float(i) / float(label_count - 1))
		var x: float = volume_rect.position.x + candle_gap * (float(candle_index) + 0.5)
		var label_text: String = _get_time_axis_text(visible_candles.size() - 1 - candle_index)
		draw_string(font, Vector2(x - 24.0, y), label_text, HORIZONTAL_ALIGNMENT_CENTER, 78.0, font_size, 坐标文字颜色)

func _get_time_axis_text(bars_ago: int) -> String:
	var time_stamp: Dictionary = _get_current_time_stamp()
	if not time_stamp.is_empty():
		var shifted_time: Dictionary = _shift_time_stamp(time_stamp, -bars_ago * _get_timeframe_minutes())
		return _format_time_axis_stamp(shifted_time)
	var profile: Dictionary = _get_timeframe_profile()
	if bars_ago <= 0:
		return "现在"
	return "-" + str(bars_ago) + str(profile.get("unit", ""))

func _get_timeframe_minutes() -> int:
	var profile: Dictionary = _get_timeframe_profile()
	return max(int(profile.get("minutes", 1)), 1)

func _get_current_time_stamp() -> Dictionary:
	if _time_system == null or not _time_system.has_method("获取当前日期数据"):
		return {}
	var date_data: Dictionary = _time_system.call("获取当前日期数据")
	return {
		"year": int(date_data.get("year", 2026)),
		"month": int(date_data.get("month", 1)),
		"day": int(date_data.get("day", 1)),
		"minute_of_day": int(date_data.get("clock_hour", 0)) * 60 + int(date_data.get("clock_minute", 0))
	}

func _shift_time_stamp(time_stamp: Dictionary, minute_delta: int) -> Dictionary:
	var result: Dictionary = time_stamp.duplicate()
	var total_minutes: int = int(result.get("minute_of_day", 0)) + minute_delta
	while total_minutes < 0:
		result = _shift_date(result, -1)
		total_minutes += 1440
	while total_minutes >= 1440:
		result = _shift_date(result, 1)
		total_minutes -= 1440
	result["minute_of_day"] = total_minutes
	return result

func _shift_date(time_stamp: Dictionary, day_delta: int) -> Dictionary:
	var result: Dictionary = time_stamp.duplicate()
	var year: int = int(result.get("year", 2026))
	var month: int = int(result.get("month", 1))
	var day: int = int(result.get("day", 1)) + day_delta
	while day < 1:
		month -= 1
		if month < 1:
			month = 12
			year -= 1
		day += _get_days_in_month(year, month)
	while day > _get_days_in_month(year, month):
		day -= _get_days_in_month(year, month)
		month += 1
		if month > 12:
			month = 1
			year += 1
	result["year"] = year
	result["month"] = month
	result["day"] = day
	return result

func _get_days_in_month(year: int, month: int) -> int:
	if _time_system != null and _time_system.has_method("获取当月天数"):
		return int(_time_system.call("获取当月天数", year, month))
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			return 29 if _is_leap_year(year) else 28
		_:
			return 30

func _is_leap_year(year: int) -> bool:
	if year % 400 == 0:
		return true
	if year % 100 == 0:
		return false
	return year % 4 == 0

func _format_time_axis_stamp(time_stamp: Dictionary) -> String:
	var minute_of_day: int = int(time_stamp.get("minute_of_day", 0))
	var hour: int = int(minute_of_day / 60)
	var minute: int = minute_of_day % 60
	var timeframe_minutes: int = _get_timeframe_minutes()
	if timeframe_minutes < 1440:
		return "%02d:%02d" % [hour, minute]
	if timeframe_minutes < 10080:
		return "%d日%02d:%02d" % [int(time_stamp.get("day", 1)), hour, minute]
	return "%d月%d日" % [int(time_stamp.get("month", 1)), int(time_stamp.get("day", 1))]

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, dash_length: float = 6.0, gap_length: float = 5.0) -> void:
	var direction: Vector2 = to - from
	var length: float = direction.length()
	if length <= 0.0:
		return
	var normal: Vector2 = direction / length
	var distance: float = 0.0
	while distance < length:
		var segment_end: float = min(distance + dash_length, length)
		draw_line(from + normal * distance, from + normal * segment_end, color, 1.0)
		distance += dash_length + gap_length

func _get_visible_candles() -> Array[Dictionary]:
	var profile: Dictionary = _get_timeframe_profile()
	var count: int = min(int(profile.get("count", 64)), _candles.size())
	var result: Array[Dictionary] = []
	for i in range(_candles.size() - count, _candles.size()):
		result.append(_candles[i])
	return result

func _get_candle_gap(draw_rect: Rect2, visible_count: int) -> float:
	return draw_rect.size.x / float(max(visible_count + max(未来留白K线数, 0), 1))

func _get_price_range(candles: Array[Dictionary]) -> Vector2:
	var min_price: float = INF
	var max_price: float = -INF
	for candle in candles:
		min_price = min(min_price, float(candle.get("low", 0.0)))
		max_price = max(max_price, float(candle.get("high", 0.0)))
	if min_price == INF or max_price == -INF or is_equal_approx(min_price, max_price):
		var base_rate: float = _get_current_market_rate()
		min_price = base_rate * 0.995
		max_price = base_rate * 1.005
	var padding: float = max((max_price - min_price) * 0.08, max_price * 0.0002)
	return Vector2(min_price - padding, max_price + padding)

func _get_price_axis_data(candles: Array[Dictionary]) -> Dictionary:
	var raw_range: Vector2 = _get_price_range(candles)
	var raw_span: float = max(raw_range.y - raw_range.x, 0.000001)
	var step: float = _get_nice_tick_step(raw_span / float(max(价格轴分段数量, 1)))
	var axis_min: float = floor(raw_range.x / step) * step
	var axis_max: float = ceil(raw_range.y / step) * step
	var labels: Array[float] = []
	var value: float = axis_min
	var guard: int = 0
	while value <= axis_max + step * 0.5 and guard < 16:
		labels.append(value)
		value += step
		guard += 1
	return {
		"min": axis_min,
		"max": axis_max,
		"step": step,
		"labels": labels
	}

func _get_nice_tick_step(raw_step: float) -> float:
	var safe_step: float = max(raw_step, 0.000001)
	var exponent: float = floor(log(safe_step) / log(10.0))
	var magnitude: float = pow(10.0, exponent)
	var normalized: float = safe_step / magnitude
	if normalized <= 1.0:
		return magnitude
	if normalized <= 2.0:
		return 2.0 * magnitude
	if normalized <= 5.0:
		return 5.0 * magnitude
	return 10.0 * magnitude

func _price_to_y(price: float, price_range: Vector2, chart_rect: Rect2) -> float:
	var ratio: float = (price - price_range.x) / max(price_range.y - price_range.x, 0.000001)
	return chart_rect.end.y - chart_rect.size.y * clampf(ratio, 0.0, 1.0)

func _format_price(value: float) -> String:
	if value >= 10.0:
		return "%.3f" % value
	return "%.5f" % value

func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var result: Node = _find_descendant_by_name(child, target_name)
		if result != null:
			return result
	return null
