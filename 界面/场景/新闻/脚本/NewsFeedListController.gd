extends Node
class_name NewsFeedListController

signal article_requested(article: Dictionary)

const LIST_IMAGE_PANEL_NAME: String = "右侧图片卡"
const LIST_IMAGE_NAME: String = "图片"
const LIST_TIME_NAME: String = "时间"
const LIST_TITLE_NAME: String = "标题"
const LIST_SUMMARY_NAME: String = "摘要"
const LIST_CATEGORY_NAME_A: String = "分类"
const LIST_CATEGORY_NAME_B: String = "标签"
const CARD_NORMAL_MODULATE: Color = Color(1, 1, 1, 1)
const CARD_PRESSED_MODULATE: Color = Color(0.92, 0.92, 0.92, 1)
const ALT_BG_COLOR_A: Color = Color("f5efe1")
const ALT_BG_COLOR_B: Color = Color("f0f2f6")
const DRAG_START_DISTANCE: float = 10.0

@export_range(1, 14, 1) var initial_batch_days: int = 3
@export_range(1, 14, 1) var batch_step_days: int = 3
@export_range(3, 180, 1) var max_history_days: int = 90
@export_range(8.0, 240.0, 1.0) var bottom_preload_threshold: float = 72.0
@export_range(8.0, 80.0, 1.0) var section_bottom_padding: float = 26.0
@export_range(8.0, 120.0, 1.0) var content_bottom_padding: float = 36.0

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
var _loaded_day_count: int = 0
var _is_loading_more: bool = false
var _base_content_min_height: float = 0.0
var _base_section_height: float = 0.0
var _base_background_height: float = 0.0
var _card_press_state: Dictionary = {}
var _pointer_down: bool = false
var _dragging: bool = false
var _press_global_position: Vector2 = Vector2.ZERO
var _press_scroll_vertical: float = 0.0
var _pressed_card: Panel = null


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
	_cache_base_sizes()
	_collect_template_cards()
	_connect_scroll_bar()
	_configure_drag_surface()


func _input(event: InputEvent) -> void:
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


func refresh_feed(current_date: Dictionary) -> void:
	_current_date = current_date.duplicate(true)
	_loaded_day_count = 0
	_loaded_items.clear()
	_visible_item_keys.clear()
	_clear_runtime_cards()
	_append_next_batch(maxi(initial_batch_days, 1))
	_refresh_layout_heights()
	_reset_scroll_position()
	_ensure_scrollable_content()


func close_open_card_state() -> void:
	for card_value: Variant in _card_press_state.keys():
		var card: Panel = card_value as Panel
		if card == null or not is_instance_valid(card):
			continue
		_apply_card_normal_state(card)
	_card_press_state.clear()
	_pressed_card = null


func get_loaded_articles() -> Array[Dictionary]:
	var articles: Array[Dictionary] = []
	for item: Dictionary in _loaded_items:
		articles.append(item.duplicate(true))
	return articles


func _cache_base_sizes() -> void:
	if _content_root != null:
		_base_content_min_height = _content_root.custom_minimum_size.y
	if _quick_section_panel != null:
		_base_section_height = _quick_section_panel.size.y
	if _page_background != null:
		_base_background_height = _page_background.size.y


func _collect_template_cards() -> void:
	_template_cards.clear()
	if _list_container == null:
		return
	for child: Node in _list_container.get_children():
		if not (child is Panel):
			continue
		var template_card: Panel = child as Panel
		template_card.visible = false
		template_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		template_card.set_meta("news_template", true)
		_template_cards.append(template_card)


func _connect_scroll_bar() -> void:
	if _scroll_container == null:
		return
	var scroll_bar: VScrollBar = _scroll_container.get_v_scroll_bar()
	if scroll_bar == null:
		return
	var callback: Callable = Callable(self, "_on_scroll_value_changed")
	if not scroll_bar.value_changed.is_connected(callback):
		scroll_bar.value_changed.connect(callback)


func _configure_drag_surface() -> void:
	if _scroll_container == null:
		return
	_scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _scroll_container.gui_input.is_connected(_on_scroll_container_gui_input):
		_scroll_container.gui_input.connect(_on_scroll_container_gui_input)
	if _quick_section_panel != null:
		_quick_section_panel.mouse_filter = Control.MOUSE_FILTER_PASS


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


func _on_scroll_value_changed(_value: float) -> void:
	_try_load_more_if_needed()


