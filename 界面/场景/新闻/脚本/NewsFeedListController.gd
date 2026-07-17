extends Node
class_name NewsFeedListController

signal article_requested(article: Dictionary)

const CARD_NORMAL_MODULATE: Color = Color(1, 1, 1, 1)
const CARD_PRESSED_MODULATE: Color = Color(0.92, 0.92, 0.92, 1)
const ALT_BG_COLOR_A: Color = Color("f5efe1")
const ALT_BG_COLOR_B: Color = Color("f0f2f6")
const DRAG_START_DISTANCE: float = 10.0
const OVERSCROLL_DRAG_RATIO: float = 0.42
const OVERSCROLL_MAX_DISTANCE: float = 96.0
const OVERSCROLL_TRIGGER_DISTANCE: float = 46.0
const OVERSCROLL_BOUNCE_DURATION: float = 0.22
const WHEEL_OVERSCROLL_STEP: float = 34.0
const MIN_CARD_WIDTH: float = 452.0
const DEFAULT_LIST_TOP: float = 82.0
const DEFAULT_CARD_HEIGHT: float = 136.0
const DEFAULT_CARD_GAP: float = 12.0

@export_range(1, 14, 1) var initial_days: int = 3
@export_range(1, 14, 1) var load_more_days: int = 3
@export_range(3, 240, 1) var max_history_days: int = 90
@export_range(1, 60, 1) var min_initial_cards: int = 9
@export_range(1, 60, 1) var min_load_more_cards: int = 6
@export_range(8.0, 240.0, 1.0) var bottom_preload_threshold: float = 72.0
@export_range(0.0, 160.0, 1.0) var list_bottom_padding: float = 24.0
@export_range(0.0, 160.0, 1.0) var section_bottom_padding: float = 28.0
@export_range(0.0, 180.0, 1.0) var content_bottom_padding: float = 42.0
@export var debug_feed_layout: bool = false

var _provider: NewsRuntimeFeedProvider = null
var _scroll_container: ScrollContainer = null
var _content_root: Control = null
var _page_background: Control = null
var _quick_section_panel: Control = null
var _list_container: VBoxContainer = null

var _template_cards: Array[Panel] = []
var _runtime_cards: Array[Panel] = []
var _loaded_items: Array[Dictionary] = []
var _visible_item_keys: Dictionary = {}
var _current_date: Dictionary = {}
var _current_serial: int = 0
var _next_history_offset_day: int = 0
var _history_pool_days: int = 0
var _has_initialized_feed: bool = false
var _is_loading_more: bool = false

var _base_content_height: float = 0.0
var _base_background_height: float = 0.0
var _base_section_height: float = 0.0
var _base_list_top: float = DEFAULT_LIST_TOP
var _base_list_width: float = MIN_CARD_WIDTH

var _card_press_state: Dictionary = {}
var _pointer_down: bool = false
var _dragging: bool = false
var _press_global_position: Vector2 = Vector2.ZERO
var _press_scroll_vertical: float = 0.0
var _pressed_card: Panel = null
var _overscroll_offset: float = 0.0
var _active_bounce_tween: Tween = null
var _queued_bottom_refresh: bool = false


func bind_runtime_nodes(
	provider: NewsRuntimeFeedProvider,
	scroll_container: ScrollContainer,
	content_root: Control,
	page_background: Control,
	quick_section_panel: Control,
	list_container: VBoxContainer
) -> void:
	_provider = provider
	_scroll_container = scroll_container
	_content_root = content_root
	_page_background = page_background
	_quick_section_panel = quick_section_panel
	_list_container = list_container
	_cache_base_layout()
	_collect_template_cards()
	_configure_scroll_area()


func refresh_feed(current_date: Dictionary) -> void:
	var next_date: Dictionary = current_date.duplicate(true)
	var next_serial: int = _day_serial(next_date)
	if not _has_initialized_feed:
		_current_date = next_date
		_current_serial = next_serial
		_history_pool_days = maxi(initial_days, 1)
		_has_initialized_feed = true
		_rebuild_from_latest(true)
		return

	var advanced_days: int = maxi(next_serial - _current_serial, 0)
	_current_date = next_date
	_current_serial = next_serial
	if advanced_days > 0:
		_history_pool_days = mini(max_history_days, maxi(_history_pool_days, initial_days) + advanced_days)
		_rebuild_from_latest(false)
		return

	_refresh_existing_cards()


