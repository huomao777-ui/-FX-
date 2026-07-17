extends Control
class_name NewsAppController

const TIME_SYSTEM_FALLBACK_PATH: String = "/root/GameDataManager/TimeSystem"
const HEADLINE_TITLE_NAME: String = "新闻标题"
const HEADLINE_IMAGE_NAME: String = "资讯图"
const DATE_SIGNAL_NAME: String = "日期变化"
const DATE_METHOD_NAME: String = "获取当前日期数据"
const MAIN_SCROLL_NAME: String = "主滚动区"
const CONTENT_ROOT_NAME: String = "滚动内容根"
const PAGE_BACKGROUND_NAME: String = "页面底色"
const QUICK_SECTION_NAME: String = "快讯分区"
const QUICK_LIST_NAME: String = "资讯列表"
const DETAIL_ROOT_NAME: String = "资讯详情节点"
const HEADLINE_CARD_CURSOR: int = Control.CURSOR_POINTING_HAND
const HEADLINE_CARD_NORMAL_MODULATE: Color = Color(1, 1, 1, 1)
const HEADLINE_CARD_PRESSED_MODULATE: Color = Color(0.92, 0.92, 0.92, 1)

@export var filter_bar_path: NodePath
@export var headline_root_path: NodePath
@export var quick_list_path: NodePath
@export var detail_root_path: NodePath
@export var time_system_path: NodePath = NodePath(TIME_SYSTEM_FALLBACK_PATH)

var _filter_bar_controller: Node = null
var _headline_root: Control = null
var _headline_track: HBoxContainer = null
var _time_system: Node = null
var _feed_provider: NewsRuntimeFeedProvider = NewsRuntimeFeedProvider.new()
var _list_controller: NewsFeedListController = NewsFeedListController.new()
var _detail_controller: NewsArticleDetailController = NewsArticleDetailController.new()
var _headline_cards: Array[Panel] = []
var _headline_press_state: Dictionary = {}
var _cached_feed: Dictionary = {}
var _current_date: Dictionary = {}


func _ready() -> void:
	add_child(_list_controller)
	add_child(_detail_controller)
	_initialize_page_state()
	_bind_feature_controllers()
	_refresh_news_feed()


func execute_app_back() -> bool:
	if _detail_controller != null and _detail_controller.hide_detail():
		return true
	var filter_bar: Node = _get_filter_bar_controller()
	if filter_bar == null:
		return false
	if filter_bar.has_method("execute_app_back"):
		return bool(filter_bar.call("execute_app_back"))
	if filter_bar.has_method("close_all_popups"):
		return bool(filter_bar.call("close_all_popups"))
	return false


func refresh_news_feed() -> void:
	_refresh_news_feed()


func _initialize_page_state() -> void:
	_filter_bar_controller = _resolve_filter_bar_controller()
	_headline_root = _resolve_headline_root()
	_headline_track = _resolve_headline_track()
	_collect_headline_cards()
	_configure_headline_cards()
	_time_system = _resolve_time_system()
	_connect_time_system()


func _bind_feature_controllers() -> void:
	var main_scroll: ScrollContainer = _find_scroll_container_by_name(self, MAIN_SCROLL_NAME)
	var content_root: Control = _find_control_by_name(self, CONTENT_ROOT_NAME)
	var page_background: Control = _find_control_by_name(self, PAGE_BACKGROUND_NAME)
	var quick_section: Control = _find_control_by_name(self, QUICK_SECTION_NAME)
	var quick_list: VBoxContainer = _resolve_quick_list()
	_list_controller.bind_runtime_nodes(_feed_provider, main_scroll, content_root, page_background, quick_section, quick_list)
	if not _list_controller.article_requested.is_connected(_on_article_requested):
		_list_controller.article_requested.connect(_on_article_requested)

	var detail_root: Control = _resolve_detail_root()
	_detail_controller.bind_detail_root(detail_root)
	if not _detail_controller.recommendation_requested.is_connected(_on_recommendation_requested):
		_detail_controller.recommendation_requested.connect(_on_recommendation_requested)
	if not _detail_controller.closed.is_connected(_on_detail_closed):
		_detail_controller.closed.connect(_on_detail_closed)


func _refresh_news_feed() -> void:
	_current_date = _get_current_date_data()
	_cached_feed = _feed_provider.build_feed(_current_date)
	_apply_headlines(_get_feed_array("headlines"))
	_list_controller.refresh_feed(_current_date)
	if _detail_controller.is_visible():
		_detail_controller.hide_detail()


func _on_article_requested(article: Dictionary) -> void:
	var recommendations: Array[Dictionary] = _build_recommendations_for(article)
	_detail_controller.show_article(article, recommendations)


func _on_recommendation_requested(article: Dictionary) -> void:
	_on_article_requested(article)


func _on_detail_closed() -> void:
	_list_controller.close_open_card_state()
	_clear_headline_press_state()


