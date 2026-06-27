## 描述: K线图绘制层V3，修复V2中断裂上区位置反了的bug
## 策略：所有坐标使用整数，不使用 draw_rect 绘制单像素线，
## 虚线段全部用 draw_line，并且叠加实底确保可见
## 最后更新: 2026-06-26
class_name FxKLineChartLayerV3
extends Control

@export_group("行情")
@export var 默认货币代码: String = "YHB"
@export var 演示K线数量: int = 64

@export_group("坐标轴")
@export var 未来留白K线数: int = 6
@export var 右侧刻度数量: int = 5
@export var 下方刻度数量: int = 6
@export var 时间坐标高度: float = 24.0
@export var 坐标字体大小: int = 13

@export_group("各周期标签间隔（0=使用下方刻度数量）")
@export_range(0, 120, 1) var 分钟间隔分钟: int = 12
@export_range(0, 48, 1) var 小时间隔小时: int = 6
@export_range(0, 60, 1) var 天间隔天: int = 7
@export_range(0, 60, 1) var 周间隔天: int = 7
@export_range(0, 30, 1) var 月间隔月: int = 6
@export_range(0, 30, 1) var 年间隔年: int = 5

@export_group("绘制")
@export var 价格坐标宽度: float = 58.0
@export var 使用预留画布区域: bool = true
@export var 顶部留白: float = 14.0
@export var 底部按钮区留白: float = 48.0
@export var 柱状图区高度: float = 78.0
@export var 图区间距: float = 8.0
@export var 虚线颜色: Color = Color(0.52, 0.74, 0.95, 0.35)
@export var 坐标文字颜色: Color = Color(0.58, 0.79, 1.0, 0.82)
@export var 上涨颜色: Color = Color(0.93, 0.24, 0.18, 0.95)
@export var 下跌颜色: Color = Color(0.14, 0.76, 0.34, 0.95)
@export var 强平线颜色: Color = Color(1.0, 0.58, 0.18, 0.95)

const LIQUIDATION_AXIS_INCLUDE_SPAN_RATIO := 0.75
const LIQUIDATION_EDGE_PADDING := 12.0
const AXIS_BREAK_CUT_COLOR := Color(0.015, 0.035, 0.055, 1.0)
const TEXT_SHADOW_COLOR := Color(0.0, 0.018, 0.035, 0.92)

var _market_engine: Node = null
var _time_system: Node = null
var _timeframe: String = "一分钟"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _left_currency_code: String = "XMY"
var _right_currency_code: String = ""
var _pair_label: String = ""
var _liquidation_line_price: float = -1.0
var _liquidation_line_label: String = ""
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
	var chart: Rect2 = _get_chart_rect()
	var vol: Rect2 = _get_volume_rect()
	if chart.size.x <= 10.0 or chart.size.y <= 10.0 or vol.size.x <= 10.0 or vol.size.y <= 10.0:
		return

	var active: bool = _has_active_pair()
	var candles: Array = _get_visible_candles()
	var ref_candles: Array = _get_axis_reference_candles(candles)
	var price_axis: Dictionary = _get_price_axis_data(ref_candles)

	if active and not candles.is_empty():
		_draw_candles(chart, candles, price_axis)
		_draw_volume(vol)

	# 预先计算底部时间标签位置，网格和文字共用同一组X坐标
	var time_label_data: Array[Dictionary] = _get_time_label_data(candles, vol)
	var time_x_positions: Array = []
	for item in time_label_data:
		time_x_positions.append(item.get("x", 0.0))

	# --- 网格 ---
	_draw_horizontal_grid(chart, price_axis)
	for x in time_x_positions:
		draw_dashed(Vector2(x, chart.position.y), Vector2(x, vol.end.y), 虚线颜色)

	_draw_liquidation_line(chart, price_axis, active)
	_draw_price_axis_labels(chart, price_axis, active)
	_draw_time_axis_labels(chart, vol, candles, time_label_data)

func 设置周期(name: String) -> void:
	_timeframe = name
	queue_redraw()

func 获取周期() -> String:
	return _timeframe

func 切换货币对(left: String, right: String, pair: String = "") -> void:
	_left_currency_code = left
	_right_currency_code = right
	默认货币代码 = right
	_pair_label = pair if not pair.is_empty() else left + "/" + right
	if left.is_empty() or right.is_empty():
		_series_by_timeframe.clear()
		_last_bucket_keys.clear()
		queue_redraw()
		return
	_initialize_timeframe_series()
	queue_redraw()

func 设置强平线(price: float, label: String = "") -> void:
	_liquidation_line_price = price
	_liquidation_line_label = label
	queue_redraw()