func close_open_card_state() -> void:
	for card_value: Variant in _card_press_state.keys():
		var card: Panel = card_value as Panel
		if card != null and is_instance_valid(card):
			_apply_card_normal_state(card)
	_card_press_state.clear()
	_pressed_card = null


func get_loaded_articles() -> Array[Dictionary]:
	var articles: Array[Dictionary] = []
	for item: Dictionary in _loaded_items:
		articles.append(item.duplicate(true))
	return articles


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button_event.pressed and _handle_wheel_overscroll(mouse_button_event):
			get_viewport().set_input_as_handled()
			return

	if not _pointer_down:
		return

	if event is InputEventMouseMotion:
		_handle_drag_motion((event as InputEventMouseMotion).global_position)
		if _dragging:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		_handle_drag_motion((event as InputEventScreenDrag).position)
		if _dragging:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			_finish_drag(mouse_button.global_position)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if not touch_event.pressed:
			_finish_drag(touch_event.position)
			get_viewport().set_input_as_handled()


func _cache_base_layout() -> void:
	if _content_root != null:
		_base_content_height = maxf(_content_root.custom_minimum_size.y, _content_root.size.y)
	if _page_background != null:
		_base_background_height = maxf(_page_background.custom_minimum_size.y, _page_background.size.y)
	if _quick_section_panel != null:
		_base_section_height = maxf(_quick_section_panel.custom_minimum_size.y, _quick_section_panel.size.y)
	if _list_container != null:
		_base_list_top = _list_container.position.y if _list_container.position.y > 0.0 else DEFAULT_LIST_TOP
		_base_list_width = maxf(maxf(_list_container.custom_minimum_size.x, _list_container.size.x), MIN_CARD_WIDTH)


func _collect_template_cards() -> void:
	_template_cards.clear()
	if _list_container == null:
		return
	for child: Node in _list_container.get_children():
		if child is Panel:
			var template_card: Panel = child as Panel
			template_card.visible = false
			template_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			template_card.set_meta("news_template", true)
			_template_cards.append(template_card)


func _configure_scroll_area() -> void:
	if _scroll_container != null:
		_scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
		if not _scroll_container.gui_input.is_connected(_on_scroll_container_gui_input):
			_scroll_container.gui_input.connect(_on_scroll_container_gui_input)
		var scroll_bar: VScrollBar = _scroll_container.get_v_scroll_bar()
		if scroll_bar != null:
			var callback: Callable = Callable(self, "_on_scroll_value_changed")
			if not scroll_bar.value_changed.is_connected(callback):
				scroll_bar.value_changed.connect(callback)
	if _quick_section_panel != null:
		_quick_section_panel.mouse_filter = Control.MOUSE_FILTER_PASS


func _rebuild_from_latest(reset_scroll: bool) -> void:
	_clear_runtime_cards()
	_loaded_items.clear()
	_visible_item_keys.clear()
	_next_history_offset_day = 0
	_history_pool_days = maxi(_history_pool_days, initial_days)
	_append_history_days(initial_days, min_initial_cards)
	_refresh_layout_heights()
	if reset_scroll:
		_reset_scroll_position()
	else:
		_clamp_scroll_to_valid_range()
	_debug_layout("rebuild")


func _refresh_existing_cards() -> void:
	# Refreshing without rebuilding preserves the player's current scroll position.
	for index: int in range(_runtime_cards.size()):
		_apply_alternating_background(_runtime_cards[index], index)
	_refresh_layout_heights()
	_try_load_more_if_needed()


func _append_history_batch_from_bottom() -> void:
	if _is_loading_more:
		return
	if _next_history_offset_day >= _history_pool_days and _history_pool_days < max_history_days:
		_history_pool_days = mini(max_history_days, _history_pool_days + maxi(load_more_days, 1))
	if _next_history_offset_day >= _history_pool_days:
		return
	var old_card_count: int = _runtime_cards.size()
	_append_history_days(load_more_days, min_load_more_cards)
	_refresh_layout_heights()
	_clamp_scroll_to_valid_range()
	_debug_layout("append old=%d new=%d" % [old_card_count, _runtime_cards.size()])


