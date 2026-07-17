extends Node
class_name NewsArticleDetailController

const TITLE_NAME: String = "新闻标题"
const TIME_NAME: String = "时间"
const CATEGORY_NAME: String = "分类"
const ABSTRACT_NAME: String = "摘要"
const IMAGE_PANEL_NAME: String = "插图区"
const IMAGE_NAME: String = "插图"
const SUMMARY_NAME: String = "现象总结"
const TREND_NAME: String = "趋势预测"
const TAIL_NAME: String = "末尾提示"
const BACK_BUTTON_NAME: String = "回退按钮"
const RECOMMEND_LIST_NAME: String = "推荐资讯行"
const RECOMMEND_CARD_NAME_PREFIX: String = "资讯卡"
const RECOMMEND_IMAGE_PANEL_NAME: String = "右侧图片卡"
const RECOMMEND_IMAGE_NAME: String = "图片"
const RECOMMEND_TIME_NAME: String = "时间"
const RECOMMEND_TITLE_NAME: String = "标题"
const RECOMMEND_SUMMARY_NAME: String = "摘要"
const RECOMMEND_CATEGORY_A: String = "标签"
const RECOMMEND_CATEGORY_B: String = "分类"

signal closed
signal recommendation_requested(article: Dictionary)

var _detail_root: Control = null
var _title_label: Label = null
var _time_label: Label = null
var _category_label: Label = null
var _abstract_label: Label = null
var _image_panel: Panel = null
var _image_rect: TextureRect = null
var _summary_label: Label = null
var _trend_label: Label = null
var _tail_label: Label = null
var _back_button: Button = null
var _recommend_cards: Array[Panel] = []
var _recommend_press_state: Dictionary = {}


func bind_detail_root(detail_root: Control) -> void:
	_detail_root = detail_root
	_title_label = _find_label_by_name(detail_root, TITLE_NAME)
	_time_label = _find_label_by_name(detail_root, TIME_NAME)
	_category_label = _find_label_by_name(detail_root, CATEGORY_NAME)
	_abstract_label = _find_label_by_name(detail_root, ABSTRACT_NAME)
	_image_panel = _find_panel_by_name(detail_root, IMAGE_PANEL_NAME)
	_image_rect = _find_texture_rect_by_name(detail_root, IMAGE_NAME)
	_summary_label = _find_label_by_name(detail_root, SUMMARY_NAME)
	_trend_label = _find_label_by_name(detail_root, TREND_NAME)
	_tail_label = _find_label_by_name(detail_root, TAIL_NAME)
	_back_button = _find_button_by_name(detail_root, BACK_BUTTON_NAME)
	_collect_recommend_cards()
	_connect_back_button()
	if _detail_root != null:
		_detail_root.visible = false


func show_article(article: Dictionary, recommendations: Array[Dictionary]) -> void:
	if _detail_root == null:
		return
	_fill_main_article(article)
	_fill_recommendations(recommendations)
	_detail_root.visible = true


func hide_detail() -> bool:
	if _detail_root == null or not _detail_root.visible:
		return false
	_detail_root.visible = false
	_clear_pressed_recommendations()
	closed.emit()
	return true


func is_visible() -> bool:
	return _detail_root != null and _detail_root.visible


func _connect_back_button() -> void:
	if _back_button == null:
		return
	var callback: Callable = Callable(self, "_on_back_button_pressed")
	if not _back_button.pressed.is_connected(callback):
		_back_button.pressed.connect(callback)


func _on_back_button_pressed() -> void:
	hide_detail()


func _fill_main_article(article: Dictionary) -> void:
	if _title_label != null:
		_title_label.text = String(article.get("headline", "暂无新闻标题"))
	if _time_label != null:
		_time_label.text = String(article.get("time_text", article.get("time_label", "--:--")))
	if _category_label != null:
		_category_label.text = String(article.get("category", article.get("category_short", "全部资讯")))
	if _abstract_label != null:
		_abstract_label.text = String(article.get("abstract", article.get("summary", "暂无摘要")))
	if _summary_label != null:
		_summary_label.text = String(article.get("summary", "暂无现象总结"))
	if _trend_label != null:
		_trend_label.text = String(article.get("trend_outlook", "暂无趋势预测"))
	if _tail_label != null:
		_tail_label.text = String(article.get("analysis_tail", "暂无末尾提示"))

	var has_image: bool = bool(article.get("has_image", false))
	if _image_panel != null:
		_image_panel.visible = has_image
	if _image_rect != null:
		if has_image:
			_apply_texture_to_rect(_image_rect, String(article.get("image_path", "")))
		else:
			_image_rect.texture = null


func _fill_recommendations(recommendations: Array[Dictionary]) -> void:
	for index: int in range(_recommend_cards.size()):
		var card: Panel = _recommend_cards[index]
		if card == null:
			continue
		if index < recommendations.size():
			var item: Dictionary = recommendations[index]
			card.visible = true
			card.set_meta("news_item", item)
			_apply_item_to_recommend_card(card, item)
		else:
			card.visible = false
			card.remove_meta("news_item")
	_clear_pressed_recommendations()


