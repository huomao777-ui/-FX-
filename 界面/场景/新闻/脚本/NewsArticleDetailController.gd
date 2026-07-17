extends Node
class_name NewsArticleDetailController

# Main article title label in the detail page header.
# Bind this to the large headline text shown after opening an article.
@export var title_label_path: NodePath
# Time label shown near the top of the detail page.
# Usually displays publish time, in-game time, or date text for the current article.
@export var time_label_path: NodePath
# Category label for the current article.
# Bind this to the small tag text such as 时政风险 / 经济数据 / 货币政策.
@export var category_label_path: NodePath
# Abstract / lead paragraph shown before the longer body sections.
# This is the short summary near the top, not the later analysis paragraphs.
@export var abstract_label_path: NodePath
# Optional image container inside the detail page.
# The whole block is hidden when the opened article does not provide an image asset.
@export var image_panel_path: NodePath
# TextureRect inside the optional image container.
# Bind this to the actual image node, not the outer wrapper panel.
@export var image_rect_path: NodePath
# Main body paragraph: phenomenon summary or first long-form text block.
@export var summary_label_path: NodePath
# Secondary body paragraph: trend outlook / market expectation text block.
@export var trend_label_path: NodePath
# Final tail note paragraph: risk hint / conclusion / footer note.
@export var tail_label_path: NodePath
# Back button in the top-left corner of the detail page.
# It steps back to the previous article in history instead of exiting straight to the main list.
@export var back_button_path: NodePath
# Container that directly holds the 3 recommendation cards at the bottom.
# The controller scans child Panel nodes here and turns them into clickable recommendations.
@export var recommend_list_path: NodePath

signal closed
signal back_requested
signal recommendation_requested(article: Dictionary)

var _detail_root: Control = null
var _title_label: Label = null
var _time_label: Label = null
var _category_label: Label = null
var _abstract_label: Label = null
var _image_panel: Control = null
var _image_rect: TextureRect = null
var _summary_label: Label = null
var _trend_label: Label = null
var _tail_label: Label = null
var _back_button: Button = null
var _recommend_cards: Array[Panel] = []
var _recommend_press_state: Dictionary = {}


# Cache local nodes once, then let the controller manage only this popup.
func bind_detail_root(detail_root: Control) -> void:
	_detail_root = detail_root
	_title_label = _resolve_label(title_label_path)
	_time_label = _resolve_label(time_label_path)
	_category_label = _resolve_label(category_label_path)
	_abstract_label = _resolve_label(abstract_label_path)
	_image_panel = _resolve_control(image_panel_path)
	_image_rect = _resolve_texture_rect(image_rect_path)
	_summary_label = _resolve_label(summary_label_path)
	_trend_label = _resolve_label(trend_label_path)
	_tail_label = _resolve_label(tail_label_path)
	_back_button = _resolve_button(back_button_path)
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


# The back button steps one article back in history, not all the way out.
func _on_back_button_pressed() -> void:
	back_requested.emit()


func _fill_main_article(article: Dictionary) -> void:
	if _title_label != null:
		_title_label.text = String(article.get("headline", "No headline"))
	if _time_label != null:
		_time_label.text = String(article.get("time_text", article.get("time_label", "--:--")))
	if _category_label != null:
		_category_label.text = String(article.get("category", article.get("category_short", "All")))
	if _abstract_label != null:
		_abstract_label.text = String(article.get("abstract", article.get("summary", "No summary")))
	if _summary_label != null:
		_summary_label.text = String(article.get("summary", "No summary"))
	if _trend_label != null:
		_trend_label.text = String(article.get("trend_outlook", "No outlook"))
	if _tail_label != null:
		_tail_label.text = String(article.get("analysis_tail", "No note"))

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
	var recommend_root: Node = get_node_or_null(recommend_list_path)
	if recommend_root == null:
		return
	for child: Node in recommend_root.get_children():
		if child is Panel:
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
	var labels: Array[Label] = _find_labels(card)
	var category_label: Label = labels[0] if labels.size() > 0 else null
	var time_label: Label = labels[1] if labels.size() > 1 else null
	var title_label: Label = labels[2] if labels.size() > 2 else null
	var summary_label: Label = labels[3] if labels.size() > 3 else null
	if category_label != null:
		category_label.text = String(item.get("category_short", "All"))
	if time_label != null:
		time_label.text = String(item.get("time_label", "--:--"))
	if title_label != null:
		title_label.text = String(item.get("headline", "No title"))
	if summary_label != null:
		summary_label.text = String(item.get("summary", "No summary"))

	var image_panel: Panel = _find_first_panel(card)
	var image_rect: TextureRect = _find_first_texture_rect(card)
	var has_image: bool = bool(item.get("has_image", false))
	if image_panel != null and image_rect != null:
		image_panel.visible = has_image
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


func _resolve_label(path: NodePath) -> Label:
	return get_node_or_null(path) as Label


func _resolve_control(path: NodePath) -> Control:
	return get_node_or_null(path) as Control


func _resolve_texture_rect(path: NodePath) -> TextureRect:
	return get_node_or_null(path) as TextureRect


func _resolve_button(path: NodePath) -> Button:
	return get_node_or_null(path) as Button


func _disable_child_mouse_filter(root: Control) -> void:
	for child: Node in root.get_children():
		if child is Control:
			var child_control: Control = child as Control
			child_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_disable_child_mouse_filter(child_control)


func _find_labels(root: Node) -> Array[Label]:
	var labels: Array[Label] = []
	for child: Node in root.get_children():
		if child is Label:
			labels.append(child as Label)
		labels.append_array(_find_labels(child))
	return labels


func _find_first_panel(root: Node) -> Panel:
	for child: Node in root.get_children():
		if child is Panel:
			return child as Panel
		var nested: Panel = _find_first_panel(child)
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