func _build_recommendations_for(article: Dictionary) -> Array[Dictionary]:
	var recommendations: Array[Dictionary] = []
	var all_loaded_articles: Array[Dictionary] = _list_controller.get_loaded_articles()
	var source_key: String = "%s|%s|%s" % [String(article.get("template_id", "")), String(article.get("date_key", "")), String(article.get("time_label", ""))]
	for candidate: Dictionary in all_loaded_articles:
		var candidate_key: String = "%s|%s|%s" % [String(candidate.get("template_id", "")), String(candidate.get("date_key", "")), String(candidate.get("time_label", ""))]
		if candidate_key == source_key:
			continue
		recommendations.append(candidate)
		if recommendations.size() >= 3:
			break
	return recommendations


func _get_feed_array(key: String) -> Array:
	var value: Variant = _cached_feed.get(key, [])
	if value is Array:
		return value as Array
	return []


func _apply_headlines(headline_items: Array) -> void:
	if _headline_cards.is_empty():
		return
	for index: int in range(_headline_cards.size()):
		var item: Dictionary = {}
		if index < headline_items.size() and headline_items[index] is Dictionary:
			item = (headline_items[index] as Dictionary).duplicate(true)
		_apply_headline_card(_headline_cards[index], item)


func _apply_headline_card(card: Panel, item: Dictionary) -> void:
	var title_label: Label = _find_label_by_name(card, HEADLINE_TITLE_NAME)
	var image_rect: TextureRect = _find_texture_rect_by_name(card, HEADLINE_IMAGE_NAME)
	if title_label != null:
		title_label.text = String(item.get("headline", "Waiting for market direction"))
	if image_rect != null:
		_apply_texture_to_rect(image_rect, String(item.get("image_path", "")))
	card.set_meta("news_item", item)


func _configure_headline_cards() -> void:
	for card: Panel in _headline_cards:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = HEADLINE_CARD_CURSOR
		card.modulate = HEADLINE_CARD_NORMAL_MODULATE
		_disable_child_mouse_filter(card)
		if not card.gui_input.is_connected(_on_headline_card_gui_input.bind(card)):
			card.gui_input.connect(_on_headline_card_gui_input.bind(card))
		if not card.mouse_exited.is_connected(_on_headline_card_mouse_exited.bind(card)):
			card.mouse_exited.connect(_on_headline_card_mouse_exited.bind(card))


func _on_headline_card_gui_input(event: InputEvent, card: Panel) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_headline_press_state[card] = true
			card.modulate = HEADLINE_CARD_PRESSED_MODULATE
			return
		var was_pressed: bool = bool(_headline_press_state.get(card, false))
		_headline_press_state.erase(card)
		card.modulate = HEADLINE_CARD_NORMAL_MODULATE
		if was_pressed and card.get_global_rect().has_point(mouse_button.global_position):
			_emit_headline_article_requested(card)
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_headline_press_state[card] = true
			card.modulate = HEADLINE_CARD_PRESSED_MODULATE
			return
		var was_pressed_touch: bool = bool(_headline_press_state.get(card, false))
		_headline_press_state.erase(card)
		card.modulate = HEADLINE_CARD_NORMAL_MODULATE
		if was_pressed_touch and card.get_global_rect().has_point(touch_event.position):
			_emit_headline_article_requested(card)


func _on_headline_card_mouse_exited(card: Panel) -> void:
	if bool(_headline_press_state.get(card, false)):
		return
	card.modulate = HEADLINE_CARD_NORMAL_MODULATE


func _emit_headline_article_requested(card: Panel) -> void:
	var article: Variant = card.get_meta("news_item", {})
	if article is Dictionary and not (article as Dictionary).is_empty():
		_on_article_requested(article as Dictionary)


func _clear_headline_press_state() -> void:
	for card_variant: Variant in _headline_press_state.keys():
		var card: Panel = card_variant as Panel
		if card != null and is_instance_valid(card):
			card.modulate = HEADLINE_CARD_NORMAL_MODULATE
	_headline_press_state.clear()


func _disable_child_mouse_filter(root: Control) -> void:
	for child: Node in root.get_children():
		if child is Control:
			var child_control: Control = child as Control
			child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_disable_child_mouse_filter(child_control)


func _connect_time_system() -> void:
	if _time_system == null or not _time_system.has_signal(DATE_SIGNAL_NAME):
		return
	var callback: Callable = Callable(self, "_on_game_date_changed")
	if not _time_system.is_connected(DATE_SIGNAL_NAME, callback):
		_time_system.connect(DATE_SIGNAL_NAME, callback)


func _on_game_date_changed(_year: int, _month: int, _day: int) -> void:
	_refresh_news_feed()


func _get_current_date_data() -> Dictionary:
	if _time_system != null and _time_system.has_method(DATE_METHOD_NAME):
		var date_data: Dictionary = _time_system.call(DATE_METHOD_NAME) as Dictionary
		if not date_data.is_empty():
			return date_data
	return {
		"year": 2026,
		"month": 7,
		"day": 15,
		"slot": 0,
		"clock_hour": 9,
		"clock_minute": 0,
	}


