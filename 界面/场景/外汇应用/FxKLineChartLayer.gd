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
## 上涨颜色；按国内看盘习惯使用红色
@export var 上涨颜色: Color = Color(0.93, 0.24, 0.18, 0.95)
## 下跌颜色；按国内看盘习惯使用绿色
@export var 下跌颜色: Color = Color(0.14, 0.76, 0.34, 0.95)

var _market_engine: Node = null
var _time_system: Node = null
var _timeframe: String = "一分钟"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _left_currency_code: String = "XMY"
var _right_currency_code: String = ""
var _pair_label: String = ""
var _series_by_timeframe: Dictionary = {}
var _last_bucket_keys: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 20260612
	_market_engine = get_node_or_null("/root/GameDataManager/MarketEngine")
	_time_system = get_node_or_null("/root/GameDataManager/TimeSystem")
	_right_currency_code = 默认货币代码
	_pair_label = "XMY/" + 默认货币代码
	_initialize_timeframe_series()
	_connect_market_engine()
	queue_redraw()

func _draw() -> void:
	var chart_rect: Rect2 = _get_chart_rect()
	var volume_rect: Rect2 = _get_volume_rect()
	if chart_rect.size.x <= 10.0 or chart_rect.size.y <= 10.0:
		return
	if volume_rect.size.x <= 10.0 or volume_rect.size.y <= 10.0:
		return

	var has_active_pair: bool = _has_active_pair()
	var visible_candles: Array = _get_visible_candles()
	var axis_reference_candles: Array = _get_axis_reference_candles(visible_candles)
	var price_axis: Dictionary = _get_price_axis_data(axis_reference_candles)
	if has_active_pair and not visible_candles.is_empty():
		_draw_candles(chart_rect)
		_draw_volume(volume_rect)
	_draw_grid(chart_rect, volume_rect, price_axis)
	_draw_axis_labels(chart_rect, volume_rect, axis_reference_candles, price_axis, has_active_pair)

func 设置周期(period_name: String) -> void:
	_timeframe = period_name
	queue_redraw()

func 获取周期() -> String:
	return _timeframe

func 切换货币对(left_code: String, right_code: String, pair_label: String = "") -> void:
	_left_currency_code = left_code
	_right_currency_code = right_code
	默认货币代码 = right_code
	_pair_label = pair_label if not pair_label.is_empty() else left_code + "/" + right_code
	if _left_currency_code.is_empty() or _right_currency_code.is_empty():
		_series_by_timeframe.clear()
		_last_bucket_keys.clear()
		queue_redraw()
		return
	_initialize_timeframe_series()
	queue_redraw()

func _connect_market_engine() -> void:
	if _market_engine == null or not _market_engine.has_signal("汇率变动"):
		return
	var callback: Callable = _on_market_rate_changed
	if not _market_engine.is_connected("汇率变动", callback):
		_market_engine.connect("汇率变动", callback)

func _on_market_rate_changed(currency_code: String, rate_snapshot: Dictionary) -> void:
	if _left_currency_code.is_empty() or _right_currency_code.is_empty():
		return
	if currency_code != _left_currency_code and currency_code != _right_currency_code and currency_code != 默认货币代码:
		return
	var rate: float = _get_current_market_rate()
	if rate <= 0.0:
		return
	_apply_live_rate_to_all_series(rate)
	queue_redraw()

func _initialize_timeframe_series() -> void:
	_series_by_timeframe.clear()
	_last_bucket_keys.clear()
	var base_rate: float = _get_current_market_rate()
	for timeframe_name in _get_supported_timeframes():
		var profile: Dictionary = _get_timeframe_profile(timeframe_name)
		_series_by_timeframe[timeframe_name] = _build_seed_series(base_rate, profile)
		_last_bucket_keys[timeframe_name] = _get_time_bucket_key(int(profile.get("minutes", 1)))