func _append_next_batch(days_to_load: int = -1) -> void:
	if _provider == null or _loaded_day_count >= max_history_days:
		return
	_is_loading_more = true
	var actual_days_to_load: int = batch_step_days if days_to_load <= 0 else days_to_load
	actual_days_to_load = mini(actual_days_to_load, max_history_days - _loaded_day_count)
	var batch_items: Array[Dictionary] = _build_batch_items(_loaded_day_count, actual_days_to_load)
	for item: Dictionary in batch_items:
		_loaded_items.append(item)
		_visible_item_keys[_build_item_key(item)] = true
		_create_runtime_card(item)
	_loaded_day_count += actual_days_to_load
	_refresh_layout_heights()
	_is_loading_more = false


func _build_batch_items(start_offset: int, day_count: int) -> Array[Dictionary]:
	var batch_items: Array[Dictionary] = []
	if _provider == null:
		return batch_items
	for offset: int in range(start_offset, start_offset + day_count):
		var source_date: Dictionary = _provider.shift_date_data(_current_date, -offset)
		var day_items: Array[Dictionary] = _provider.build_day_items(source_date)
		for item: Dictionary in day_items:
			var item_key: String = _build_item_key(item)
			if _visible_item_keys.has(item_key):
				continue
			batch_items.append(item)
	batch_items.sort_custom(_sort_items_descending)
	return batch_items


func _build_item_key(item: Dictionary) -> String:
	return "%s|%s|%s" % [String(item.get("template_id", "")), String(item.get("date_key", "")), String(item.get("time_label", ""))]


func _sort_items_descending(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("sort_value", 0)) > int(b.get("sort_value", 0))


func _create_runtime_card(item: Dictionary) -> void:
	if _list_container == null:
		return
	var template_card: Panel = _pick_template_card(bool(item.get("has_image", false)))
	if template_card == null:
		return
	var runtime_card: Panel = template_card.duplicate() as Panel
	if runtime_card == null:
		return
	runtime_card.visible = true
	runtime_card.mouse_filter = Control.MOUSE_FILTER_STOP
	runtime_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	runtime_card.modulate = CARD_NORMAL_MODULATE
	runtime_card.set_meta("news_item", item)
	runtime_card.set_meta("news_template", false)
	_disable_child_mouse_filter(runtime_card)
	if not runtime_card.gui_input.is_connected(_on_card_gui_input.bind(runtime_card)):
		runtime_card.gui_input.connect(_on_card_gui_input.bind(runtime_card))
	if not runtime_card.mouse_exited.is_connected(_on_card_mouse_exited.bind(runtime_card)):
		runtime_card.mouse_exited.connect(_on_card_mouse_exited.bind(runtime_card))
	_apply_item_to_card(runtime_card, item)
	_apply_alternating_background(runtime_card, _runtime_cards.size())
	_list_container.add_child(runtime_card)
	_runtime_cards.append(runtime_card)


func _pick_template_card(needs_image: bool) -> Panel:
	for template_card: Panel in _template_cards:
		if _card_supports_image(template_card) == needs_image:
			return template_card
	if not _template_cards.is_empty():
		return _template_cards[0]
	return null


func _card_supports_image(card: Panel) -> bool:
	return _find_panel_by_name(card, LIST_IMAGE_PANEL_NAME) != null


func _apply_item_to_card(card: Panel, item: Dictionary) -> void:
	var category_label: Label = _find_first_label(card, [LIST_CATEGORY_NAME_A, LIST_CATEGORY_NAME_B])
	var time_label: Label = _find_label_by_name(card, LIST_TIME_NAME)
	var title_label: Label = _find_label_by_name(card, LIST_TITLE_NAME)
	var summary_label: Label = _find_label_by_name(card, LIST_SUMMARY_NAME)
	if category_label != null:
		category_label.text = String(item.get("category_short", "全部资讯"))
	if time_label != null:
		time_label.text = String(item.get("time_label", "--:--"))
	if title_label != null:
		title_label.text = String(item.get("headline", "暂无新闻"))
	if summary_label != null:
		summary_label.text = String(item.get("summary", "暂无摘要"))

	var image_panel: Panel = _find_panel_by_name(card, LIST_IMAGE_PANEL_NAME)
	var image_rect: TextureRect = _find_texture_rect_by_name(card, LIST_IMAGE_NAME)
	var has_image: bool = bool(item.get("has_image", false))
	if image_panel != null:
		image_panel.visible = has_image
	if image_rect != null:
		if has_image:
			_apply_texture_to_rect(image_rect, String(item.get("image_path", "")))
		else:
			image_rect.texture = null


func _apply_alternating_background(card: Panel, index: int) -> void:
	var target_color: Color = ALT_BG_COLOR_A if index % 2 == 0 else ALT_BG_COLOR_B
	var stylebox: StyleBox = card.get_theme_stylebox("panel")
	var flat_stylebox: StyleBoxFlat = stylebox as StyleBoxFlat
	if flat_stylebox != null:
		var duplicated_stylebox: StyleBoxFlat = flat_stylebox.duplicate() as StyleBoxFlat
		duplicated_stylebox.bg_color = target_color
		card.add_theme_stylebox_override("panel", duplicated_stylebox)