func _append_history_days(day_budget: int, minimum_cards: int) -> void:
	if _provider == null or _list_container == null:
		return
	_is_loading_more = true
	var scanned_days: int = 0
	var appended_cards: int = 0
	var max_scan_days: int = mini(max_history_days - _next_history_offset_day, maxi(day_budget * 4, day_budget + 2))
	while scanned_days < max_scan_days and _next_history_offset_day < max_history_days:
		if _next_history_offset_day >= _history_pool_days:
			break
		var source_date: Dictionary = _provider.shift_date_data(_current_date, -_next_history_offset_day)
		var day_items: Array[Dictionary] = _provider.build_day_items(source_date)
		day_items.sort_custom(_sort_items_descending)
		for item: Dictionary in day_items:
			var item_key: String = _build_item_key(item)
			if _visible_item_keys.has(item_key):
				continue
			_visible_item_keys[item_key] = true
			_loaded_items.append(item)
			_create_runtime_card(item)
			appended_cards += 1
		_next_history_offset_day += 1
		scanned_days += 1
		if scanned_days >= day_budget and appended_cards >= minimum_cards:
			break
	_is_loading_more = false


func _sort_items_descending(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("sort_value", 0)) > int(b.get("sort_value", 0))


func _build_item_key(item: Dictionary) -> String:
	return "%s|%s|%s" % [String(item.get("template_id", "")), String(item.get("date_key", "")), String(item.get("time_label", ""))]


func _create_runtime_card(item: Dictionary) -> void:
	var template_card: Panel = _pick_template_card(bool(item.get("has_image", false)))
	if template_card == null or _list_container == null:
		return
	var runtime_card: Panel = template_card.duplicate(15) as Panel
	if runtime_card == null:
		return
	runtime_card.name = "NewsCard_%03d" % _runtime_cards.size()
	runtime_card.visible = true
	runtime_card.mouse_filter = Control.MOUSE_FILTER_STOP
	runtime_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	runtime_card.modulate = CARD_NORMAL_MODULATE
	runtime_card.set_meta("news_item", item.duplicate(true))
	runtime_card.set_meta("news_template", false)
	_disable_child_mouse_filter(runtime_card)
	_apply_runtime_card_min_size(runtime_card)
	_apply_item_to_card(runtime_card, item)
	_apply_alternating_background(runtime_card, _runtime_cards.size())
	var input_callback: Callable = _on_card_gui_input.bind(runtime_card)
	if not runtime_card.gui_input.is_connected(input_callback):
		runtime_card.gui_input.connect(input_callback)
	var exit_callback: Callable = _on_card_mouse_exited.bind(runtime_card)
	if not runtime_card.mouse_exited.is_connected(exit_callback):
		runtime_card.mouse_exited.connect(exit_callback)
	_list_container.add_child(runtime_card)
	_runtime_cards.append(runtime_card)


func _apply_runtime_card_min_size(card: Panel) -> void:
	var target_width: float = maxf(maxf(card.custom_minimum_size.x, card.size.x), MIN_CARD_WIDTH)
	var target_height: float = maxf(maxf(card.custom_minimum_size.y, card.size.y), DEFAULT_CARD_HEIGHT)
	card.custom_minimum_size = Vector2(target_width, target_height)
	card.size = Vector2(target_width, target_height)


func _pick_template_card(needs_image: bool) -> Panel:
	for template_card: Panel in _template_cards:
		if _card_supports_image(template_card) == needs_image:
			return template_card
	if not _template_cards.is_empty():
		return _template_cards[0]
	return null


func _card_supports_image(card: Panel) -> bool:
	return _find_first_texture_rect(card) != null


func _apply_item_to_card(card: Panel, item: Dictionary) -> void:
	_set_label_text_by_name(card, ["分类", "标签"], String(item.get("category_short", "News")))
	_set_label_text_by_name(card, ["时间"], String(item.get("time_label", "--:--")))
	_set_label_text_by_name(card, ["标题"], String(item.get("headline", "No headline")))
	_set_label_text_by_name(card, ["摘要"], String(item.get("summary", "")))
	var image_panel: Panel = _find_first_panel_with_texture(card)
	var image_rect: TextureRect = _find_first_texture_rect(card)
	var has_image: bool = bool(item.get("has_image", false))
	if image_panel != null:
		image_panel.visible = has_image
	if image_rect != null:
		if has_image:
			_apply_texture_to_rect(image_rect, String(item.get("image_path", "")))
		else:
			image_rect.texture = null


func _set_label_text_by_name(root: Node, names: Array[String], text_value: String) -> void:
	var label: Label = _find_label_by_names(root, names)
	if label != null:
		label.text = text_value