func _build_seed_series(base_rate: float, profile: Dictionary) -> Array[Dictionary]:
	var series: Array[Dictionary] = []
	var volatility: float = float(profile.get("volatility", 0.0012))
	var count: int = max(int(profile.get("count", 演示K线数量)), 12)
	var last_close: float = max(base_rate, 0.000001)
	for i in range(count):
		var drift: float = sin(float(i) * 0.21) * volatility * 0.35
		var shock: float = _rng.randfn(0.0, volatility)
		var open_price: float = last_close
		var close_price: float = max(open_price * (1.0 + drift + shock), 0.000001)
		var wick_scale: float = absf(_rng.randfn(volatility * 0.7, volatility * 0.35))
		var high_price: float = max(open_price, close_price) * (1.0 + wick_scale)
		var low_price: float = min(open_price, close_price) * max(1.0 - wick_scale, 0.000001)
		var wick_padding: float = max(open_price * volatility * 0.22, open_price * 0.00012)
		high_price = max(high_price, max(open_price, close_price) + wick_padding)
		low_price = min(low_price, min(open_price, close_price) - wick_padding)
		low_price = max(low_price, 0.000001)
		var volume: float = absf(_rng.randfn(1.0, 0.35)) * (1.0 + absf(close_price - open_price) / max(open_price, 0.000001) * 90.0)
		series.append(_make_candle(open_price, high_price, low_price, close_price, volume))
		last_close = close_price
	if not series.is_empty():
		var last_candle: Dictionary = series[series.size() - 1]
		last_candle["close"] = base_rate
		last_candle["high"] = max(float(last_candle.get("high", base_rate)), base_rate)
		last_candle["low"] = min(float(last_candle.get("low", base_rate)), base_rate)
		last_candle = _ensure_visible_wicks(last_candle)
		series[series.size() - 1] = last_candle
	return series

func _apply_live_rate_to_all_series(rate: float) -> void:
	for timeframe_name in _get_supported_timeframes():
		var profile: Dictionary = _get_timeframe_profile(timeframe_name)
		var bucket_key: int = _get_time_bucket_key(int(profile.get("minutes", 1)))
		var series: Array[Dictionary] = _series_by_timeframe.get(timeframe_name, []) as Array[Dictionary]
		if series.is_empty():
			series = _build_seed_series(rate, profile)
		var last_bucket_key: int = int(_last_bucket_keys.get(timeframe_name, bucket_key))
		if bucket_key != last_bucket_key:
			var previous_close: float = float(series[series.size() - 1].get("close", rate))
			var fresh_candle: Dictionary = _make_candle(previous_close, max(previous_close, rate), min(previous_close, rate), rate, 1.0)
			series.append(_ensure_visible_wicks(fresh_candle))
			var max_count: int = max(int(profile.get("count", 演示K线数量)), 12)
			while series.size() > max_count:
				series.remove_at(0)
			_last_bucket_keys[timeframe_name] = bucket_key
		else:
			var last: Dictionary = series[series.size() - 1]
			last["close"] = rate
			last["high"] = max(float(last.get("high", rate)), rate)
			last["low"] = min(float(last.get("low", rate)), rate)
			last["volume"] = float(last.get("volume", 1.0)) + 0.18
			series[series.size() - 1] = _ensure_visible_wicks(last)
		_series_by_timeframe[timeframe_name] = series

func _make_candle(open_price: float, high_price: float, low_price: float, close_price: float, volume: float) -> Dictionary:
	return {
		"open": open_price,
		"high": high_price,
		"low": low_price,
		"close": close_price,
		"volume": volume
	}

func _get_current_market_rate() -> float:
	var pair_rate: float = _get_pair_rate(_left_currency_code, _right_currency_code)
	if pair_rate > 0.0:
		return pair_rate
	match _right_currency_code:
		"YHB":
			return 20.0
		"USD":
			return 0.14
		"EUR":
			return 0.13
		"GBP":
			return 0.11
		"DSB":
			return 0.21
		"FYB":
			return 0.19
		_:
			return 1.0

func _get_pair_rate(left_code: String, right_code: String) -> float:
	var left_rate: float = _get_rate_against_xmy(left_code)
	var right_rate: float = _get_rate_against_xmy(right_code)
	if left_rate <= 0.0 or right_rate <= 0.0:
		return 0.0
	return right_rate / left_rate

func _get_rate_against_xmy(currency_code: String) -> float:
	if currency_code == "XMY":
		return 1.0
	if _market_engine != null and _market_engine.has_method("获取汇率"):
		var rate: float = float(_market_engine.call("获取汇率", currency_code))
		if rate > 0.0:
			return rate
	return 0.0

func _get_supported_timeframes() -> Array[String]:
	return ["一分钟", "一小时", "一天", "一周", "一月", "一年"]

func _get_timeframe_profile(target_timeframe: String = "") -> Dictionary:
	var timeframe_name: String = target_timeframe if not target_timeframe.is_empty() else _timeframe
	match timeframe_name:
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

