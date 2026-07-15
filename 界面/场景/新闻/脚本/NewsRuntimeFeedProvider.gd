extends RefCounted
class_name NewsRuntimeFeedProvider

const TEMPLATES_PATH: String = "res://\u8d44\u6e90/\u6570\u636e/\u65b0\u95fb/news_templates.json"
const IMAGE_ASSETS_PATH: String = "res://\u8d44\u6e90/\u6570\u636e/\u65b0\u95fb/news_image_assets.json"
const DAY_COOLDOWN_NORMAL: int = 6
const DAY_COOLDOWN_HEADLINE: int = 12
const HEADLINE_STEP_DAYS: int = 3
const HEADLINE_COUNT: int = 5
const LIST_COUNT: int = 5
const DAILY_NEWS_MIN: int = 3
const DAILY_NEWS_MAX: int = 4

const CAT_POLITICAL: String = "\u65f6\u653f\u98ce\u9669"
const CAT_DATA: String = "\u7ecf\u6d4e\u6570\u636e"
const CAT_POLICY: String = "\u8d27\u5e01\u653f\u7b56"
const CAT_TRADE: String = "\u8d38\u6613\u4e0e\u4ea7\u4e1a"
const CAT_EXPECT: String = "\u5e02\u573a\u9884\u671f"
const CAT_MOVE: String = "\u76d8\u9762\u5f02\u52a8"
const CAT_ALL: String = "\u5168\u90e8\u8d44\u8baf"
const REGION_GLOBAL: String = "\u5168\u7403"

const CATEGORY_WEIGHTS: Dictionary = {
	CAT_EXPECT: 22,
	CAT_DATA: 22,
	CAT_MOVE: 20,
	CAT_POLICY: 14,
	CAT_TRADE: 12,
	CAT_POLITICAL: 10,
}

const CATEGORY_SHORT_LABELS: Dictionary = {
	CAT_POLITICAL: "\u65f6\u653f\u98ce\u9669",
	CAT_DATA: "\u7ecf\u6d4e\u6570\u636e",
	CAT_POLICY: "\u8d27\u5e01\u653f\u7b56",
	CAT_TRADE: "\u8d38\u6613\u4ea7\u4e1a",
	CAT_EXPECT: "\u5e02\u573a\u9884\u671f",
	CAT_MOVE: "\u76d8\u9762\u5f02\u52a8",
}

const SLOT_NAMES: Array[String] = [
	"\u6e05\u6668",
	"\u4e2d\u5348",
	"\u9ec4\u660f",
	"\u665a\u4e0a",
	"\u6df1\u591c",
]

var _templates: Array[Dictionary] = []
var _templates_by_category: Dictionary = {}
var _image_path_by_id: Dictionary = {}
var _loaded: bool = false


func ensure_loaded() -> void:
	if _loaded:
		return
	_load_templates()
	_load_image_assets()
	_loaded = true


func build_feed(date_data: Dictionary) -> Dictionary:
	ensure_loaded()
	var normalized_date: Dictionary = _normalize_date(date_data)
	return {
		"headlines": _build_headline_items(normalized_date),
		"list_items": _build_list_items(normalized_date),
	}