func _find_label_by_names(root: Node, names: Array[String]) -> Label:
	if root is Label:
		var label_name: String = String(root.name)
		for target_name: String in names:
			if label_name == target_name:
				return root as Label
	for child: Node in root.get_children():
		var found: Label = _find_label_by_names(child, names)
		if found != null:
			return found
	return null


func _apply_alternating_background(card: Panel, index: int) -> void:
	var target_color: Color = ALT_BG_COLOR_A if index % 2 == 0 else ALT_BG_COLOR_B
	var stylebox: StyleBox = card.get_theme_stylebox("panel")
	var flat_stylebox: StyleBoxFlat = stylebox as StyleBoxFlat
	if flat_stylebox == null:
		flat_stylebox = StyleBoxFlat.new()
	var duplicated_stylebox: StyleBoxFlat = flat_stylebox.duplicate() as StyleBoxFlat
	duplicated_stylebox.bg_color = target_color
	card.add_theme_stylebox_override("panel", duplicated_stylebox)


func _refresh_layout_heights() -> void:
	if _list_container == null:
		return
	var list_height: float = _measure_list_height() + list_bottom_padding
	var list_width: float = maxf(_base_list_width, _measure_list_width())
	_apply_minimum_size(_list_container, Vector2(list_width, list_height))
	if _list_container is Container:
		(_list_container as Container).queue_sort()

	var section_height: float = maxf(_base_section_height, _base_list_top + list_height + section_bottom_padding)
	if _quick_section_panel != null:
		_apply_minimum_size(_quick_section_panel, Vector2(maxf(_quick_section_panel.size.x, list_width), section_height))

	var background_height: float = maxf(_base_background_height, (_quick_section_panel.position.y if _quick_section_panel != null else 0.0) + section_height)
	if _page_background != null:
		_apply_minimum_size(_page_background, Vector2(maxf(_page_background.size.x, list_width), background_height))

	var content_height: float = _base_content_height
	if _quick_section_panel != null:
		content_height = maxf(content_height, _quick_section_panel.position.y + section_height + content_bottom_padding)
	if _page_background != null:
		content_height = maxf(content_height, _page_background.position.y + background_height + content_bottom_padding)
	if _content_root != null:
		_apply_minimum_size(_content_root, Vector2(maxf(_content_root.size.x, list_width), content_height))

	if _scroll_container != null:
		_scroll_container.update_minimum_size()
		_scroll_container.queue_redraw()
	_apply_overscroll_visual()


func _apply_minimum_size(control: Control, target_size: Vector2) -> void:
	if control == null:
		return
	control.custom_minimum_size = Vector2(maxf(target_size.x, 0.0), maxf(target_size.y, 0.0))
	control.size = control.custom_minimum_size
	control.offset_right = control.offset_left + control.custom_minimum_size.x
	control.offset_bottom = control.offset_top + control.custom_minimum_size.y
	control.update_minimum_size()
	if control.get_parent() is Control:
		(control.get_parent() as Control).update_minimum_size()


func _measure_list_height() -> float:
	if _list_container == null:
		return 0.0
	var total_height: float = 0.0
	var visible_count: int = 0
	var separation: float = DEFAULT_CARD_GAP
	if _list_container is BoxContainer:
		separation = float((_list_container as BoxContainer).get_theme_constant("separation"))
	for child: Node in _list_container.get_children():
		if not (child is Control):
			continue
		var row: Control = child as Control
		if row.is_queued_for_deletion() or not row.visible:
			continue
		var row_height: float = maxf(row.custom_minimum_size.y, row.size.y)
		total_height += maxf(row_height, DEFAULT_CARD_HEIGHT)
		visible_count += 1
	if visible_count > 1:
		total_height += separation * float(visible_count - 1)
	return total_height


func _measure_list_width() -> float:
	var max_width: float = MIN_CARD_WIDTH
	if _list_container == null:
		return max_width
	for child: Node in _list_container.get_children():
		if child is Control:
			var row: Control = child as Control
			max_width = maxf(max_width, maxf(row.custom_minimum_size.x, row.size.x))
	return max_width


func _try_load_more_if_needed() -> void:
	if _is_loading_more or _scroll_container == null:
		return
	var distance_to_bottom: float = _get_scroll_max_value() - float(_scroll_container.scroll_vertical)
	if distance_to_bottom <= bottom_preload_threshold:
		_append_history_batch_from_bottom()


