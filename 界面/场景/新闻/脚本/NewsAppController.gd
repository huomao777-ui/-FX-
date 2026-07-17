extends Control
class_name NewsAppController

const TIME_SYSTEM_FALLBACK_PATH: String = "/root/GameDataManager/TimeSystem"
const HEADLINE_CARD_NORMAL_MODULATE: Color = Color(1, 1, 1, 1)
const HEADLINE_CARD_PRESSED_MODULATE: Color = Color(0.92, 0.92, 0.92, 1)

@export var filter_bar_path: NodePath
@export var headline_track_path: NodePath
@export var headline_carousel_path: NodePath
@export var main_scroll_path: NodePath
@export var content_root_path: NodePath
@export var page_background_path: NodePath
@export var quick_section_path: NodePath
@export var quick_list_path: NodePath
@export var detail_root_path: NodePath
@export var time_system_path: NodePath = NodePath(TIME_SYSTEM_FALLBACK_PATH)
@export var time_signal_name: String = "日期变化"
@export var time_method_name: String = "获取当前日期数据"

var _filter_bar_controller: Node = null
var _headline_track: HBoxContainer = null
var _headline_carousel: NewsHeadlineCarouselController = null
var _time_system: Node = null
var _feed_provider: NewsRuntimeFeedProvider = NewsRuntimeFeedProvider.new()
var _list_controller: NewsFeedListController = NewsFeedListController.new()
var _detail_controller: NewsArticleDetailController = NewsArticleDetailController.new()
var _headline_cards: Array[Panel] = []
var _headline_press_state: Dictionary = {}
var _cached_feed: Dictionary = {}
var _current_date: Dictionary = {}
var _article_history: Array[Dictionary] = []


func _ready() -> void:
	add_child(_list_controller)
	add_child(_detail_controller)
	_initialize_page_state()
	_bind_feature_controllers()
	_refresh_news_feed()


func execute_app_back() -> bool:
	var filter_bar: Node = _get_filter_bar_controller()
	if filter_bar != null:
		if filter_bar.has_method("execute_app_back") and bool(filter_bar.call("execute_app_back")):
			return true
		if filter_bar.has_method("close_all_popups") and bool(filter_bar.call("close_all_popups")):
			return true
	if _detail_controller != null and _detail_controller.is_visible():
		if _detail_controller.hide_detail():
			return true
	return false


func 执行APP内部回退() -> bool:
	return execute_app_back()


func refresh_news_feed() -> void:
	_refresh_news_feed()


func _initialize_page_state() -> void:
	_filter_bar_controller = get_node_or_null(filter_bar_path)
	_headline_track = get_node_or_null(headline_track_path) as HBoxContainer
	_headline_carousel = get_node_or_null(headline_carousel_path) as NewsHeadlineCarouselController
	_collect_headline_cards()
	_configure_headline_cards()
	_time_system = _resolve_time_system()
	_connect_time_system()


func _bind_feature_controllers() -> void:
	var main_scroll: ScrollContainer = get_node_or_null(main_scroll_path) as ScrollContainer
	var content_root: Control = get_node_or_null(content_root_path) as Control
	var page_background: Control = get_node_or_null(page_background_path) as Control
	var quick_section: Control = get_node_or_null(quick_section_path) as Control
	var quick_list: VBoxContainer = get_node_or_null(quick_list_path) as VBoxContainer
	_list_controller.bind_runtime_nodes(_feed_provider, main_scroll, content_root, page_background, quick_section, quick_list)
	if not _list_controller.article_requested.is_connected(_on_article_requested):
		_list_controller.article_requested.connect(_on_article_requested)

	var detail_root: Control = get_node_or_null(detail_root_path) as Control
	_configure_detail_controller_paths(detail_root)
	_detail_controller.bind_detail_root(detail_root)
	if not _detail_controller.recommendation_requested.is_connected(_on_recommendation_requested):
		_detail_controller.recommendation_requested.connect(_on_recommendation_requested)
	if not _detail_controller.closed.is_connected(_on_detail_closed):
		_detail_controller.closed.connect(_on_detail_closed)
	if not _detail_controller.back_requested.is_connected(_on_detail_back_requested):
		_detail_controller.back_requested.connect(_on_detail_back_requested)
	if _headline_carousel != null and not _headline_carousel.headline_activated.is_connected(_on_headline_activated):
		_headline_carousel.headline_activated.connect(_on_headline_activated)


func _refresh_news_feed() -> void:
	_current_date = _get_current_date_data()
	_cached_feed = _feed_provider.build_feed(_current_date)
	_apply_headlines(_get_feed_array("headlines"))
	_list_controller.refresh_feed(_current_date)
	if _detail_controller.is_visible():
		_clear_article_history()
		_detail_controller.hide_detail()


func _on_article_requested(article: Dictionary) -> void:
	_open_article(article, true)


func _on_recommendation_requested(article: Dictionary) -> void:
	_open_article(article, true)


func _on_detail_closed() -> void:
	_list_controller.close_open_card_state()
	_clear_headline_press_state()
	_clear_article_history()


func _on_detail_back_requested() -> void:
	if _article_history.size() <= 1:
		_clear_article_history()
		_detail_controller.hide_detail()
		return
	_article_history.pop_back()
	var previous_article: Dictionary = (_article_history[_article_history.size() - 1] as Dictionary).duplicate(true)
	_show_article_without_history_push(previous_article)


