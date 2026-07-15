extends Control
class_name NewsAppController

const FEED_PROVIDER_SCRIPT = preload("res://\u754c\u9762/\u573a\u666f/\u65b0\u95fb/\u811a\u672c/NewsRuntimeFeedProvider.gd")
const TIME_SYSTEM_FALLBACK_PATH: String = "/root/GameDataManager/TimeSystem"
const HEADLINE_TITLE_NAME: String = "\u65b0\u95fb\u6807\u9898"
const HEADLINE_IMAGE_NAME: String = "\u8d44\u8baf\u56fe"
const LIST_TIME_NAME: String = "\u65f6\u95f4"
const LIST_TITLE_NAME: String = "\u6807\u9898"
const LIST_SUMMARY_NAME: String = "\u6458\u8981"
const LIST_CATEGORY_NAME_A: String = "\u5206\u7c7b"
const LIST_CATEGORY_NAME_B: String = "\u6807\u7b7e"
const LIST_IMAGE_PANEL_NAME: String = "\u53f3\u4fa7\u56fe\u7247\u5361"
const LIST_IMAGE_NAME: String = "\u56fe\u7247"
const DATE_SIGNAL_NAME: String = "\u65e5\u671f\u53d8\u5316"
const DATE_METHOD_NAME: String = "\u83b7\u53d6\u5f53\u524d\u65e5\u671f\u6570\u636e"

@export var filter_bar_path: NodePath
@export var headline_root_path: NodePath
@export var quick_list_path: NodePath
@export var time_system_path: NodePath = NodePath(TIME_SYSTEM_FALLBACK_PATH)

var _filter_bar_controller: Node = null
var _headline_root: Control = null
var _headline_track: HBoxContainer = null
var _quick_list: VBoxContainer = null
var _time_system: Node = null
var _feed_provider: NewsRuntimeFeedProvider = NewsRuntimeFeedProvider.new()
var _headline_cards: Array[Panel] = []
var _list_cards: Array[Panel] = []
var _cached_feed: Dictionary = {}


func _ready() -> void:
	_initialize_page_state()
	_refresh_news_feed()


func execute_app_back() -> bool:
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
	_quick_list = _resolve_quick_list()
	_collect_headline_cards()
	_collect_list_cards()
	_time_system = _resolve_time_system()
	_connect_time_system()


func _refresh_news_feed() -> void:
	var current_date: Dictionary = _get_current_date_data()
	_cached_feed = _feed_provider.build_feed(current_date)
	_apply_headlines(_get_feed_array("headlines"))
	_apply_list_items(_get_feed_array("list_items"))


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
			item = headline_items[index] as Dictionary
		_apply_headline_card(_headline_cards[index], item)


func _apply_headline_card(card: Panel, item: Dictionary) -> void:
	var title_label: Label = _find_label_by_name(card, HEADLINE_TITLE_NAME)
	var image_rect: TextureRect = _find_texture_rect_by_name(card, HEADLINE_IMAGE_NAME)
	if title_label != null:
		title_label.text = String(item.get("headline", "Waiting for market direction"))
	if image_rect != null:
		_apply_texture_to_rect(image_rect, String(item.get("image_path", "")))


func _apply_list_items(raw_items: Array) -> void:
	if _list_cards.is_empty():
		return
	var ordered_items: Array[Dictionary] = _arrange_items_for_card_layout(raw_items)
	for index: int in range(_list_cards.size()):
		var item: Dictionary = {}
		if index < ordered_items.size():
			item = ordered_items[index]
		_apply_list_card(_list_cards[index], item)


func _arrange_items_for_card_layout(raw_items: Array) -> Array[Dictionary]:
	var items_with_images: Array[Dictionary] = []
	var text_only_items: Array[Dictionary] = []
	for raw_item: Variant in raw_items:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item as Dictionary
		if bool(item.get("has_image", false)):
			items_with_images.append(item)
		else:
			text_only_items.append(item)

	var ordered: Array[Dictionary] = []
	for card: Panel in _list_cards:
		var expects_image: bool = _find_panel_by_name(card, LIST_IMAGE_PANEL_NAME) != null
		if expects_image and not items_with_images.is_empty():
			ordered.append(items_with_images.pop_front())
		elif not text_only_items.is_empty():
			ordered.append(text_only_items.pop_front())
		elif not items_with_images.is_empty():
			ordered.append(items_with_images.pop_front())
		else:
			ordered.append({})
	return ordered


func _apply_list_card(card: Panel, item: Dictionary) -> void:
	var category_text: String = String(item.get("category_short", "ALL"))
	var time_text: String = String(item.get("time_label", "--:--"))
	var headline_text: String = String(item.get("headline", "Market is waiting for the next catalyst"))
	var summary_text: String = String(item.get("summary", "No news item is available for this slot."))

	var category_label: Label = _find_first_label(card, [LIST_CATEGORY_NAME_A, LIST_CATEGORY_NAME_B])
	var time_label: Label = _find_label_by_name(card, LIST_TIME_NAME)
	var title_label: Label = _find_label_by_name(card, LIST_TITLE_NAME)
	var summary_label: Label = _find_label_by_name(card, LIST_SUMMARY_NAME)
	if category_label != null:
		category_label.text = category_text
	if time_label != null:
		time_label.text = time_text
	if title_label != null:
		title_label.text = headline_text
	if summary_label != null:
		summary_label.text = summary_text

	var image_panel: Panel = _find_panel_by_name(card, LIST_IMAGE_PANEL_NAME)
	var image_rect: TextureRect = _find_texture_rect_by_name(card, LIST_IMAGE_NAME)
	var has_image: bool = bool(item.get("has_image", false))
	if image_panel != null:
		image_panel.visible = has_image
	if image_rect != null:
		if has_image:
			apply_texture_to_optional_rect(image_rect, String(item.get("image_path", "")))
		else:
			image_rect.texture = null


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
	for child: Node in _find_descendants_of_type(self, VBoxContainer):
		var container: VBoxContainer = child as VBoxContainer
		if _count_panel_children(container) >= 5 and _find_label_by_name(container, LIST_TITLE_NAME) != null:
			return container
	return null


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


func _collect_list_cards() -> void:
	_list_cards.clear()
	if _quick_list == null:
		return
	for child: Node in _quick_list.get_children():
		if child is Panel:
			_list_cards.append(child as Panel)


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
		return
	var texture_resource: Texture2D = load(texture_path) as Texture2D
	if texture_resource != null:
		image_rect.texture = texture_resource


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