func _collect_recommend_cards() -> void:
	_recommend_cards.clear()
	if _detail_root == null:
		return
	var recommend_root: Node = _find_node_by_name(_detail_root, RECOMMEND_LIST_NAME)
	if recommend_root == null:
		return
	for child: Node in recommend_root.get_children():
		if child is Panel and String(child.name).begins_with(RECOMMEND_CARD_NAME_PREFIX):
			var card: Panel = child as Panel
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_disable_child_mouse_filter(card)
			if not card.gui_input.is_connected(_on_recommend_card_gui_input.bind(card)):
				card.gui_input.connect(_on_recommend_card_gui_input.bind(card))
			if not card.mouse_exited.is_connected(_on_recommend_card_mouse_exited.bind(card)):
				card.mouse_exited.connect(_on_recommend_card_mouse_exited.bind(card))
			_recommend_cards.append(card)


func _apply_item_to_recommend_card(card: Panel, item: Dictionary) -> void:
	var category_label: Label = _find_first_label(card, [RECOMMEND_CATEGORY_A, RECOMMEND_CATEGORY_B])
	var time_label: Label = _find_label_by_name(card, RECOMMEND_TIME_NAME)
	var title_label: Label = _find_label_by_name(card, RECOMMEND_TITLE_NAME)
	var summary_label: Label = _find_label_by_name(card, RECOMMEND_SUMMARY_NAME)
	if category_label != null:
		category_label.text = String(item.get("category_short", "全部资讯"))
	if time_label != null:
		time_label.text = String(item.get("time_label", "--:--"))
	if title_label != null:
		title_label.text = String(item.get("headline", "暂无标题"))
	if summary_label != null:
		summary_label.text = String(item.get("summary", "暂无摘要"))

	var image_panel: Panel = _find_panel_by_name(card, RECOMMEND_IMAGE_PANEL_NAME)
	var image_rect: TextureRect = _find_texture_rect_by_name(card, RECOMMEND_IMAGE_NAME)
	var has_image: bool = bool(item.get("has_image", false))
	if image_panel != null:
		image_panel.visible = has_image
	if image_rect != null:
		if has_image:
			_apply_texture_to_rect(image_rect, String(item.get("image_path", "")))
		else:
			image_rect.texture = null


func _on_recommend_card_gui_input(event: InputEvent, card: Panel) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_recommend_press_state[card] = true
			card.modulate = Color(0.92, 0.92, 0.92, 1)
			return
		var was_pressed: bool = bool(_recommend_press_state.get(card, false))
		_recommend_press_state.erase(card)
		card.modulate = Color(1, 1, 1, 1)
		if was_pressed and card.get_global_rect().has_point(mouse_button.global_position):
			_emit_recommendation_requested(card)
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_recommend_press_state[card] = true
			card.modulate = Color(0.92, 0.92, 0.92, 1)
			return
		var was_pressed_touch: bool = bool(_recommend_press_state.get(card, false))
		_recommend_press_state.erase(card)
		card.modulate = Color(1, 1, 1, 1)
		if was_pressed_touch and card.get_global_rect().has_point(touch_event.position):
			_emit_recommendation_requested(card)


func _on_recommend_card_mouse_exited(card: Panel) -> void:
	if bool(_recommend_press_state.get(card, false)):
		return
	card.modulate = Color(1, 1, 1, 1)


func _emit_recommendation_requested(card: Panel) -> void:
	var article: Variant = card.get_meta("news_item", {})
	if article is Dictionary:
		recommendation_requested.emit(article as Dictionary)


func _clear_pressed_recommendations() -> void:
	for card_variant: Variant in _recommend_press_state.keys():
		var card: Panel = card_variant as Panel
		if card != null and is_instance_valid(card):
			card.modulate = Color(1, 1, 1, 1)
	_recommend_press_state.clear()


func _disable_child_mouse_filter(root: Control) -> void:
	for child: Node in root.get_children():
		if child is Control:
			var child_control: Control = child as Control
			child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_disable_child_mouse_filter(child_control)


func _find_node_by_name(root: Node, target_name: String) -> Node:
	for child: Node in root.get_children():
		if String(child.name) == target_name:
			return child
		var nested: Node = _find_node_by_name(child, target_name)
		if nested != null:
			return nested
	return null


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


func _find_panel_by_name(root: Node, target_name: String) -> Panel:
	for child: Node in root.get_children():
		if child is Panel and String(child.name) == target_name:
			return child as Panel
		var nested: Panel = _find_panel_by_name(child, target_name)
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


func _find_button_by_name(root: Node, target_name: String) -> Button:
	for child: Node in root.get_children():
		if child is Button and String(child.name) == target_name:
			return child as Button
		var nested: Button = _find_button_by_name(child, target_name)
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