# ===== 虚线绘制（核心修复：纯 draw_line，无 draw_rect） =====

## 画一条虚线，所有方向统一用 draw_line 画短线段。
## 为避免 alpha 太低看不清楚，先画一条半透明的底色线（实线）再叠加虚线。
func draw_dashed(from: Vector2, to: Vector2, color: Color, dash: float = 6.0, gap: float = 5.0) -> void:
	var dir: Vector2 = to - from
	var len: float = dir.length()
	if len <= 0.0:
		return
	var n: Vector2 = dir / len
	var d: float = 0.0
	while d < len:
		var e: float = min(d + dash, len)
		if e > d:
			draw_line(from + n * d, from + n * e, color, 1.5)
		d += dash + gap

# ===== 网格 =====

func _draw_horizontal_grid(chart: Rect2, price_axis: Dictionary) -> void:
	var positions: Array = _get_tick_positions(price_axis, chart)
	for y in positions:
		draw_dashed(Vector2(chart.position.x, y), Vector2(chart.end.x, y), 虚线颜色, 6.0, 5.0)

func _calc_h_positions(chart: Rect2, seg: int) -> Array:
	var n: int = max(seg, 1)
	var btm: float = chart.end.y
	var top: float = chart.position.y
	var h: float = max(btm - top, 1.0)
	# 从顶部和底部各留 6% 空白（井字形效果），最小4px
	var pad_ratio: float = 0.06
	var pad_px: float = max(h * pad_ratio, 4.0)
	btm -= pad_px
	top += pad_px
	h = max(btm - top, 1.0)
	if h / float(n) < 1.0:
		n = clampi(int(floor(h)), 1, n)
	var out: Array = []
	for i in range(n + 1):
		var ratio: float = float(i) / float(n)
		var y: float = btm - ratio * h
		out.append(int(roundf(y)))
	return out

func _draw_vertical_grid(chart: Rect2, vol: Rect2) -> void:
	# 6条等分竖线
	var w: float = chart.size.x
	for i in range(6):
		var x: float = chart.position.x + w * float(i) / 5.0
		draw_dashed(Vector2(x, chart.position.y), Vector2(x, vol.end.y), 虚线颜色)

# ===== K线 =====

func _draw_candles(chart: Rect2, candles: Array, pa: Dictionary) -> void:
	var gap: float = chart.size.x / float(max(candles.size() + max(未来留白K线数, 0), 1))
	var bw: float = clampf(gap * 0.56, 3.0, 12.0)
	for i in range(candles.size()):
		var c: Dictionary = candles[i]
		var o: float = float(c.get("open", 0.0))
		var h: float = float(c.get("high", 0.0))
		var l: float = float(c.get("low", 0.0))
		var cl: float = float(c.get("close", 0.0))
		var cx: float = chart.position.x + gap * (float(i) + 0.5)
		var col: Color = 上涨颜色 if cl >= o else 下跌颜色
		var hy: float = _p2ay(h, pa, chart)
		var ly: float = _p2ay(l, pa, chart)
		var oy: float = _p2ay(o, pa, chart)
		var cy: float = _p2ay(cl, pa, chart)
		var bt: float = min(oy, cy)
		var bb: float = max(oy, cy)
		var bh: float = max(absf(oy - cy), 2.0)
		draw_line(Vector2(cx, hy), Vector2(cx, bt), col, 1.4)
		draw_line(Vector2(cx, bb), Vector2(cx, ly), col, 1.4)
		var br := Rect2(Vector2(cx - bw * 0.5, bt), Vector2(bw, bh))
		if cl >= o:
			draw_rect(br, col, false, 1.6)
		else:
			draw_rect(br, col, true)

func _draw_volume(vol: Rect2) -> void:
	var candles: Array = _get_visible_candles()
	var mv: float = 0.000001
	for c in candles:
		mv = max(mv, float(c.get("volume", 0.0)))
	var gap: float = vol.size.x / float(max(candles.size() + max(未来留白K线数, 0), 1))
	var bw: float = clampf(gap * 0.56, 3.0, 12.0)
	for i in range(candles.size()):
		var c: Dictionary = candles[i]
		var o: float = float(c.get("open", 0.0))
		var cl: float = float(c.get("close", 0.0))
		var col: Color = 上涨颜色 if cl >= o else 下跌颜色
		col.a = 0.42
		var bh: float = vol.size.y * float(c.get("volume", 0.0)) / mv
		var x: float = vol.position.x + gap * (float(i) + 0.5) - bw * 0.5
		draw_rect(Rect2(Vector2(x, vol.end.y - bh), Vector2(bw, bh)), col, true)

# ===== 价格轴标签 =====