func _build_headline_items(date_data: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var headline_anchor: Dictionary = _shift_date(date_data, -posmod(_day_serial(date_data), HEADLINE_STEP_DAYS))
	var used_template_ids: Dictionary = {}
	for index: int in range(HEADLINE_COUNT):
		var target_date: Dictionary = _shift_date(headline_anchor, -index * HEADLINE_STEP_DAYS)
		var item: Dictionary = _generate_featured_item_for_date(target_date, used_template_ids)
		if item.is_empty():
			item = _generate_any_item_for_date(target_date, used_template_ids, true)
		if item.is_empty():
			continue
		used_template_ids[String(item.get("template_id", ""))] = true
		items.append(item)
	return items


func _build_list_items(date_data: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var used_template_ids: Dictionary = {}
	var offset_day: int = 0
	while items.size() < LIST_COUNT and offset_day < 4:
		var source_date: Dictionary = _shift_date(date_data, -offset_day)
		var day_items: Array[Dictionary] = _generate_daily_items(source_date)
		for item: Dictionary in day_items:
			var template_id: String = String(item.get("template_id", ""))
			if used_template_ids.has(template_id):
				continue
			used_template_ids[template_id] = true
			items.append(item)
			if items.size() >= LIST_COUNT:
				break
		offset_day += 1
	return items


func _generate_daily_items(date_data: Dictionary) -> Array[Dictionary]:
	var seed_value: int = _day_serial(date_data)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var item_count: int = DAILY_NEWS_MIN + int(seed_value % max(DAILY_NEWS_MAX - DAILY_NEWS_MIN + 1, 1))
	var items: Array[Dictionary] = []
	var used_categories: Dictionary = {}
	var used_template_ids: Dictionary = {}
	for index: int in range(item_count):
		var category_name: String = _pick_weighted_category(rng, used_categories)
		if category_name.is_empty():
			break
		used_categories[category_name] = int(used_categories.get(category_name, 0)) + 1
		var template_data: Dictionary = _pick_template_for_category(category_name, date_data, seed_value + index * 13, used_template_ids, false)
		if template_data.is_empty():
			continue
		var item: Dictionary = _build_news_item(template_data, date_data, seed_value + index * 37, false)
		if item.is_empty():
			continue
		used_template_ids[String(item.get("template_id", ""))] = true
		items.append(item)
	return items


func _generate_featured_item_for_date(date_data: Dictionary, used_template_ids: Dictionary) -> Dictionary:
	var categories: Array[String] = [CAT_POLICY, CAT_POLITICAL, CAT_TRADE, CAT_EXPECT]
	var day_seed: int = _day_serial(date_data)
	for offset: int in range(categories.size()):
		var category_name: String = categories[posmod(day_seed + offset, categories.size())]
		var template_data: Dictionary = _pick_template_for_category(category_name, date_data, day_seed + offset * 17, used_template_ids, true)
		if template_data.is_empty():
			continue
		return _build_news_item(template_data, date_data, day_seed + offset * 41, true)
	return {}


func _generate_any_item_for_date(date_data: Dictionary, used_template_ids: Dictionary, prefer_image: bool) -> Dictionary:
	var categories: Array[String] = _get_category_names()
	var day_seed: int = _day_serial(date_data)
	for offset: int in range(categories.size()):
		var category_name: String = categories[posmod(day_seed + offset * 3, categories.size())]
		var template_data: Dictionary = _pick_template_for_category(category_name, date_data, day_seed + offset * 19, used_template_ids, prefer_image)
		if template_data.is_empty():
			continue
		return _build_news_item(template_data, date_data, day_seed + offset * 47, prefer_image)
	return {}


func _pick_weighted_category(rng: RandomNumberGenerator, used_categories: Dictionary) -> String:
	var pool: Array[String] = []
	for category_name_variant: Variant in CATEGORY_WEIGHTS.keys():
		var category_name: String = String(category_name_variant)
		var used_count: int = int(used_categories.get(category_name, 0))
		if used_count >= 2:
			continue
		var weight: int = int(CATEGORY_WEIGHTS.get(category_name, 0))
		var adjusted_weight: int = maxi(weight - used_count * 8, 1)
		for _repeat: int in range(adjusted_weight):
			pool.append(category_name)
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]


func _pick_template_for_category(category_name: String, date_data: Dictionary, seed_value: int, used_template_ids: Dictionary, prefer_image: bool) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var category_templates: Array = _templates_by_category.get(category_name, []) as Array
	for candidate_variant: Variant in category_templates:
		if not (candidate_variant is Dictionary):
			continue
		var candidate: Dictionary = candidate_variant as Dictionary
		var template_id: String = String(candidate.get("id", ""))
		if used_template_ids.has(template_id):
			continue
		if not _is_template_available_for_date(template_id, date_data, prefer_image):
			continue
		if prefer_image and not bool(candidate.get("has_image", false)):
			continue
		candidates.append(candidate)
	if candidates.is_empty() and prefer_image:
		return _pick_template_for_category(category_name, date_data, seed_value, used_template_ids, false)
	if candidates.is_empty():
		return {}
	var index: int = posmod(seed_value * 7 + candidates.size(), candidates.size())
	return candidates[index]


func _is_template_available_for_date(template_id: String, date_data: Dictionary, prefer_image: bool) -> bool:
	var cooldown_days: int = DAY_COOLDOWN_HEADLINE if prefer_image else DAY_COOLDOWN_NORMAL
	for lookback: int in range(1, cooldown_days + 1):
		var history_date: Dictionary = _shift_date(date_data, -lookback)
		var simulated: Array[Dictionary] = _generate_daily_items(history_date)
		for simulated_item: Dictionary in simulated:
			if String(simulated_item.get("template_id", "")) == template_id:
				return false
		if lookback <= HEADLINE_STEP_DAYS * 2:
			var featured: Dictionary = _generate_featured_item_for_date(history_date, {})
			if String(featured.get("template_id", "")) == template_id:
				return false
	return true


func _build_news_item(template_data: Dictionary, date_data: Dictionary, seed_value: int, prefer_image: bool) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var region_name: String = _pick_region(template_data, rng)
	var bias_text: String = _pick_string_option(template_data.get("bias_options", []), String(template_data.get("default_bias", "")), rng)
	var strength_text: String = _pick_string_option(template_data.get("strength_options", []), String(template_data.get("default_strength", "")), rng)
	var time_text: String = _build_time_text(date_data)
	var replacements: Dictionary = {
		"region": region_name,
		"time_text": time_text,
	}
	var summary_text: String = _render_template(String(template_data.get("summary_template", "")), replacements)
	var trend_text: String = _render_template(String(template_data.get("trend_outlook", "")), replacements)
	var tail_text: String = _render_template(String(template_data.get("analysis_tail", "")), replacements)
	var headline_text: String = _render_template(String(template_data.get("headline_template", "")), replacements)
	var body_text: String = "%s %s %s" % [summary_text, trend_text, tail_text]
	var image_path: String = ""
	if prefer_image or bool(template_data.get("has_image", false)):
		image_path = _pick_image_path(template_data, rng)
	var category_text: String = String(template_data.get("category", CAT_ALL))
	return {
		"template_id": String(template_data.get("id", "")),
		"date_key": _date_key(date_data),
		"category": category_text,
		"category_short": String(CATEGORY_SHORT_LABELS.get(category_text, category_text)),
		"headline": headline_text,
		"summary": summary_text,
		"trend_outlook": trend_text,
		"analysis_tail": tail_text,
		"body": body_text.strip_edges(),
		"time_label": _build_clock_text(date_data, rng),
		"time_text": time_text,
		"region": region_name,
		"bias": bias_text,
		"strength": strength_text,
		"image_path": image_path,
		"has_image": not image_path.is_empty(),
		"source_type": "state_driven",
		"impact_bucket": String(template_data.get("developer_bucket", "UNSET")),
		"parameter_hints": template_data.get("parameter_hints", []),
	}


func _pick_region(template_data: Dictionary, rng: RandomNumberGenerator) -> String:
	var regions: Array = template_data.get("regions", []) as Array
	if regions.is_empty():
		return REGION_GLOBAL
	return String(regions[rng.randi_range(0, regions.size() - 1)])


func _pick_image_path(template_data: Dictionary, rng: RandomNumberGenerator) -> String:
	var image_ids: Array = template_data.get("image_ids", []) as Array
	if image_ids.is_empty():
		return ""
	var selected_id: String = String(image_ids[rng.randi_range(0, image_ids.size() - 1)])
	return String(_image_path_by_id.get(selected_id, ""))


func _pick_string_option(options_variant: Variant, fallback: String, rng: RandomNumberGenerator) -> String:
	if not (options_variant is Array):
		return fallback
	var options: Array = options_variant as Array
	if options.is_empty():
		return fallback
	return String(options[rng.randi_range(0, options.size() - 1)])


func _render_template(source_text: String, replacements: Dictionary) -> String:
	var rendered_text: String = source_text
	for replacement_key_variant: Variant in replacements.keys():
		var replacement_key: String = String(replacement_key_variant)
		rendered_text = rendered_text.replace("{" + replacement_key + "}", String(replacements[replacement_key]))
	return rendered_text.strip_edges()


func _build_time_text(date_data: Dictionary) -> String:
	return "%04d-%02d-%02d %s" % [
		int(date_data.get("year", 2026)),
		int(date_data.get("month", 1)),
		int(date_data.get("day", 1)),
		_pick_slot_name(int(date_data.get("slot", 0))),
	]


func _build_clock_text(date_data: Dictionary, rng: RandomNumberGenerator) -> String:
	var base_hour: int = int(date_data.get("clock_hour", -1))
	var base_minute: int = int(date_data.get("clock_minute", -1))
	if base_hour < 0 or base_minute < 0:
		base_hour = 8 + rng.randi_range(0, 11)
		base_minute = rng.randi_range(0, 1) * 30
	return "%02d:%02d" % [base_hour, base_minute]


func _pick_slot_name(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= SLOT_NAMES.size():
		return "\u76d8\u4e2d"
	return SLOT_NAMES[slot_index]


func _date_key(date_data: Dictionary) -> String:
	return "%04d-%02d-%02d" % [
		int(date_data.get("year", 2026)),
		int(date_data.get("month", 1)),
		int(date_data.get("day", 1)),
	]


func _get_category_names() -> Array[String]:
	var category_names: Array[String] = []
	for category_name_variant: Variant in CATEGORY_WEIGHTS.keys():
		category_names.append(String(category_name_variant))
	return category_names


func _load_templates() -> void:
	_templates.clear()
	_templates_by_category.clear()
	var root_data: Dictionary = _read_json_dictionary(TEMPLATES_PATH)
	var templates_variant: Variant = root_data.get("templates", [])
	if not (templates_variant is Array):
		return
	for template_variant: Variant in templates_variant:
		if not (template_variant is Dictionary):
			continue
		var template_data: Dictionary = template_variant as Dictionary
		if not bool(template_data.get("enabled", true)):
			continue
		_templates.append(template_data)
		var category_name: String = String(template_data.get("category", CAT_ALL))
		if not _templates_by_category.has(category_name):
			_templates_by_category[category_name] = []
		var category_list: Array = _templates_by_category.get(category_name, []) as Array
		category_list.append(template_data)
		_templates_by_category[category_name] = category_list


func _load_image_assets() -> void:
	_image_path_by_id.clear()
	var root_data: Dictionary = _read_json_dictionary(IMAGE_ASSETS_PATH)
	var images_variant: Variant = root_data.get("images", [])
	if not (images_variant is Array):
		return
	for image_variant: Variant in images_variant:
		if not (image_variant is Dictionary):
			continue
		var image_data: Dictionary = image_variant as Dictionary
		var image_id: String = String(image_data.get("id", ""))
		var image_path: String = String(image_data.get("file", ""))
		if image_id.is_empty() or image_path.is_empty():
			continue
		_image_path_by_id[image_id] = image_path


func _read_json_dictionary(resource_path: String) -> Dictionary:
	if not FileAccess.file_exists(resource_path):
		return {}
	var file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		return {}
	var raw_text: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(raw_text)
	if parse_error != OK:
		push_warning("NewsRuntimeFeedProvider: failed to parse " + resource_path)
		return {}
	var data: Variant = parser.data
	if data is Dictionary:
		return data as Dictionary
	return {}


func _normalize_date(date_data: Dictionary) -> Dictionary:
	var year: int = maxi(int(date_data.get("year", 2026)), 1)
	var month: int = clampi(int(date_data.get("month", 1)), 1, 12)
	var day: int = clampi(int(date_data.get("day", 1)), 1, _get_days_in_month(year, month))
	return {
		"year": year,
		"month": month,
		"day": day,
		"slot": clampi(int(date_data.get("slot", 0)), 0, 4),
		"clock_hour": int(date_data.get("clock_hour", -1)),
		"clock_minute": int(date_data.get("clock_minute", -1)),
	}


func _shift_date(date_data: Dictionary, day_delta: int) -> Dictionary:
	var result: Dictionary = _normalize_date(date_data)
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
	return {
		"year": year,
		"month": month,
		"day": day,
		"slot": int(result.get("slot", 0)),
		"clock_hour": int(result.get("clock_hour", -1)),
		"clock_minute": int(result.get("clock_minute", -1)),
	}


func _day_serial(date_data: Dictionary) -> int:
	return _days_from_civil(
		int(date_data.get("year", 2026)),
		int(date_data.get("month", 1)),
		int(date_data.get("day", 1))
	)


func _get_days_in_month(year: int, month: int) -> int:
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


func _days_from_civil(year: int, month: int, day: int) -> int:
	var adjusted_year: int = year - (1 if month <= 2 else 0)
	var era: int = int(floor(float(adjusted_year) / 400.0))
	var year_of_era: int = adjusted_year - era * 400
	var adjusted_month: int = month - 3 if month > 2 else month + 9
	var day_of_year: int = int((153 * adjusted_month + 2) / 5) + day - 1
	var day_of_era: int = year_of_era * 365 + int(year_of_era / 4) - int(year_of_era / 100) + day_of_year
	return era * 146097 + day_of_era - 719468