func _on_scroll_value_changed(_value: float) -> void:
	_try_load_more_if_needed()


func _on_scroll_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_begin_drag(mouse_button.global_position, null)
		return
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_drag(touch_event.position, null)


func _on_card_gui_input(event: InputEvent, card: Panel) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_begin_drag(mouse_button.global_position, card)
			_apply_card_pressed_state(card)
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_drag(touch_event.position, card)
			_apply_card_pressed_state(card)
		return


func _begin_drag(global_position: Vector2, card: Panel) -> void:
	_pointer_down = true
	_dragging = false
	_press_global_position = global_position
	_press_scroll_vertical = float(_scroll_container.scroll_vertical) if _scroll_container != null else 0.0
	_pressed_card = card
	_kill_bounce_tween()
	if card != null:
		_card_press_state[card] = true


func _handle_drag_motion(global_position: Vector2) -> void:
	if not _pointer_down or _scroll_container == null:
		return
	var delta: Vector2 = global_position - _press_global_position
	if not _dragging and absf(delta.y) >= DRAG_START_DISTANCE:
		_dragging = true
		if _pressed_card != null:
			_card_press_state.erase(_pressed_card)
			_apply_card_normal_state(_pressed_card)
	if not _dragging:
		return
	var max_scroll: float = _get_scroll_max_value()
	var target_scroll: float = _press_scroll_vertical - delta.y
	var clamped_scroll: float = clampf(target_scroll, 0.0, max_scroll)
	_scroll_container.scroll_vertical = int(clamped_scroll)
	var overflow: float = target_scroll - clamped_scroll
	if not is_zero_approx(overflow):
		_set_overscroll_offset(clampf(-overflow * OVERSCROLL_DRAG_RATIO, -OVERSCROLL_MAX_DISTANCE, OVERSCROLL_MAX_DISTANCE))
	else:
		_set_overscroll_offset(0.0)
	_try_load_more_if_needed()


func _finish_drag(global_position: Vector2) -> void:
	if not _pointer_down:
		return
	var released_card: Panel = _pressed_card
	var was_dragging: bool = _dragging
	_pointer_down = false
	_dragging = false
	_pressed_card = null
	var should_refresh_bottom: bool = _overscroll_offset <= -OVERSCROLL_TRIGGER_DISTANCE
	if not is_zero_approx(_overscroll_offset):
		_bounce_overscroll(should_refresh_bottom)
	if released_card == null:
		return
	var was_pressed: bool = bool(_card_press_state.get(released_card, false))
	_card_press_state.erase(released_card)
	_apply_card_normal_state(released_card)
	if was_dragging:
		return
	if was_pressed and released_card.get_global_rect().has_point(global_position):
		_emit_article_requested(released_card)


func _on_card_mouse_exited(card: Panel) -> void:
	if bool(_card_press_state.get(card, false)):
		return
	_apply_card_normal_state(card)


func _emit_article_requested(card: Panel) -> void:
	var article: Variant = card.get_meta("news_item", {})
	if article is Dictionary:
		article_requested.emit(article as Dictionary)


func _apply_card_pressed_state(card: Panel) -> void:
	card.modulate = CARD_PRESSED_MODULATE


func _apply_card_normal_state(card: Panel) -> void:
	card.modulate = CARD_NORMAL_MODULATE


func _clear_runtime_cards() -> void:
	for card: Panel in _runtime_cards:
		if card != null and is_instance_valid(card):
			card.queue_free()
	_runtime_cards.clear()
	_card_press_state.clear()
	_pointer_down = false
	_dragging = false
	_pressed_card = null
	_queued_bottom_refresh = false
	_kill_bounce_tween()
	_set_overscroll_offset(0.0)


func _handle_wheel_overscroll(mouse_button: InputEventMouseButton) -> bool:
	if _scroll_container == null or mouse_button.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return false
	var is_at_bottom: bool = _get_scroll_max_value() - float(_scroll_container.scroll_vertical) <= 1.0
	if not is_at_bottom:
		return false
	_set_overscroll_offset(maxf(_overscroll_offset - WHEEL_OVERSCROLL_STEP, -OVERSCROLL_MAX_DISTANCE))
	_bounce_overscroll(true)
	return true