func _draw_price_axis_labels(chart: Rect2, pa: Dictionary, active: bool) -> void:
	var font: Font = get_theme_default_font()
	var labels: Array = pa.get("labels", []) as Array
	var positions: Array = _get_tick_positions(pa, chart)
	var last_pos_idx: int = max(positions.size() - 1, 0)
	for i in range(labels.size()):
		var idx: int = min(i, last_pos_idx)
		var y: float = float(positions[idx]) + 4.0
		var txt: String = _format_price(float(labels[i])) if active else "--"
		_draw_crisp_string(font, Vector2(chart.end.x + 8.0, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 坐标字体大小, 坐标文字颜色)
	_draw_axis_break_markers(chart, pa, positions)
# ===== 时间轴标签 =====

func _draw_time_axis_labels(chart: Rect2, vol: Rect2, candles: Array, label_data: Array[Dictionary]) -> void:
	var font: Font = get_theme_default_font()
	var y: float = vol.end.y + min(时间坐标高度, 20.0)
	for item in label_data:
		var x: float = float(item.get("x", 0.0))
		var txt: String = str(item.get("text", "--"))
		_draw_crisp_string(font, Vector2(x - 24.0, y), txt, HORIZONTAL_ALIGNMENT_CENTER, 78.0, 坐标字体大小, 坐标文字颜色)

func _get_time_label_data(candles: Array, vol: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var total: int = candles.size()
	var n: int = max(下方刻度数量, 2)
	for i in range(n):
		var ratio: float = float(i) / float(n - 1)
		var x: float = vol.position.x + vol.size.x * ratio
		if total > 0:
			var bars_ago: int = _get_time_axis_bars_ago_for_tick(i, n, total, ratio)
			out.append({"x": x, "text": _get_time_axis_text(bars_ago)})
		else:
			out.append({"x": x, "text": "--"})
	return out

func _get_label_step() -> int:
	var series: Array = _series_by_timeframe.get(_timeframe, []) as Array
	var total: int = max(series.size(), 1)
	var desired: int = max(下方刻度数量, 2)
	return max(1, int(round(float(total) / float(desired))))

func _get_time_axis_bars_ago_for_tick(index: int, tick_count: int, total: int, ratio: float) -> int:
	var interval_step: int = _get_configured_label_interval_bars()
	if interval_step > 0:
		return max(tick_count - 1 - index, 0) * interval_step
	return int(round(float(max(total - 1, 0)) * (1.0 - ratio)))

func _get_configured_label_interval_bars() -> int:
	var candle_minutes: int = _get_timeframe_minutes()
	var interval_minutes: int = 0
	match _timeframe:
		"一分钟":
			interval_minutes = 分钟间隔分钟
		"一小时":
			interval_minutes = 小时间隔小时 * 60
		"一天":
			interval_minutes = 天间隔天 * 1440
		"一周":
			interval_minutes = 周间隔天 * 1440
		"一月":
			interval_minutes = 月间隔月 * 43200
		"一年":
			interval_minutes = 年间隔年 * 525600
	if interval_minutes <= 0:
		return 0
	return max(1, int(round(float(interval_minutes) / float(candle_minutes))))

func _get_time_axis_text(bars_ago: int) -> String:
	var ts: Dictionary = _get_current_time_stamp()
	if not ts.is_empty():
		var shifted: Dictionary = _shift_time_stamp(ts, -bars_ago * _get_timeframe_minutes())
		return _format_time_stamp(shifted)
	var profile: Dictionary = _get_timeframe_profile()
	if bars_ago <= 0:
		return "现在"
	return "-" + str(bars_ago) + str(profile.get("unit", ""))

func _format_time_stamp(ts: Dictionary) -> String:
	var mod: int = int(ts.get("minute_of_day", 0))
	var h: int = int(mod / 60)
	var m: int = mod % 60
	var d: int = int(ts.get("day", 1))
	var mo: int = int(ts.get("month", 1))
	var y: int = int(ts.get("year", 2026))
	var tfm: int = _get_timeframe_minutes()
	if tfm < 1440:
		return "%02d:%02d" % [h, m]
	if tfm < 10080:
		return "%d日" % d
	if tfm < 43200:
		return "%d月%d日" % [mo, d]
	if tfm < 525600:
		return "%d年%d月" % [y % 100, mo]
	return "%d年" % [y % 100]

# ===== 强平线 / 断轴 =====

func _draw_liquidation_line(chart: Rect2, pa: Dictionary, active: bool) -> void:
	if not active or _liquidation_line_price <= 0.0:
		return
	var y: float = _p2ay(_liquidation_line_price, pa, chart)
	draw_line(Vector2(chart.position.x, y), Vector2(chart.end.x, y), 强平线颜色, 1.8)
	var font: Font = get_theme_default_font()
	var txt: String = _liquidation_line_label if not _liquidation_line_label.is_empty() else "强平 " + _format_price(_liquidation_line_price)
	var ly: float = clampf(y + 4.0, chart.position.y + 12.0, chart.end.y - 4.0)
	_draw_crisp_string(font, Vector2(chart.end.x + 8.0, ly), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 坐标字体大小, 强平线颜色)

func _draw_crisp_string(font: Font, position: Vector2, text: String, alignment: HorizontalAlignment, width: float, font_size: int, color: Color) -> void:
	var crisp_position: Vector2 = Vector2(roundf(position.x), roundf(position.y))
	var clear_color: Color = color
	clear_color.a = max(clear_color.a, 0.96)
	draw_string(font, crisp_position + Vector2(1.0, 1.0), text, alignment, width, font_size, TEXT_SHADOW_COLOR)
	draw_string(font, crisp_position, text, alignment, width, font_size, clear_color)

func _draw_axis_break_markers(chart: Rect2, pa: Dictionary, positions: Array) -> void:
	var side: String = str(pa.get("broken_side", ""))
	if side.is_empty() or positions.size() < 3:
		return
	var break_y: float = 0.0
	if side == "lower":
		break_y = (float(positions[1]) + float(positions[2])) * 0.5
	elif side == "upper":
		var last: int = positions.size() - 1
		break_y = (float(positions[last - 2]) + float(positions[last - 1])) * 0.5
	else:
		return
	var ax: float = chart.end.x - 1.0
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(ax + 1.0, break_y - 8.0),
		Vector2(ax + 8.0, break_y - 2.0),
		Vector2(ax + 2.0, break_y + 1.0),
		Vector2(ax + 8.0, break_y + 8.0)
	])
	draw_polyline(pts, AXIS_BREAK_CUT_COLOR, 5.0)
	draw_polyline(pts, Color(0.94, 0.98, 0.93, 0.92), 1.2)