func _disable_child_mouse_filter(root: Control) -> void:
	for child: Node in root.get_children():
		if child is Control:
			var child_control: Control = child as Control
			child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_disable_child_mouse_filter(child_control)


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
	var target_scroll: float = _press_scroll_vertical - delta.y
	_scroll_container.scroll_vertical = int(clampf(target_scroll, 0.0, float(_scroll_container.get_v_scroll_bar().max_value)))
	_try_load_more_if_needed()


func _finish_drag(global_position: Vector2) -> void:
	if not _pointer_down:
		return
	var released_card: Panel = _pressed_card
	var was_dragging: bool = _dragging
	_pointer_down = false
	_dragging = false
	_pressed_card = null
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


func _refresh_layout_heights() -> void:
	if _list_container == null:
		return
	var list_height: float = _measure_list_height()
	_list_container.custom_minimum_size = Vector2(_list_container.custom_minimum_size.x, list_height)

	if _quick_section_panel != null:
		var section_height: float = maxf(_base_section_height, _list_container.position.y + list_height + section_bottom_padding)
		_quick_section_panel.size = Vector2(_quick_section_panel.size.x, section_height)
		if _page_background != null:
			var background_height: float = maxf(_base_background_height, section_height + 28.0)
			_page_background.size = Vector2(_page_background.size.x, background_height)
		if _content_root != null:
			var content_height: float = maxf(_base_content_min_height, _quick_section_panel.position.y + section_height + content_bottom_padding)
			_content_root.custom_minimum_size = Vector2(_content_root.custom_minimum_size.x, content_height)


func _measure_list_height() -> float:
	if _list_container == null:
		return 0.0
	var height_total: float = 0.0
	var visible_count: int = 0
	for child: Node in _list_container.get_children():
		if not (child is Control):
			continue
		var child_control: Control = child as Control
		if not child_control.visible:
			continue
		height_total += maxf(child_control.custom_minimum_size.y, child_control.size.y)
		visible_count += 1
	if visible_count > 1:
		height_total += float(visible_count - 1) * float(_list_container.get_theme_constant("separation"))
	return height_total


func _reset_scroll_position() -> void:
	if _scroll_container == null:
		return
	_scroll_container.scroll_vertical = 0


func _ensure_scrollable_content() -> void:
	if _scroll_container == null:
		return
	var scroll_bar: VScrollBar = _scroll_container.get_v_scroll_bar()
	if scroll_bar == null:
		return
	while scroll_bar.max_value <= 1.0 and _loaded_day_count < max_history_days:
		var previous_count: int = _runtime_cards.size()
		_append_next_batch()
		if _runtime_cards.size() == previous_count:
			break


func _try_load_more_if_needed() -> void:
	if _is_loading_more or _scroll_container == null:
		return
	var scroll_bar: VScrollBar = _scroll_container.get_v_scroll_bar()
	if scroll_bar == null:
		return
	if scroll_bar.max_value - scroll_bar.value > bottom_preload_threshold:
		return
	if _loaded_day_count >= max_history_days:
		return
	_append_next_batch()


func _find_label_by_name(root: Node, target_name: String) -> Label:
	for child: Node in root.get_children():
		if child is Label and String(child.name) == target_name:
			return child as Label
		var nested: Label = _find_label_by_name(child, target_name)
		if nested != null:
			return nested
	return null


func _find_first_label(root: Node, target_names: Array[String]) -> Label:
	for target_name: String in target_names:
		var found: Label = _find_label_by_name(root, target_name)
		if found != null:
			return found
	return null


func _find_texture_rect_by_name(root: Node, target_name: String) -> TextureRect:
	for child: Node in root.get_children():
		if child is TextureRect and String(child.name) == target_name:
			return child as TextureRect
		var nested: TextureRect = _find_texture_rect_by_name(child, target_name)
		if nested != null:
			return nested
	return null


func _find_panel_by_name(root: Node, target_name: String) -> Panel:
	for child: Node in root.get_children():
		if child is Panel and String(child.name) == target_name:
			return child as Panel
		var nested: Panel = _find_panel_by_name(child, target_name)
		if nested != null:
			return nested
	return null


func _apply_texture_to_rect(image_rect: TextureRect, texture_path: String) -> void:
	if texture_path.is_empty():
		image_rect.texture = null
		return
	var texture_resource: Texture2D = load(texture_path) as Texture2D
	if texture_resource != null:
		image_rect.texture = texture_resource
	else:
		image_rect.texture = null