func _bounce_overscroll(trigger_refresh: bool) -> void:
	if is_zero_approx(_overscroll_offset):
		if trigger_refresh:
			_append_history_batch_from_bottom()
		return
	_queued_bottom_refresh = trigger_refresh
	_kill_bounce_tween()
	var start_offset: float = _overscroll_offset
	_active_bounce_tween = create_tween()
	_active_bounce_tween.set_trans(Tween.TRANS_QUART)
	_active_bounce_tween.set_ease(Tween.EASE_OUT)
	_active_bounce_tween.tween_method(_set_overscroll_offset, start_offset, 0.0, OVERSCROLL_BOUNCE_DURATION)
	_active_bounce_tween.finished.connect(_on_bounce_finished)


func _on_bounce_finished() -> void:
	_active_bounce_tween = null
	_set_overscroll_offset(0.0)
	if _queued_bottom_refresh:
		_queued_bottom_refresh = false
		_append_history_batch_from_bottom()


func _set_overscroll_offset(value: float) -> void:
	_overscroll_offset = value
	_apply_overscroll_visual()


func _apply_overscroll_visual() -> void:
	if _content_root != null:
		_content_root.position.y = _overscroll_offset
	if _scroll_container != null:
		_scroll_container.position.y = _overscroll_offset * 0.18


func _kill_bounce_tween() -> void:
	if _active_bounce_tween != null and _active_bounce_tween.is_valid():
		_active_bounce_tween.kill()
	_active_bounce_tween = null


func _reset_scroll_position() -> void:
	if _scroll_container == null:
		return
	_scroll_container.scroll_vertical = 0
	_scroll_container.position.y = 0.0


func _clamp_scroll_to_valid_range() -> void:
	if _scroll_container == null:
		return
	_scroll_container.scroll_vertical = int(clampf(float(_scroll_container.scroll_vertical), 0.0, _get_scroll_max_value()))


func _get_scroll_max_value() -> float:
	if _scroll_container == null:
		return 0.0
	var scroll_bar: VScrollBar = _scroll_container.get_v_scroll_bar()
	if scroll_bar == null:
		return 0.0
	return maxf(scroll_bar.max_value - scroll_bar.page, 0.0)


func _disable_child_mouse_filter(root: Control) -> void:
	for child: Node in root.get_children():
		if child is Control:
			var child_control: Control = child as Control
			child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_disable_child_mouse_filter(child_control)


func _find_first_texture_rect(root: Node) -> TextureRect:
	for child: Node in root.get_children():
		if child is TextureRect:
			return child as TextureRect
		var nested: TextureRect = _find_first_texture_rect(child)
		if nested != null:
			return nested
	return null


func _find_first_panel_with_texture(root: Node) -> Panel:
	for child: Node in root.get_children():
		if child is Panel and _find_first_texture_rect(child) != null:
			return child as Panel
		var nested: Panel = _find_first_panel_with_texture(child)
		if nested != null:
			return nested
	return null


func _apply_texture_to_rect(image_rect: TextureRect, texture_path: String) -> void:
	if texture_path.is_empty():
		image_rect.texture = null
		return
	var texture_resource: Texture2D = load(texture_path) as Texture2D
	image_rect.texture = texture_resource


func _day_serial(date_data: Dictionary) -> int:
	return _days_from_civil(int(date_data.get("year", 2026)), int(date_data.get("month", 1)), int(date_data.get("day", 1)))


func _days_from_civil(year: int, month: int, day: int) -> int:
	var adjusted_year: int = year - (1 if month <= 2 else 0)
	var era: int = int(floor(float(adjusted_year) / 400.0))
	var year_of_era: int = adjusted_year - era * 400
	var adjusted_month: int = month - 3 if month > 2 else month + 9
	var day_of_year: int = int((153 * adjusted_month + 2) / 5) + day - 1
	var day_of_era: int = year_of_era * 365 + int(year_of_era / 4) - int(year_of_era / 100) + day_of_year
	return era * 146097 + day_of_era - 719468


func _debug_layout(reason: String) -> void:
	if not debug_feed_layout:
		return
	var max_scroll: float = _get_scroll_max_value()
	var scroll_value: int = _scroll_container.scroll_vertical if _scroll_container != null else 0
	print("NewsFeedListController ", reason, " cards=", _runtime_cards.size(), " items=", _loaded_items.size(), " next_day=", _next_history_offset_day, " pool=", _history_pool_days, " list_h=", _measure_list_height(), " scroll=", scroll_value, "/", max_scroll)