# ===== 价格轴计算 =====

func _p2y(price: float, pa: Dictionary, chart: Rect2) -> float:
	var labels: Array = pa.get("labels", []) as Array
	var positions: Array = _calc_h_positions(chart, max(labels.size() - 1, 1))
	if labels.size() >= 2 and positions.size() >= labels.size():
		return _piecewise_p2y(price, labels, positions, 0, labels.size() - 1)
	var mn: float = float(pa.get("min", 0.0))
	var mx: float = float(pa.get("max", 1.0))
	var r: float = (price - mn) / max(mx - mn, 0.000001)
	return lerpf(float(positions[0]), float(positions[positions.size() - 1]), clampf(r, 0.0, 1.0)) if not positions.is_empty() else chart.end.y

func _p2ay(price: float, pa: Dictionary, chart: Rect2) -> float:
	var side: String = str(pa.get("broken_side", ""))
	if side.is_empty():
		return _p2y(price, pa, chart)
	var labels: Array = pa.get("labels", []) as Array
	if labels.size() < 2:
		return _p2y(price, pa, chart)

	# 断裂情况：手动计算line_positions，让下区（或上区）视觉压缩
	var line_positions: Array = _calc_broken_positions(pa, chart)
	var n: int = labels.size()

	if side == "lower":
		var lower_local_tick: float = float(labels[0])
		var upper_local_tick: float = float(labels[1])
		if price <= upper_local_tick:
			var r: float = clampf((price - lower_local_tick) / max(upper_local_tick - lower_local_tick, 0.000001), 0.0, 1.0)
			return lerpf(float(line_positions[0]), float(line_positions[1]), r)
		return _piecewise_p2y(price, labels, line_positions, 2, n - 1)
	if side == "upper":
		var last: int = n - 1
		var lower_local_tick: float = float(labels[last - 1])
		var upper_local_tick: float = float(labels[last])
		if price >= lower_local_tick:
			var r: float = clampf((price - lower_local_tick) / max(upper_local_tick - lower_local_tick, 0.000001), 0.0, 1.0)
			return lerpf(float(line_positions[last - 1]), float(line_positions[last]), r)
		return _piecewise_p2y(price, labels, line_positions, 0, last - 2)
	return _p2y(price, pa, chart)