func _get_filter_bar_controller() -> Node:
	if _filter_bar_controller != null and is_instance_valid(_filter_bar_controller):
		return _filter_bar_controller
	_filter_bar_controller = _resolve_filter_bar_controller()
	return _filter_bar_controller


func _resolve_filter_bar_controller() -> Node:
	if not filter_bar_path.is_empty():
		var resolved: Node = get_node_or_null(filter_bar_path)
		if resolved != null:
			return resolved
	return _find_filter_bar_candidate(self)


func _resolve_headline_root() -> Control:
	if not headline_root_path.is_empty():
		return get_node_or_null(headline_root_path) as Control
	for child: Node in _find_descendants_of_type(self, Panel):
		var panel_child: Panel = child as Panel
		if _find_hbox_with_panel_children(panel_child, 3) != null and _find_label_by_name(panel_child, HEADLINE_TITLE_NAME) != null:
			return panel_child
	return null


func _resolve_headline_track() -> HBoxContainer:
	if _headline_root == null:
		return null
	return _find_hbox_with_panel_children(_headline_root, 3)


func _resolve_quick_list() -> VBoxContainer:
	if not quick_list_path.is_empty():
		return get_node_or_null(quick_list_path) as VBoxContainer
	return _find_vbox_by_name(self, QUICK_LIST_NAME)


func _resolve_detail_root() -> Control:
	if not detail_root_path.is_empty():
		return get_node_or_null(detail_root_path) as Control
	return _find_control_by_name(self, DETAIL_ROOT_NAME)


func _resolve_time_system() -> Node:
	if not time_system_path.is_empty():
		var resolved: Node = get_node_or_null(time_system_path)
		if resolved != null:
			return resolved
	return get_node_or_null(TIME_SYSTEM_FALLBACK_PATH)


func _collect_headline_cards() -> void:
	_headline_cards.clear()
	if _headline_track == null:
		return
	for child: Node in _headline_track.get_children():
		if child is Panel:
			_headline_cards.append(child as Panel)


func _find_filter_bar_candidate(root: Node) -> Node:
	for child: Node in root.get_children():
		if child is HBoxContainer and _count_button_children(child) >= 3:
			var parent_node: Node = child.get_parent()
			if parent_node is Panel:
				return parent_node
		var found: Node = _find_filter_bar_candidate(child)
		if found != null:
			return found
	return null


func _find_hbox_with_panel_children(root: Node, minimum_panels: int) -> HBoxContainer:
	for child: Node in root.get_children():
		if child is HBoxContainer:
			var box: HBoxContainer = child as HBoxContainer
			if _count_panel_children(box) >= minimum_panels:
				return box
		var nested: HBoxContainer = _find_hbox_with_panel_children(child, minimum_panels)
		if nested != null:
			return nested
	return null


func _find_descendants_of_type(root: Node, target_type: Variant) -> Array[Node]:
	var results: Array[Node] = []
	for child: Node in root.get_children():
		if is_instance_of(child, target_type):
			results.append(child)
		results.append_array(_find_descendants_of_type(child, target_type))
	return results


func _find_label_by_name(root: Node, target_name: String) -> Label:
	for child: Node in root.get_children():
		if child is Label and String(child.name) == target_name:
			return child as Label
		var nested: Label = _find_label_by_name(child, target_name)
		if nested != null:
			return nested
	return null


func _find_texture_rect_by_name(root: Node, target_name: String) -> TextureRect:
	for child: Node in root.get_children():
		if child is TextureRect and String(child.name) == target_name:
			return child as TextureRect
		var nested: TextureRect = _find_texture_rect_by_name(child, target_name)
		if nested != null:
			return nested
	return null


func _find_control_by_name(root: Node, target_name: String) -> Control:
	for child: Node in root.get_children():
		if child is Control and String(child.name) == target_name:
			return child as Control
		var nested: Control = _find_control_by_name(child, target_name)
		if nested != null:
			return nested
	return null


func _find_scroll_container_by_name(root: Node, target_name: String) -> ScrollContainer:
	for child: Node in root.get_children():
		if child is ScrollContainer and String(child.name) == target_name:
			return child as ScrollContainer
		var nested: ScrollContainer = _find_scroll_container_by_name(child, target_name)
		if nested != null:
			return nested
	return null


func _find_vbox_by_name(root: Node, target_name: String) -> VBoxContainer:
	for child: Node in root.get_children():
		if child is VBoxContainer and String(child.name) == target_name:
			return child as VBoxContainer
		var nested: VBoxContainer = _find_vbox_by_name(child, target_name)
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


func apply_texture_to_optional_rect(image_rect: TextureRect, texture_path: String) -> void:
	_apply_texture_to_rect(image_rect, texture_path)


func _count_button_children(root: Node) -> int:
	var count: int = 0
	for child: Node in root.get_children():
		if child is Button:
			count += 1
	return count


func _count_panel_children(root: Node) -> int:
	var count: int = 0
	for child: Node in root.get_children():
		if child is Panel:
			count += 1
	return count