func _on_headline_activated(card: Panel, _index: int) -> void:
	_emit_headline_article_requested(card)


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
	var title_label: Label = _find_first_label(card)
	var image_rect: TextureRect = _find_first_texture_rect(card)
	if title_label != null:
		title_label.text = String(item.get("headline", "No headline"))
	if image_rect != null:
		_apply_texture_to_rect(image_rect, String(item.get("image_path", "")))
	card.set_meta("news_item", item)


func _configure_headline_cards() -> void:
	if _headline_carousel != null:
		for card: Panel in _headline_cards:
			card.modulate = HEADLINE_CARD_NORMAL_MODULATE
		return
	for card: Panel in _headline_cards:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
		_open_article(article as Dictionary, true)


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
	if _time_system == null or time_signal_name.is_empty() or not _time_system.has_signal(time_signal_name):
		return
	var callback: Callable = Callable(self, "_on_game_date_changed")
	if not _time_system.is_connected(time_signal_name, callback):
		_time_system.connect(time_signal_name, callback)


func _on_game_date_changed(_year: int, _month: int, _day: int) -> void:
	_refresh_news_feed()


func _get_current_date_data() -> Dictionary:
	if _time_system != null and not time_method_name.is_empty() and _time_system.has_method(time_method_name):
		var date_data: Dictionary = _time_system.call(time_method_name) as Dictionary
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
	_filter_bar_controller = get_node_or_null(filter_bar_path)
	return _filter_bar_controller


func _configure_detail_controller_paths(detail_root: Control) -> void:
	if detail_root == null:
		return
	_set_detail_path(&"title_label_path", detail_root.get_node_or_null("背景弹窗/详情滚动区_商务版/内容根/纵向内容/标题区/新闻标题"))
	_set_detail_path(&"time_label_path", detail_root.get_node_or_null("背景弹窗/详情滚动区_商务版/内容根/纵向内容/资讯信息行/时间"))
	_set_detail_path(&"category_label_path", detail_root.get_node_or_null("背景弹窗/详情滚动区_商务版/内容根/纵向内容/资讯信息行/分类"))
	_set_detail_path(&"abstract_label_path", detail_root.get_node_or_null("背景弹窗/详情滚动区_商务版/内容根/纵向内容/摘要"))
	_set_detail_path(&"image_panel_path", detail_root.get_node_or_null("背景弹窗/详情滚动区_商务版/内容根/纵向内容/插图区"))
	_set_detail_path(&"image_rect_path", detail_root.get_node_or_null("背景弹窗/详情滚动区_商务版/内容根/纵向内容/插图区/插图"))
	_set_detail_path(&"summary_label_path", detail_root.get_node_or_null("背景弹窗/详情滚动区_商务版/内容根/纵向内容/正文分段区/现象总结"))
	_set_detail_path(&"trend_label_path", detail_root.get_node_or_null("背景弹窗/详情滚动区_商务版/内容根/纵向内容/正文分段区/趋势预测"))
	_set_detail_path(&"tail_label_path", detail_root.get_node_or_null("背景弹窗/详情滚动区_商务版/内容根/纵向内容/正文分段区/末尾提示"))
	_set_detail_path(&"back_button_path", detail_root.get_node_or_null("背景弹窗/详情滚动区_商务版/内容根/纵向内容/回退行/回退按钮"))
	_set_detail_path(&"recommend_list_path", detail_root.get_node_or_null("背景弹窗/详情滚动区_商务版/内容根/纵向内容/推荐资讯行"))


func _set_detail_path(property_name: StringName, target_node: Node) -> void:
	if target_node == null:
		return
	_detail_controller.set(property_name, _detail_controller.get_path_to(target_node))


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


func _open_article(article: Dictionary, push_history: bool) -> void:
	if article.is_empty():
		return
	if push_history:
		_push_article_history(article)
	_show_article_without_history_push(article)


func _show_article_without_history_push(article: Dictionary) -> void:
	var recommendations: Array[Dictionary] = _build_recommendations_for(article)
	_detail_controller.show_article(article, recommendations)


func _push_article_history(article: Dictionary) -> void:
	var article_copy: Dictionary = article.duplicate(true)
	if _article_history.is_empty():
		_article_history.append(article_copy)
		return
	var latest_article: Dictionary = (_article_history[_article_history.size() - 1] as Dictionary).duplicate(true)
	if _build_article_key(latest_article) == _build_article_key(article_copy):
		_article_history[_article_history.size() - 1] = article_copy
		return
	_article_history.append(article_copy)


func _clear_article_history() -> void:
	_article_history.clear()


func _build_article_key(article: Dictionary) -> String:
	return "%s|%s|%s" % [String(article.get("template_id", "")), String(article.get("date_key", "")), String(article.get("time_label", ""))]


func _build_recommendations_for(article: Dictionary) -> Array[Dictionary]:
	var recommendations: Array[Dictionary] = []
	var all_loaded_articles: Array[Dictionary] = _list_controller.get_loaded_articles()
	var source_key: String = _build_article_key(article)
	for candidate: Dictionary in all_loaded_articles:
		if _build_article_key(candidate) == source_key:
			continue
		recommendations.append(candidate)
		if recommendations.size() >= 3:
			break
	return recommendations


func _find_first_label(root: Node) -> Label:
	for child: Node in root.get_children():
		if child is Label:
			return child as Label
		var nested: Label = _find_first_label(child)
		if nested != null:
			return nested
	return null


func _find_first_texture_rect(root: Node) -> TextureRect:
	for child: Node in root.get_children():
		if child is TextureRect:
			return child as TextureRect
		var nested: TextureRect = _find_first_texture_rect(child)
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