## 为断裂情况计算正确的line_positions。
## 原K线主体刻度保持等距，断裂侧用两个局部刻度夹住强平线。
func _calc_broken_positions(pa: Dictionary, chart: Rect2) -> Array:
	var labels: Array = pa.get("labels", []) as Array
	var side: String = str(pa.get("broken_side", ""))
	var n: int = labels.size()
	var pad: float = 10.0
	var top: float = chart.position.y + pad
	var btm: float = chart.end.y - pad
	var h: float = max(btm - top, 8.0)
	var break_band: float = clampf(h * 0.16, 34.0, 58.0)
	var local_band: float = clampf(break_band * 0.42, 16.0, 26.0)

	if side == "lower":
		var positions: Array = []
		positions.append(int(roundf(btm)))
		positions.append(int(roundf(btm - local_band)))
		var original_count: int = n - 2
		var original_bottom: float = btm - break_band
		var original_height: float = max(original_bottom - top, 1.0)
		for i in range(original_count):
			var ratio: float = 0.0 if original_count <= 1 else float(i) / float(original_count - 1)
			var y: float = original_bottom - original_height * ratio
			positions.append(int(roundf(y)))
		return positions

	if side == "upper":
		var positions: Array = []
		var original_count: int = n - 2
		var original_top: float = top + break_band
		var original_height: float = max(btm - original_top, 1.0)
		for i in range(original_count):
			var ratio: float = 0.0 if original_count <= 1 else float(i) / float(original_count - 1)
			var y: float = btm - original_height * ratio
			positions.append(int(roundf(y)))
		positions.append(int(roundf(top + local_band)))
		positions.append(int(roundf(top)))
		return positions

	# 不应该到这里
	return _calc_h_positions(chart, max(n - 1, 1))

func _piecewise_p2y(price: float, labels: Array, pos: Array, start: int, end: int) -> float:
	var s: int = clampi(start, 0, labels.size() - 1)
	var e: int = clampi(end, s, labels.size() - 1)
	if price <= float(labels[s]): return float(pos[s])
	if price >= float(labels[e]): return float(pos[e])
	for i in range(s, e):
		var lo: float = float(labels[i])
		var hi: float = float(labels[i + 1])
		if price >= lo and price <= hi:
			var r: float = (price - lo) / max(hi - lo, 0.000001)
			return lerpf(float(pos[i]), float(pos[i + 1]), r)
	return float(pos[s])

## 计算所有刻度线的Y坐标（断裂情况用_calc_broken_positions）
func _get_tick_positions(pa: Dictionary, chart: Rect2) -> Array:
	var labels: Array = pa.get("labels", []) as Array
	if labels.is_empty():
		return []
	var broken: bool = not pa.get("broken_side", "").is_empty()
	if not broken:
		return _calc_h_positions(chart, max(labels.size() - 1, 1))
	return _calc_broken_positions(pa, chart)

func _get_price_axis_data(candles: Array) -> Dictionary:
	var rng: Vector2 = _get_price_range(candles)
	var span: float = max(rng.y - rng.x, 0.000001)
	var seg: int = max(右侧刻度数量 - 1, 1)
	var step: float = _get_nice_tick(span / float(seg))
	var mn: float = floor(rng.x / step) * step
	var mx: float = mn + step * float(seg)
	if mx < rng.y:
		mx = ceil(rng.y / step) * step
		mn = mx - step * float(seg)
	var lbl: Array[float] = []
	for i in range(seg + 1):
		lbl.append(mn + step * float(i))
	var data: Dictionary = {"min": mn, "max": mx, "step": step, "segment_count": seg, "labels": lbl}
	data["original_tick_count"] = 右侧刻度数量  # 记录原有刻度数量
	return _apply_liquidation_axis_break(data)

func _apply_liquidation_axis_break(data: Dictionary) -> Dictionary:
	if _liquidation_line_price <= 0.0:
		return data
	var labels: Array = data.get("labels", []) as Array
	if labels.size() < 2:
		return data
	var mn: float = float(data.get("min", 0.0))
	var mx: float = float(data.get("max", 1.0))
	if _liquidation_line_price >= mn and _liquidation_line_price <= mx:
		return data
	var step_val: float = float(labels[1]) - float(labels[0]) if labels.size() >= 2 else 1.0
	var display: Array[float] = []
	if _liquidation_line_price < mn:
		var bracket: Vector2 = _get_liquidation_bracket_ticks(step_val, _liquidation_line_price)
		display.append(bracket.x)
		display.append(bracket.y)
		for index in range(1, labels.size()):
			display.append(float(labels[index]))
		data["broken_side"] = "lower"
		data["break_from"] = bracket.y
		data["break_to"] = float(labels[1])
		data["visual_min"] = bracket.x
		data["visual_max"] = mx
	elif _liquidation_line_price > mx:
		var bracket: Vector2 = _get_liquidation_bracket_ticks(step_val, _liquidation_line_price)
		for index in range(labels.size() - 1):
			display.append(float(labels[index]))
		display.append(bracket.x)
		display.append(bracket.y)
		data["broken_side"] = "upper"
		data["break_from"] = float(labels[labels.size() - 2])
		data["break_to"] = bracket.x
		data["visual_min"] = mn
		data["visual_max"] = bracket.y
	data["labels"] = display
	if not display.is_empty():
		data["min"] = float(display[0])
		data["max"] = float(display[display.size() - 1])
	return data