func _draw_grid(chart_rect: Rect2, volume_rect: Rect2, price_axis: Dictionary) -> void:
	var segment_count: int = max(int(price_axis.get("segment_count", 价格轴分段数量)), 1)
	var horizontal_line_positions: Array = _get_price_axis_line_positions(chart_rect, segment_count)
	for y in horizontal_line_positions:
		_draw_dashed_line(Vector2(chart_rect.position.x, y), Vector2(chart_rect.end.x, y), 虚线颜色)
	for i in range(6):
		var x: float = chart_rect.position.x + chart_rect.size.x * float(i) / 5.0
		_draw_dashed_line(Vector2(x, chart_rect.position.y), Vector2(x, volume_rect.end.y), 虚线颜色)

func _draw_candles(chart_rect: Rect2) -> void:
	var visible_candles: Array = _get_visible_candles()
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
		var body_top: float = min(open_y, close_y)
		var body_bottom: float = max(open_y, close_y)
		var body_height: float = max(absf(open_y - close_y), 2.0)
		var is_rise: bool = close_price >= open_price
		var is_doji: bool = absf(close_price - open_price) / max(max(absf(open_price), absf(close_price)), 0.000001) <= 0.0002
		draw_line(Vector2(center_x, high_y), Vector2(center_x, body_top), color, 1.4)
		draw_line(Vector2(center_x, body_bottom), Vector2(center_x, low_y), color, 1.4)
		var body_rect := Rect2(Vector2(center_x - body_width * 0.5, body_top), Vector2(body_width, body_height))
		if is_doji:
			var mid_y: float = (open_y + close_y) * 0.5
			draw_line(Vector2(body_rect.position.x, mid_y), Vector2(body_rect.end.x, mid_y), color, 1.8)
		elif is_rise:
			draw_rect(body_rect, Color(0, 0, 0, 0), true)
			draw_rect(body_rect, color, false, 1.6)
		else:
			draw_rect(body_rect, color, true)

func _draw_volume(volume_rect: Rect2) -> void:
	var visible_candles: Array = _get_visible_candles()
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

func _draw_axis_labels(chart_rect: Rect2, volume_rect: Rect2, visible_candles: Array, price_axis: Dictionary, has_active_pair: bool) -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = 13
	var labels: Array = price_axis.get("labels", []) as Array
	var segment_count: int = max(labels.size() - 1, 1)
	var horizontal_line_positions: Array = _get_price_axis_line_positions(chart_rect, segment_count)
	for index in range(labels.size()):
		var y: float = float(horizontal_line_positions[min(index, horizontal_line_positions.size() - 1)]) + 4.0
		var price_text: String = _format_price(float(labels[index])) if has_active_pair else "--"
		draw_string(font, Vector2(chart_rect.end.x + 8.0, y), price_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 坐标文字颜色)
	_draw_time_axis_labels(font, font_size, visible_candles, volume_rect)

func _draw_time_axis_labels(font: Font, font_size: int, visible_candles: Array, volume_rect: Rect2) -> void:
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
	if absf(from.y - to.y) <= 0.01:
		var start_x: float = min(from.x, to.x)
		var end_x: float = max(from.x, to.x)
		var y: float = roundf(from.y)
		var cursor_x: float = start_x
		while cursor_x < end_x:
			var dash_end_x: float = min(cursor_x + dash_length, end_x)
			draw_rect(Rect2(Vector2(cursor_x, y), Vector2(max(dash_end_x - cursor_x, 1.0), 1.0)), color, true)
			cursor_x += dash_length + gap_length
		return
	if absf(from.x - to.x) <= 0.01:
		var start_y: float = min(from.y, to.y)
		var end_y: float = max(from.y, to.y)
		var x: float = roundf(from.x)
		var cursor_y: float = start_y
		while cursor_y < end_y:
			var dash_end_y: float = min(cursor_y + dash_length, end_y)
			draw_rect(Rect2(Vector2(x, cursor_y), Vector2(1.0, max(dash_end_y - cursor_y, 1.0))), color, true)
			cursor_y += dash_length + gap_length
		return
	var normal: Vector2 = direction / length
	var distance: float = 0.0
	while distance < length:
		var segment_end: float = min(distance + dash_length, length)
		draw_line(from + normal * distance, from + normal * segment_end, color, 1.0)
		distance += dash_length + gap_length

func _get_price_axis_line_positions(chart_rect: Rect2, segment_count: int) -> Array:
	var positions: Array = []
	var safe_segment_count: int = max(segment_count, 1)
	var raw_bottom_y: float = chart_rect.end.y - 1.0
	var raw_top_y: float = chart_rect.position.y
	var min_y: float = roundf(raw_top_y) + 0.5
	var max_y: float = roundf(raw_bottom_y) + 0.5
	for index in range(safe_segment_count + 1):
		var ratio: float = float(index) / float(safe_segment_count)
		var raw_y: float = lerpf(raw_bottom_y, raw_top_y, ratio)
		var snapped_y: float = clampf(roundf(raw_y) + 0.5, min_y, max_y)
		positions.append(snapped_y)
	return positions

func _get_visible_candles() -> Array:
	var series: Array = _series_by_timeframe.get(_timeframe, []) as Array
	return series.duplicate(true)

func _get_axis_reference_candles(visible_candles: Array) -> Array:
	if not visible_candles.is_empty():
		return visible_candles
	var placeholder_candles: Array = []
	for i in range(24):
		placeholder_candles.append(_make_candle(1.0, 1.0, 1.0, 1.0, 0.0))
	return placeholder_candles

func _has_active_pair() -> bool:
	return not _left_currency_code.is_empty() and not _right_currency_code.is_empty()

func _get_time_bucket_key(interval_minutes: int) -> int:
	var safe_interval: int = max(interval_minutes, 1)
	var time_stamp: Dictionary = _get_current_time_stamp()
	if time_stamp.is_empty():
		return 0
	var absolute_minutes: int = _days_from_civil(
		int(time_stamp.get("year", 2026)),
		int(time_stamp.get("month", 1)),
		int(time_stamp.get("day", 1))
	) * 1440 + int(time_stamp.get("minute_of_day", 0))
	return int(floor(float(absolute_minutes) / float(safe_interval)))

func _days_from_civil(year: int, month: int, day: int) -> int:
	var adjusted_year: int = year - (1 if month <= 2 else 0)
	var era: int = floori(float(adjusted_year) / 400.0)
	var year_of_era: int = adjusted_year - era * 400
	var adjusted_month: int = month - 3 if month > 2 else month + 9
	var day_of_year: int = int((153 * adjusted_month + 2) / 5) + day - 1
	var day_of_era: int = year_of_era * 365 + int(year_of_era / 4) - int(year_of_era / 100) + day_of_year
	return era * 146097 + day_of_era - 719468

func _get_candle_gap(draw_rect: Rect2, visible_count: int) -> float:
	return draw_rect.size.x / float(max(visible_count + max(未来留白K线数, 0), 1))

func _get_price_range(candles: Array) -> Vector2:
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

func _get_price_axis_data(candles: Array) -> Dictionary:
	var raw_range: Vector2 = _get_price_range(candles)
	var raw_span: float = max(raw_range.y - raw_range.x, 0.000001)
	var segment_count: int = max(价格轴分段数量, 1)
	var step: float = _get_nice_tick_step(raw_span / float(segment_count))
	var axis_min: float = floor(raw_range.x / step) * step
	var axis_max: float = axis_min + step * float(segment_count)
	if axis_max < raw_range.y:
		axis_max = ceil(raw_range.y / step) * step
		axis_min = axis_max - step * float(segment_count)
	var labels: Array[float] = []
	for index in range(segment_count + 1):
		var value: float = axis_min + step * float(index)
		labels.append(value)
	return {
		"min": axis_min,
		"max": axis_max,
		"step": step,
		"segment_count": segment_count,
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

func _ensure_visible_wicks(candle: Dictionary) -> Dictionary:
	var open_price: float = float(candle.get("open", 0.0))
	var close_price: float = float(candle.get("close", 0.0))
	var high_price: float = float(candle.get("high", max(open_price, close_price)))
	var low_price: float = float(candle.get("low", min(open_price, close_price)))
	var reference_price: float = max(max(open_price, close_price), 0.000001)
	var wick_padding: float = max(reference_price * 0.00015, 0.00001)
	high_price = max(high_price, max(open_price, close_price) + wick_padding)
	low_price = min(low_price, min(open_price, close_price) - wick_padding)
	candle["high"] = high_price
	candle["low"] = max(low_price, 0.000001)
	return candle

func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child in root.get_children():
		var result: Node = _find_descendant_by_name(child, target_name)
		if result != null:
			return result
	return null