## 断裂逻辑（x=右侧刻度数量）：
## 一个原极端刻度被挪到强平线附近，再额外新增一个刻度，尽量让强平线居中。
func _get_liquidation_bracket_ticks(step: float, liq: float) -> Vector2:
	var safe_step: float = max(absf(step), 0.000001)
	var lower_tick: float = floor(liq / safe_step) * safe_step
	var upper_tick: float = lower_tick + safe_step
	var ratio: float = (liq - lower_tick) / safe_step
	if ratio <= 0.05 or ratio >= 0.95:
		lower_tick = liq - safe_step * 0.5
		upper_tick = liq + safe_step * 0.5
	return Vector2(lower_tick, upper_tick)

func _get_price_range(candles: Array) -> Vector2:
	var mn: float = INF
	var mx: float = -INF
	for c in candles:
		mn = min(mn, float(c.get("low", 0.0)))
		mx = max(mx, float(c.get("high", 0.0)))
	if mn == INF or mx == -INF or is_equal_approx(mn, mx):
		var base: float = _get_current_market_rate()
		mn = base * 0.995
		mx = base * 1.005
	# 强平线距离合理时才将其纳入价格轴（不压缩K线）
	if _should_include_liquidation_in_axis(mn, mx):
		mn = min(mn, _liquidation_line_price)
		mx = max(mx, _liquidation_line_price)
	var pad: float = max((mx - mn) * 0.08, mx * 0.0002)
	return Vector2(mn - pad, mx + pad)

func _should_include_liquidation_in_axis(mn: float, mx: float) -> bool:
	if _liquidation_line_price <= 0.0:
		return false
	var span: float = max(mx - mn, max(mx, 0.000001) * 0.001)
	var allowed: float = span * LIQUIDATION_AXIS_INCLUDE_SPAN_RATIO
	return _liquidation_line_price >= mn - allowed and _liquidation_line_price <= mx + allowed

func _get_nice_tick(raw: float) -> float:
	var s: float = max(raw, 0.000001)
	var e: float = floor(log(s) / log(10.0))
	var mag: float = pow(10.0, e)
	var n: float = s / mag
	if n <= 1.0: return mag
	if n <= 2.0: return 2.0 * mag
	if n <= 5.0: return 5.0 * mag
	return 10.0 * mag

# ===== K线数据 =====

func _initialize_timeframe_series() -> void:
	_series_by_timeframe.clear()
	_last_bucket_keys.clear()
	var base: float = _get_current_market_rate()
	for tf in _get_supported_timeframes():
		var prof: Dictionary = _get_timeframe_profile(tf)
		_series_by_timeframe[tf] = _build_seed(base, prof)
		_last_bucket_keys[tf] = _get_bucket_key(int(prof.get("minutes", 1)))

func _build_seed(base: float, prof: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var vol: float = float(prof.get("volatility", 0.0012))
	var count: int = max(int(prof.get("count", 演示K线数量)), 12)
	var last: float = max(base, 0.000001)
	for i in range(count):
		var drift: float = sin(float(i) * 0.21) * vol * 0.35
		var shock: float = _rng.randfn(0.0, vol)
		var o: float = last
		var cl: float = max(o * (1.0 + drift + shock), 0.000001)
		var ws: float = absf(_rng.randfn(vol * 0.7, vol * 0.35))
		var h: float = max(o, cl) * (1.0 + ws)
		var l: float = min(o, cl) * max(1.0 - ws, 0.000001)
		var wp: float = max(o * vol * 0.22, o * 0.00012)
		h = max(h, max(o, cl) + wp)
		l = min(l, min(o, cl) - wp)
		l = max(l, 0.000001)
		var v: float = absf(_rng.randfn(1.0, 0.35)) * (1.0 + absf(cl - o) / max(o, 0.000001) * 90.0)
		out.append({"open": o, "high": h, "low": l, "close": cl, "volume": v})
		last = cl
	return out

func _get_visible_candles() -> Array:
	var series: Array = _series_by_timeframe.get(_timeframe, []) as Array
	return series.duplicate(true)

func _get_axis_reference_candles(candles: Array) -> Array:
	if not candles.is_empty():
		return candles
	var out: Array = []
	for i in range(24):
		out.append({"open": 1.0, "high": 1.0, "low": 1.0, "close": 1.0, "volume": 0.0})
	return out

func _get_supported_timeframes() -> Array[String]:
	return ["一分钟", "一小时", "一天", "一周", "一月", "一年"]

func _get_timeframe_profile(tf: String = "") -> Dictionary:
	var name: String = tf if not tf.is_empty() else _timeframe
	match name:
		"一分钟": return {"count": 64, "volatility": 0.0008, "label": "1m", "unit": "m", "minutes": 1}
		"一小时": return {"count": 56, "volatility": 0.0014, "label": "1h", "unit": "h", "minutes": 60}
		"一天": return {"count": 48, "volatility": 0.0024, "label": "1d", "unit": "d", "minutes": 1440}
		"一周": return {"count": 42, "volatility": 0.0055, "label": "1w", "unit": "w", "minutes": 10080}
		"一月": return {"count": 36, "volatility": 0.0100, "label": "1M", "unit": "M", "minutes": 43200}
		"一年": return {"count": 30, "volatility": 0.0180, "label": "1Y", "unit": "Y", "minutes": 525600}
		_: return {"count": 64, "volatility": 0.0008, "label": "1m", "unit": "m", "minutes": 1}

func _get_timeframe_minutes() -> int:
	var prof: Dictionary = _get_timeframe_profile()
	return max(int(prof.get("minutes", 1)), 1)

# ===== 时间戳 =====

func _get_current_time_stamp() -> Dictionary:
	if _time_system == null or not _time_system.has_method("获取当前日期数据"):
		return {}
	var dd: Dictionary = _time_system.call("获取当前日期数据")
	return {
		"year": int(dd.get("year", 2026)),
		"month": int(dd.get("month", 1)),
		"day": int(dd.get("day", 1)),
		"minute_of_day": int(dd.get("clock_hour", 0)) * 60 + int(dd.get("clock_minute", 0))
	}

func _shift_time_stamp(ts: Dictionary, delta_min: int) -> Dictionary:
	var r: Dictionary = ts.duplicate()
	var total: int = int(r.get("minute_of_day", 0)) + delta_min
	while total < 0:
		r = _shift_date(r, -1)
		total += 1440
	while total >= 1440:
		r = _shift_date(r, 1)
		total -= 1440
	r["minute_of_day"] = total
	return r

func _shift_date(ts: Dictionary, days: int) -> Dictionary:
	var r: Dictionary = ts.duplicate()
	var y: int = int(r.get("year", 2026))
	var mo: int = int(r.get("month", 1))
	var d: int = int(r.get("day", 1)) + days
	while d < 1:
		mo -= 1
		if mo < 1: mo = 12; y -= 1
		d += _days_in_month(y, mo)
	while d > _days_in_month(y, mo):
		d -= _days_in_month(y, mo)
		mo += 1
		if mo > 12: mo = 1; y += 1
	r["year"] = y; r["month"] = mo; r["day"] = d
	return r

func _days_in_month(y: int, m: int) -> int:
	if _time_system != null and _time_system.has_method("获取当月天数"):
		return int(_time_system.call("获取当月天数", y, m))
	match m:
		1,3,5,7,8,10,12: return 31
		4,6,9,11: return 30
		2: return 29 if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0 else 28
		_: return 30

func _get_bucket_key(interval: int) -> int:
	var safe: int = max(interval, 1)
	var ts: Dictionary = _get_current_time_stamp()
	if ts.is_empty():
		return 0
	var abs_min: int = _days_from_civil(int(ts.get("year", 2026)), int(ts.get("month", 1)), int(ts.get("day", 1))) * 1440 + int(ts.get("minute_of_day", 0))
	return int(floor(float(abs_min) / float(safe)))

func _days_from_civil(y: int, m: int, d: int) -> int:
	var ay: int = y - (1 if m <= 2 else 0)
	var era: int = floori(float(ay) / 400.0)
	var yoe: int = ay - era * 400
	var am: int = m - 3 if m > 2 else m + 9
	var doy: int = int((153 * am + 2) / 5) + d - 1
	var doe: int = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
	return era * 146097 + doe - 719468

func _has_active_pair() -> bool:
	return not _left_currency_code.is_empty() and not _right_currency_code.is_empty()

# ===== 行情 =====

func _get_current_market_rate() -> float:
	var pr: float = _get_pair_rate(_left_currency_code, _right_currency_code)
	if pr > 0.0: return pr
	match _right_currency_code:
		"YHB": return 20.0
		"USD": return 0.14
		"EUR": return 0.13
		"GBP": return 0.11
		"DSB": return 0.21
		"FYB": return 0.19
		_: return 1.0

func _get_pair_rate(left: String, right: String) -> float:
	var lr: float = _get_rate_against_xmy(left)
	var rr: float = _get_rate_against_xmy(right)
	if lr <= 0.0 or rr <= 0.0: return 0.0
	return rr / lr

func _get_rate_against_xmy(code: String) -> float:
	if code == "XMY": return 1.0
	if _market_engine != null and _market_engine.has_method("获取汇率"):
		var r: float = float(_market_engine.call("获取汇率", code))
		if r > 0.0: return r
	return 0.0

# ===== 信号 =====

func _connect_market_engine() -> void:
	if _market_engine == null or not _market_engine.has_signal("汇率变动"): return
	var cb: Callable = _on_rate_changed
	if not _market_engine.is_connected("汇率变动", cb):
		_market_engine.connect("汇率变动", cb)

func _on_rate_changed(code: String, _snap: Dictionary) -> void:
	if _left_currency_code.is_empty() or _right_currency_code.is_empty():
		return
	if code != _left_currency_code and code != _right_currency_code and code != 默认货币代码:
		return
	var rate: float = _get_current_market_rate()
	if rate <= 0.0: return
	_apply_live_rate(rate)
	queue_redraw()

func _apply_live_rate(rate: float) -> void:
	for tf in _get_supported_timeframes():
		var prof: Dictionary = _get_timeframe_profile(tf)
		var bk: int = _get_bucket_key(int(prof.get("minutes", 1)))
		var series: Array = _series_by_timeframe.get(tf, []) as Array
		if series.is_empty():
			series = _build_seed(rate, prof)
		var last_bk: int = int(_last_bucket_keys.get(tf, bk))
		if bk != last_bk:
			var prev_close: float = float(series[series.size() - 1].get("close", rate))
			var vol: float = float(prof.get("volatility", 0.0012))
			var wp: float = max(prev_close * vol * 0.22, prev_close * 0.00012)
			var body_high: float = max(prev_close, rate)
			var body_low: float = min(prev_close, rate)
			series.append({
				"open": prev_close,
				"high": max(body_high + wp, body_high),
				"low": min(body_low - wp, body_low),
				"close": rate,
				"volume": 1.0
			})
			var max_count: int = max(int(prof.get("count", 演示K线数量)), 12)
			while series.size() > max_count: series.remove_at(0)
			_last_bucket_keys[tf] = bk
		else:
			var last: Dictionary = series[series.size() - 1]
			last["close"] = rate
			last["high"] = max(float(last.get("high", rate)), rate)
			last["low"] = min(float(last.get("low", rate)), rate)
			last["volume"] = float(last.get("volume", 1.0)) + 0.18
		_series_by_timeframe[tf] = series

func _format_price(v: float) -> String:
	if v >= 10.0: return "%.3f" % v
	return "%.5f" % v

# ===== 图表区域 =====

func _get_chart_rect() -> Rect2:
	var r: Rect2 = _get_reserved("k线图部分2")
	if 使用预留画布区域 and r.size.x > 10.0 and r.size.y > 10.0:
		return _with_price_space(r)
	var ch: float = max(size.y - 底部按钮区留白 - 时间坐标高度 - 柱状图区高度 - 图区间距 - 顶部留白, 40.0)
	return Rect2(Vector2(10.0, 顶部留白), Vector2(max(size.x - 价格坐标宽度 - 18.0, 40.0), ch))

func _get_volume_rect() -> Rect2:
	var r: Rect2 = _get_reserved("柱状图部分")
	if 使用预留画布区域 and r.size.x > 10.0 and r.size.y > 10.0:
		return _with_price_space(r)
	var cr: Rect2 = _get_chart_rect()
	return Rect2(Vector2(cr.position.x, cr.end.y + 图区间距), Vector2(cr.size.x, 柱状图区高度))

func _get_reserved(name: String) -> Rect2:
	var p: Node = get_parent()
	if p == null: return Rect2()
	var t: Control = _find_descendant(p, name) as Control
	if t == null: return Rect2()
	return Rect2(t.position, t.size)

func _with_price_space(r: Rect2) -> Rect2:
	var pad: float = 8.0
	return Rect2(r.position + Vector2(pad, 6.0), Vector2(max(r.size.x - 价格坐标宽度 - pad * 2.0, 20.0), max(r.size.y - 12.0, 20.0)))

func _find_descendant(root: Node, name: String) -> Node:
	if root == null: return null
	if root.name == name: return root
	for c in root.get_children():
		var f: Node = _find_descendant(c, name)
		if f != null: return f
	return null
