## 描述: 全屏手机主界面控制器，管理页面滑动、应用图标拖拽和 Dock 显示
## 依赖: 子节点 软件；应用图标为 软件 下带 Button 子节点的 Control
## 状态: 初版
## 最后更新：2026-06-12
extends Control

const APP_SCENE_PATHS: Dictionary = {
	"国内炒汇": "res://界面/场景/外汇应用/国内炒汇.tscn"
}

## ===== 导出配置变量 =====

@export_group("页面滑动")
## 手机应用页宽度，用于页面切换和图标跨页定位
@export var 应用页宽度: float = 420.0
## 应用页在手机屏幕中的可视裁剪区域
@export var 页面可视区域: Rect2 = Rect2(680.0, 96.0, 440.0, 800.0)
## 图标拖拽时允许停留的手机内屏区域
@export var 手机屏幕拖拽区域: Rect2 = Rect2(680.0, 96.0, 440.0, 912.0)
## 单次滑动切页所需的最小水平距离
@export var 切页滑动距离: float = 90.0
## 判定为水平滑动时，横向距离需要大于纵向距离的倍数
@export var 横向滑动判定倍率: float = 1.25
## 页面吸附速度
@export var 页面吸附速度: float = 12.0
## 是否允许滑到左侧消息推送页
@export var 允许左侧消息页: bool = true
## 是否允许拖动图标到右侧时自动创建新页面
@export var 允许自动创建应用页: bool = true
## 跟随页面滑动的控件路径，推荐优先把天气、日历等大组件直接放到“软件”节点下
@export var 页面滑动控件路径: Array[NodePath] = []

@export_group("图标网格")
## 是否根据场景中已有图标位置自动推导 4x7 网格参数
@export var 自动推导图标网格: bool = true
## 每页应用列数
@export_range(1, 6, 1) var 每页列数: int = 4
## 每页应用行数
@export_range(1, 8, 1) var 每页行数: int = 7
## 首页顶部被天气、日历等大组件占用的行数；右侧新页面不占用这些槽位
@export_range(0, 4, 1) var 首页顶部大组件占用行数: int = 2
## 图标页面左上角
@export var 图标起点: Vector2 = Vector2(16.0, -8.0)
## 图标水平间距
@export var 图标水平间距: float = 96.0
## 图标垂直间距
@export var 图标垂直间距: float = 104.0
## 图标吸附速度
@export var 图标吸附速度: float = 18.0
## 固定大组件名称，例如 2x2 的天气、日历；随页面滑动但不参与拖拽和交换
@export var 固定大组件名称: Array[String] = ["天气", "日历"]

@export_group("拖拽")
## 按住图标超过该时间后进入拖拽
@export var 长按拖拽时间: float = 0.25
## 拖动时靠近页面边缘多少像素触发切页
@export var 拖拽切页边缘距离: float = 64.0
## 拖动到边缘后需要停留多久才触发切页，避免误触导致立刻翻页
@export var 拖拽切页停留时间: float = 0.35
## 拖拽切页冷却时间
@export var 拖拽切页冷却: float = 0.45
## 图标拖到 Dock 区域上方多少像素内时进入 Dock，过大会占用应用区底部槽位
@export var Dock吸附上方距离: float = 16.0

@export_group("Dock")
## Dock 应用名称，保持这些应用在应用页下方常驻
@export var Dock应用名称: Array[String] = ["电话", "飞信", "相机", "音乐"]
## Dock 可放置槽位数量
@export_range(1, 8, 1) var Dock槽位数量: int = 4
## Dock 左上角
@export var Dock起点: Vector2 = Vector2(32.0, 504.0)
## Dock 水平间距
@export var Dock水平间距: float = 96.0

@export_group("页面指示")
## 页面指示点中心位置，位于应用最后一行下方、Dock 上方
@export var 页面指示位置: Vector2 = Vector2(892.0, 872.0)
## 页面指示点直径
@export var 页面指示点直径: float = 8.0
## 页面指示点间距
@export var 页面指示点间距: float = 16.0
## 当前页面指示颜色
@export var 当前页面指示颜色: Color = Color(1.0, 1.0, 1.0, 0.95)
## 其他页面指示颜色
@export var 其他页面指示颜色: Color = Color(0.45, 0.45, 0.45, 0.75)

## ===== 节点引用 =====

@onready var _apps_root: Control = $软件
@onready var _dock_background: CanvasItem = get_node_or_null("灰色控件") as CanvasItem

## ===== 内部变量 =====

var _page_width: float = 420.0
var _current_page: int = 0
var _max_app_page: int = 0
var _target_root_x: float = 0.0
var _apps_root_base_position: Vector2 = Vector2.ZERO
var _press_position: Vector2 = Vector2.ZERO
var _press_time: float = 0.0
var _is_pointer_down: bool = false
var _is_swiping: bool = false
var _dragged_icon: Control = null
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_edge_timer: float = 0.0
var _drag_edge_hold_timer: float = 0.0
var _drag_edge_hold_direction: int = 0
var _icon_page: Dictionary = {}
var _icon_slot: Dictionary = {}
var _icon_target_position: Dictionary = {}
var _slot_owner: Dictionary = {}
var _dock_slot_owner: Dictionary = {}
var _dock_slot_positions: Array[Vector2] = []
var _dock_slot_centers: Array[Vector2] = []
var _app_slot_visual_offset: Vector2 = Vector2.ZERO
var _page_clip: Control = null
var _dock_root: Control = null
var _drag_root: Control = null
var _page_indicator_root: Control = null
var _clip_margin: float = 8.0
var _dock_icons: Array[Control] = []
var _app_icons: Array[Control] = []
var _sliding_widgets: Array[Control] = []
var _fixed_widgets: Array[Control] = []
var _drag_origin_page: int = 0
var _drag_origin_slot: int = 0
var _drag_started_from_dock: bool = false
var _last_drag_desired_global_position: Vector2 = Vector2.ZERO
var _has_last_drag_desired_position: bool = false

## ===== 生命周期 =====

func _ready() -> void:
	_page_width = max(应用页宽度, 1.0)
	if _dock_background == null:
		_dock_background = get_node_or_null("软件/Panel") as CanvasItem
	_collect_icons()
	_infer_layout_from_scene()
	_setup_page_clip()
	_setup_sliding_widgets()
	_setup_dock_overlay()
	_setup_drag_overlay()
	_setup_page_indicator()
	_layout_all_icons(true)
	_update_page_target(true)

func _process(delta: float) -> void:
	if _is_pointer_down and _dragged_icon == null:
		_press_time += delta
		if _press_time >= 长按拖拽时间:
			_try_begin_drag(get_global_mouse_position())

	if _dragged_icon != null:
		_update_drag(get_global_mouse_position(), delta)

	var target_position_x: float = _apps_root_base_position.x + _target_root_x
	if not is_equal_approx(_apps_root.position.x, target_position_x):
		_apps_root.position.x = lerpf(_apps_root.position.x, target_position_x, min(页面吸附速度 * delta, 1.0))

	_update_icon_snap(delta)
	_update_app_clip_visibility()

## ===== 输入处理 =====

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed and mouse_event.double_click:
			if not _is_point_inside_phone_screen(mouse_event.position):
				var viewport := get_viewport()
				_return_to_mobile_phone()
				if viewport != null:
					viewport.set_input_as_handled()
				return
			if _try_open_app_at_position(mouse_event.position):
				return
		if mouse_event.pressed:
			_on_pointer_pressed(mouse_event.position)
		else:
			_on_pointer_released(mouse_event.position)
		return

	if event is InputEventMouseMotion and _is_pointer_down and _dragged_icon == null:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		_update_swipe(motion_event.position)

## ===== 私有方法：图标收集与布局 =====

func _collect_icons() -> void:
	_app_icons.clear()
	_dock_icons.clear()
	_icon_page.clear()
	_icon_slot.clear()
	_slot_owner.clear()
	_dock_slot_owner.clear()
	_fixed_widgets.clear()
	_max_app_page = 0

	for child in _apps_root.get_children():
		if not child is Control:
			continue
		var icon: Control = child as Control
		if icon == _dock_background:
			continue

		if 固定大组件名称.has(icon.name):
			_fixed_widgets.append(icon)
		elif Dock应用名称.has(icon.name):
			_dock_icons.append(icon)
		else:
			_app_icons.append(icon)

	_app_icons.sort_custom(Callable(self, "_sort_icons_by_position"))
	_dock_icons.sort_custom(Callable(self, "_sort_icons_by_position"))

	for icon in _app_icons:
		var page: int = _infer_page_from_position(icon.position)
		var slot: int = _get_nearest_slot_from_page_position(icon.position - Vector2(page * _page_width, 0.0))
		while _slot_owner.has(_get_slot_key(page, slot)):
			slot += 1
			page += int(slot / _get_slots_per_page())
			slot %= _get_slots_per_page()
		_icon_page[icon] = page
		_icon_slot[icon] = slot
		_slot_owner[_get_slot_key(page, slot)] = icon
		_max_app_page = max(_max_app_page, page)

	for i in range(_dock_icons.size()):
		_icon_slot[_dock_icons[i]] = i
		_dock_slot_owner[i] = _dock_icons[i]

func _reassign_app_slots_from_current_positions() -> void:
	_icon_page.clear()
	_icon_slot.clear()
	_slot_owner.clear()
	_dock_slot_owner.clear()
	_max_app_page = 0

	for icon in _app_icons:
		var page: int = _infer_page_from_position(icon.position)
		var slot: int = _get_nearest_slot_from_page_position(icon.position - Vector2(page * _page_width, 0.0))
		if not _is_app_slot_available(page, slot) or _slot_owner.has(_get_slot_key(page, slot)):
			slot = _find_nearest_free_slot(page, slot)
		_icon_page[icon] = page
		_icon_slot[icon] = slot
		_slot_owner[_get_slot_key(page, slot)] = icon
		_max_app_page = max(_max_app_page, page)

	for i in range(_dock_icons.size()):
		_icon_slot[_dock_icons[i]] = i
		_icon_page[_dock_icons[i]] = -99
		_dock_slot_owner[i] = _dock_icons[i]

func _setup_page_clip() -> void:
	_page_clip = Control.new()
	_page_clip.name = "应用页裁剪层"
	_page_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_clip.position = 页面可视区域.position
	_page_clip.size = 页面可视区域.size
	_page_clip.clip_children = 2
	_page_clip.set("clip_contents", true)
	add_child(_page_clip)
	_reparent_control_keep_global(_apps_root, _page_clip)
	_apps_root_base_position = _apps_root.position

func _setup_sliding_widgets() -> void:
	_sliding_widgets.clear()
	for widget_path in 页面滑动控件路径:
		var widget: Control = get_node_or_null(widget_path) as Control
		if widget == null:
			continue
		_sliding_widgets.append(widget)
		_reparent_control_keep_global(widget, _apps_root)

func _setup_dock_overlay() -> void:
	_dock_root = Control.new()
	_dock_root.name = "Dock覆盖层"
	_dock_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dock_root)

	for icon in _dock_icons:
		_reparent_control_keep_global(icon, _dock_root)

	_refresh_dock_slot_positions_from_icons()

func _setup_drag_overlay() -> void:
	_drag_root = Control.new()
	_drag_root.name = "拖拽覆盖层"
	_drag_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_root)

func _setup_page_indicator() -> void:
	_page_indicator_root = Control.new()
	_page_indicator_root.name = "页面指示器"
	_page_indicator_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page_indicator_root)
	_update_page_indicator()

func _reparent_control_keep_global(control: Control, new_parent: Node) -> void:
	var old_global_position: Vector2 = control.global_position
	var old_parent: Node = control.get_parent()
	if old_parent != null:
		old_parent.remove_child(control)
	new_parent.add_child(control)
	control.global_position = old_global_position

func _refresh_dock_slot_positions_from_icons() -> void:
	_dock_slot_positions.clear()
	_dock_slot_centers.clear()
	_dock_icons.sort_custom(Callable(self, "_sort_icons_by_position"))
	var dock_space: Control = _dock_root if _dock_root != null else self
	for icon in _dock_icons:
		if _dock_slot_positions.size() >= Dock槽位数量:
			break
		_dock_slot_positions.append(icon.position)
		_dock_slot_centers.append(_global_to_control_local(dock_space, _get_icon_center(icon)))

func _refresh_dock_slot_positions_from_existing_slots() -> void:
	# Dock 的视觉中心来自场景初始排布；交换只改变槽位归属，不改变槽位间距和布局。
	pass

func _layout_all_icons(immediate: bool = false) -> void:
	_rebuild_targets_from_slots()
	_apply_icon_targets(immediate)

func _rebuild_targets_from_slots() -> void:
	_icon_target_position.clear()
	_slot_owner.clear()
	_dock_slot_owner.clear()
	_max_app_page = 0

	for icon in _app_icons:
		var page: int = int(_icon_page.get(icon, 0))
		var slot: int = clampi(int(_icon_slot.get(icon, 0)), 0, _get_slots_per_page() - 1)
		var key: String = _get_slot_key(page, slot)
		if not _is_app_slot_available(page, slot) or _slot_owner.has(key):
			slot = _find_nearest_free_slot(page, slot)
			key = _get_slot_key(page, slot)
		_icon_page[icon] = page
		_icon_slot[icon] = slot
		_slot_owner[key] = icon
		_icon_target_position[icon] = _get_app_slot_position_for_icon(icon, page, slot)
		_max_app_page = max(_max_app_page, page)

	for i in range(_dock_icons.size()):
		var icon: Control = _dock_icons[i]
		_icon_slot[icon] = i
		_icon_page[icon] = -99
		_dock_slot_owner[i] = icon
		_icon_target_position[icon] = _get_dock_slot_position_for_icon(icon, i)
	_update_icon_visibility()

func _apply_icon_targets(immediate: bool) -> void:
	for icon in _icon_target_position.keys():
		if not is_instance_valid(icon):
			continue
		if immediate:
			icon.position = _icon_target_position[icon]

func _update_icon_snap(delta: float) -> void:
	for icon in _icon_target_position.keys():
		if icon == _dragged_icon or not is_instance_valid(icon):
			continue
		var target: Vector2 = _icon_target_position[icon]
		icon.position = icon.position.lerp(target, min(图标吸附速度 * delta, 1.0))

func _get_app_slot_position(page: int, slot: int) -> Vector2:
	var col: int = slot % 每页列数
	var row: int = int(slot / 每页列数)
	return Vector2(
		图标起点.x + page * _page_width + col * 图标水平间距,
		图标起点.y + row * 图标垂直间距
	)

func _get_app_slot_position_for_icon(icon: Control, page: int, slot: int) -> Vector2:
	var slot_center: Vector2 = _get_app_slot_visual_center(page, slot)
	return slot_center - _get_icon_visual_center_offset(icon)

func _get_app_slot_visual_center(page: int, slot: int) -> Vector2:
	return _get_app_slot_position(page, slot) + _app_slot_visual_offset

func _get_dock_slot_position(slot: int) -> Vector2:
	var base_position: Vector2 = Vector2(
		Dock起点.x + slot * Dock水平间距,
		Dock起点.y
	)
	if slot >= 0 and slot < _dock_slot_positions.size():
		base_position = _dock_slot_positions[slot]

	return base_position

func _get_dock_slot_position_for_icon(icon: Control, slot: int) -> Vector2:
	return _get_dock_slot_center(slot) - _get_icon_visual_center_offset(icon)

func _get_dock_slot_center(slot: int) -> Vector2:
	if slot >= 0 and slot < _dock_slot_centers.size():
		return _dock_slot_centers[slot]
	return _get_dock_slot_position(slot) + Vector2(32.0, 32.0)

func _get_slots_per_page() -> int:
	return max(每页列数 * 每页行数, 1)

## ===== 私有方法：滑动 =====

func _on_pointer_pressed(local_position: Vector2) -> void:
	_is_pointer_down = true
	_is_swiping = false
	_press_time = 0.0
	_press_position = local_position

func _on_pointer_released(local_position: Vector2) -> void:
	if _dragged_icon != null:
		_finish_drag()
	else:
		_finish_swipe(local_position)

	_is_pointer_down = false
	_is_swiping = false
	_press_time = 0.0
	_drag_edge_timer = 0.0
	_drag_edge_hold_timer = 0.0
	_drag_edge_hold_direction = 0

func _update_swipe(local_position: Vector2) -> void:
	var delta: Vector2 = local_position - _press_position
	if absf(delta.x) <= absf(delta.y) * 横向滑动判定倍率:
		return
	if absf(delta.x) < 8.0:
		return
	_is_swiping = true
	_apps_root.position.x = _apps_root_base_position.x + _target_root_x + delta.x

func _finish_swipe(local_position: Vector2) -> void:
	if not _is_swiping:
		_update_page_target()
		return

	var delta: Vector2 = local_position - _press_position
	if absf(delta.x) >= 切页滑动距离:
		if delta.x > 0:
			_go_to_page(_current_page - 1)
		else:
			_go_to_page(_current_page + 1)
	else:
		_update_page_target()

func _go_to_page(page: int, allow_empty_preview: bool = false) -> void:
	var min_page: int = -1 if 允许左侧消息页 else 0
	var max_page: int = _max_app_page
	if allow_empty_preview and _dragged_icon != null and 允许自动创建应用页:
		max_page += 1
	_current_page = clampi(page, min_page, max_page)
	_update_page_target()

func _update_page_target(immediate: bool = false) -> void:
	_target_root_x = -float(_current_page) * _page_width
	if immediate:
		_apps_root.position.x = _apps_root_base_position.x + _target_root_x
	_rebuild_targets_from_slots()
	_update_dock_visibility()
	_update_icon_visibility()
	_update_page_indicator()

func _update_dock_visibility() -> void:
	var show_dock: bool = _current_page >= 0
	if _dock_background != null:
		_dock_background.visible = show_dock
	for icon in _dock_icons:
		icon.visible = show_dock

func _update_icon_visibility() -> void:
	for icon in _app_icons:
		if not is_instance_valid(icon):
			continue
		icon.visible = true

	var show_dock: bool = _current_page >= 0
	for icon in _dock_icons:
		if is_instance_valid(icon):
			icon.visible = show_dock
	_update_app_clip_visibility()

func _update_app_clip_visibility() -> void:
	if _page_clip == null:
		return
	var clip_rect: Rect2 = _get_control_global_rect(_page_clip).grow(_clip_margin)
	for icon in _app_icons:
		if not is_instance_valid(icon) or icon == _dragged_icon:
			continue
		icon.visible = clip_rect.intersects(_get_icon_global_rect(icon), true)
	for widget in _fixed_widgets:
		if not is_instance_valid(widget):
			continue
		widget.visible = clip_rect.intersects(_get_control_global_rect(widget), true)

func _update_page_indicator() -> void:
	if _page_indicator_root == null:
		return

	for child in _page_indicator_root.get_children():
		child.queue_free()

	var page_count: int = max(max(_max_app_page + 1, _current_page + 1), 1)
	var total_width: float = float(page_count - 1) * 页面指示点间距 + 页面指示点直径
	_page_indicator_root.position = 页面指示位置 - Vector2(total_width * 0.5, 页面指示点直径 * 0.5)
	_page_indicator_root.visible = _current_page >= 0

	for page in range(page_count):
		var dot: Panel = Panel.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(float(page) * 页面指示点间距, 0.0)
		dot.size = Vector2(页面指示点直径, 页面指示点直径)

		var style_box: StyleBoxFlat = StyleBoxFlat.new()
		style_box.bg_color = 当前页面指示颜色 if page == _current_page else 其他页面指示颜色
		var radius: int = roundi(页面指示点直径 * 0.5)
		style_box.corner_radius_top_left = radius
		style_box.corner_radius_top_right = radius
		style_box.corner_radius_bottom_left = radius
		style_box.corner_radius_bottom_right = radius
		dot.add_theme_stylebox_override("panel", style_box)

		_page_indicator_root.add_child(dot)

## ===== 私有方法：拖拽 =====

func _try_begin_drag(global_position: Vector2) -> void:
	var icon: Control = _find_icon_at_global_position(global_position)
	if icon == null:
		return

	_dragged_icon = icon
	_drag_offset = global_position - icon.global_position
	_drag_origin_page = int(_icon_page.get(icon, 0))
	_drag_origin_slot = int(_icon_slot.get(icon, 0))
	_drag_started_from_dock = _dock_icons.has(icon)
	_last_drag_desired_global_position = icon.global_position
	_has_last_drag_desired_position = true
	_dragged_icon.z_index = 100
	if _drag_root != null:
		_reparent_control_keep_global(_dragged_icon, _drag_root)
	_is_swiping = false

func _try_open_app_at_position(local_position: Vector2) -> bool:
	var icon: Control = _find_icon_at_global_position(local_position)
	if icon == null:
		return false
	var scene_path: String = AppShellController.get_scene_path_for_app(icon.name)
	if scene_path.is_empty():
		scene_path = str(APP_SCENE_PATHS.get(icon.name, ""))
	if scene_path.is_empty():
		return false
	_is_pointer_down = false
	_is_swiping = false
	_press_time = 0.0
	_drag_edge_timer = 0.0
	_drag_edge_hold_timer = 0.0
	_drag_edge_hold_direction = 0
	get_tree().change_scene_to_file(scene_path)
	return true

func _update_drag(global_position: Vector2, delta: float) -> void:
	if _dragged_icon == null:
		return

	var desired_position: Vector2 = global_position - _drag_offset
	_last_drag_desired_global_position = desired_position
	_has_last_drag_desired_position = true
	_dragged_icon.global_position = _get_clamped_icon_global_position(_dragged_icon, desired_position)
	_drag_edge_timer = max(_drag_edge_timer - delta, 0.0)
	_handle_drag_edge_switch(_get_icon_center(_dragged_icon), delta)

func _handle_drag_edge_switch(global_position: Vector2, delta: float) -> void:
	if _drag_edge_timer > 0.0:
		return

	var edge_rect: Rect2 = _get_control_global_rect(_page_clip) if _page_clip != null else _get_drag_limit_global_rect()
	var edge_direction: int = 0
	if global_position.x > edge_rect.end.x - 拖拽切页边缘距离:
		edge_direction = 1
	elif global_position.x < edge_rect.position.x + 拖拽切页边缘距离:
		edge_direction = -1

	if edge_direction == 0:
		_drag_edge_hold_timer = 0.0
		_drag_edge_hold_direction = 0
		return

	if edge_direction != _drag_edge_hold_direction:
		_drag_edge_hold_direction = edge_direction
		_drag_edge_hold_timer = 0.0

	_drag_edge_hold_timer += delta
	if _drag_edge_hold_timer < 拖拽切页停留时间:
		return

	_go_to_page(_current_page + edge_direction, true)
	_drag_edge_timer = 拖拽切页冷却
	_drag_edge_hold_timer = 0.0

func _finish_drag() -> void:
	if _dragged_icon == null:
		return

	if _is_drag_over_dock(_dragged_icon):
		_drop_icon_to_dock(_dragged_icon)
	else:
		_drop_icon_to_nearest_app_slot(_dragged_icon)

	_dragged_icon.z_index = 0
	_dragged_icon = null
	_has_last_drag_desired_position = false
	_layout_all_icons(false)
	if _current_page > _max_app_page:
		_go_to_page(_max_app_page)
	else:
		_update_page_target()

func _find_icon_at_global_position(global_position: Vector2) -> Control:
	var candidates: Array[Control] = []
	candidates.append_array(_app_icons)
	candidates.append_array(_dock_icons)

	for i in range(candidates.size() - 1, -1, -1):
		var icon: Control = candidates[i]
		if not icon.visible:
			continue
		if _app_icons.has(icon) and _page_clip != null:
			if not _get_control_global_rect(_page_clip).has_point(global_position):
				continue
		if _get_icon_global_rect(icon).has_point(global_position):
			return icon
	return null

func _drop_icon_to_nearest_app_slot(icon: Control) -> void:
	_release_icon_from_current_slot(icon)

	if _dock_icons.has(icon):
		_dock_icons.erase(icon)
		_app_icons.append(icon)

	if icon.get_parent() != _apps_root:
		_reparent_control_keep_global(icon, _apps_root)

	var target: Dictionary = _get_nearest_app_slot_for_icon(icon)
	var target_page: int = int(target.get("page", max(_current_page, 0)))
	var target_slot: int = int(target.get("slot", 0))
	var target_key: String = _get_slot_key(target_page, target_slot)
	if not _is_app_slot_available(target_page, target_slot):
		target_slot = _find_nearest_free_slot(target_page, target_slot)
		target_key = _get_slot_key(target_page, target_slot)
	var occupied_icon: Control = _slot_owner.get(target_key, null) as Control

	if occupied_icon != null and occupied_icon != icon:
		_slot_owner.erase(target_key)
		if _drag_started_from_dock:
			_slot_owner[target_key] = icon
			_icon_page[occupied_icon] = target_page
			_icon_slot[occupied_icon] = _find_nearest_free_slot(target_page, target_slot)
			_slot_owner.erase(target_key)
		else:
			_icon_page[occupied_icon] = _drag_origin_page
			_icon_slot[occupied_icon] = _drag_origin_slot

	_icon_page[icon] = target_page
	_icon_slot[icon] = target_slot

func _drop_icon_to_dock(icon: Control) -> void:
	if _dock_root == null:
		_drop_icon_to_nearest_app_slot(icon)
		return

	_release_icon_from_current_slot(icon)

	var target_slot: int = _get_nearest_dock_slot_for_icon(icon)
	if _dock_icons.has(icon):
		var origin_slot: int = _dock_icons.find(icon)
		if origin_slot >= 0 and target_slot >= 0 and target_slot < _dock_icons.size():
			var swapped_icon: Control = _dock_icons[target_slot]
			_dock_icons[target_slot] = icon
			_dock_icons[origin_slot] = swapped_icon
			if icon.get_parent() != _dock_root:
				_reparent_control_keep_global(icon, _dock_root)
			_refresh_dock_slot_positions_from_existing_slots()
		return

	if target_slot < _dock_icons.size():
		var replaced_app_icon: Control = _dock_icons[target_slot]
		if replaced_app_icon == null or not is_instance_valid(replaced_app_icon):
			_drop_icon_to_nearest_app_slot(icon)
			return
		_app_icons.erase(icon)
		_dock_icons[target_slot] = icon
		if icon.get_parent() != _dock_root:
			_reparent_control_keep_global(icon, _dock_root)
		_app_icons.append(replaced_app_icon)
		if replaced_app_icon.get_parent() != _apps_root:
			_reparent_control_keep_global(replaced_app_icon, _apps_root)
		_icon_page[replaced_app_icon] = _drag_origin_page
		_icon_slot[replaced_app_icon] = _find_nearest_free_slot(_drag_origin_page, _drag_origin_slot)
		_refresh_dock_slot_positions_from_existing_slots()
	else:
		_app_icons.erase(icon)
		_dock_icons.append(icon)
		if icon.get_parent() != _dock_root:
			_reparent_control_keep_global(icon, _dock_root)
		_refresh_dock_slot_positions_from_existing_slots()

func _release_icon_from_current_slot(icon: Control) -> void:
	if _dock_icons.has(icon):
		var dock_slot: int = _dock_icons.find(icon)
		if dock_slot >= 0:
			_dock_slot_owner.erase(dock_slot)
		return

	var page: int = int(_icon_page.get(icon, _drag_origin_page))
	var slot: int = int(_icon_slot.get(icon, _drag_origin_slot))
	var key: String = _get_slot_key(page, slot)
	if _slot_owner.get(key, null) == icon:
		_slot_owner.erase(key)

func _is_drag_over_dock(icon: Control) -> bool:
	if _dock_background == null or _current_page < 0:
		return false
	var dock_rect: Rect2 = _get_control_global_rect(_dock_background as Control)
	var dock_capture_rect: Rect2 = Rect2(
		dock_rect.position - Vector2(0.0, max(Dock吸附上方距离, 0.0)),
		dock_rect.size + Vector2(0.0, max(Dock吸附上方距离, 0.0))
	)
	return dock_capture_rect.has_point(_get_icon_center(icon))

func _get_control_global_rect(control: Control) -> Rect2:
	return Rect2(control.global_position, control.size)

func _control_local_to_global(control: Control, local_position: Vector2) -> Vector2:
	if control == null:
		return local_position
	return control.global_position + local_position

func _global_to_control_local(control: Control, global_position: Vector2) -> Vector2:
	if control == null:
		return global_position
	return global_position - control.global_position

func _get_icon_global_rect(icon: Control) -> Rect2:
	var button: Control = icon.get_node_or_null("Button") as Control
	if button != null:
		return _get_control_global_rect(button)
	return _get_control_global_rect(icon)

func _get_icon_center(icon: Control) -> Vector2:
	var rect: Rect2 = _get_icon_global_rect(icon)
	return rect.position + rect.size * 0.5

func _get_clamped_icon_global_position(icon: Control, desired_global_position: Vector2) -> Vector2:
	var limit_rect: Rect2 = _get_drag_limit_global_rect()
	if limit_rect.size.x <= 0.0 or limit_rect.size.y <= 0.0:
		return desired_global_position

	var current_rect: Rect2 = _get_icon_global_rect(icon)
	var delta: Vector2 = desired_global_position - icon.global_position
	var moved_rect: Rect2 = Rect2(current_rect.position + delta, current_rect.size)

	if moved_rect.position.x < limit_rect.position.x:
		delta.x += limit_rect.position.x - moved_rect.position.x
	elif moved_rect.end.x > limit_rect.end.x:
		delta.x -= moved_rect.end.x - limit_rect.end.x

	if moved_rect.position.y < limit_rect.position.y:
		delta.y += limit_rect.position.y - moved_rect.position.y
	elif moved_rect.end.y > limit_rect.end.y:
		delta.y -= moved_rect.end.y - limit_rect.end.y

	return icon.global_position + delta

func _get_drag_limit_global_rect() -> Rect2:
	var top_left: Vector2 = _control_local_to_global(self, 手机屏幕拖拽区域.position)
	var bottom_right: Vector2 = _control_local_to_global(self, 手机屏幕拖拽区域.position + 手机屏幕拖拽区域.size)
	return Rect2(top_left, bottom_right - top_left)

func _is_point_inside_phone_screen(global_position: Vector2) -> bool:
	var top_left: Vector2 = _control_local_to_global(self, 页面可视区域.position)
	var bottom_right: Vector2 = _control_local_to_global(self, 页面可视区域.position + 页面可视区域.size)
	return Rect2(top_left, bottom_right - top_left).has_point(global_position)

func _return_to_mobile_phone() -> void:
	var tree := get_tree()
	if tree != null and tree.current_scene == self:
		tree.change_scene_to_file("res://界面/场景/手机/mobile_phone.tscn")
		return
	queue_free()

func _infer_layout_from_scene() -> void:
	if _app_icons.size() > 0:
		_app_slot_visual_offset = _get_icon_visual_center_offset(_app_icons[0])
	if not 自动推导图标网格:
		return
	var app_positions: Array[Vector2] = []
	for icon in _app_icons:
		app_positions.append(icon.position)
	if app_positions.size() >= 2:
		var first_small_icon_position: Vector2 = _get_min_position(app_positions)
		图标水平间距 = _infer_axis_spacing(app_positions, true, 图标水平间距)
		图标垂直间距 = _infer_axis_spacing(app_positions, false, 图标垂直间距)
		图标起点 = Vector2(
			first_small_icon_position.x,
			first_small_icon_position.y - float(首页顶部大组件占用行数) * 图标垂直间距
		)
	var dock_positions: Array[Vector2] = []
	for icon in _dock_icons:
		dock_positions.append(icon.position)
	if dock_positions.size() >= 2:
		dock_positions.sort_custom(Callable(self, "_sort_vectors_by_position"))
		_dock_slot_positions.clear()
		for i in range(min(dock_positions.size(), Dock槽位数量)):
			_dock_slot_positions.append(dock_positions[i])
		Dock起点 = _get_min_position(dock_positions)
		Dock水平间距 = _infer_axis_spacing(dock_positions, true, Dock水平间距)
	_reassign_app_slots_from_current_positions()

func _sort_icons_by_position(a: Control, b: Control) -> bool:
	if not is_equal_approx(a.position.y, b.position.y):
		return a.position.y < b.position.y
	return a.position.x < b.position.x

func _sort_vectors_by_position(a: Vector2, b: Vector2) -> bool:
	if not is_equal_approx(a.y, b.y):
		return a.y < b.y
	return a.x < b.x

func _infer_page_from_position(position: Vector2) -> int:
	return max(floori((position.x - 图标起点.x) / _page_width), 0)

func _get_nearest_app_slot_for_icon(icon: Control) -> Dictionary:
	var local_position: Vector2 = _get_icon_slot_reference_position(icon)
	var page: int = max(floori((local_position.x - 图标起点.x) / _page_width), 0)
	if page > _max_app_page and 允许自动创建应用页:
		_max_app_page = page
	var page_position: Vector2 = local_position - Vector2(page * _page_width, 0.0)
	return {
		"page": page,
		"slot": _get_nearest_slot_from_page_position(page_position)
	}

func _get_icon_slot_reference_position(icon: Control) -> Vector2:
	if icon == _dragged_icon and _has_last_drag_desired_position:
		return _global_to_control_local(_apps_root, _last_drag_desired_global_position)
	var visual_rect: Rect2 = _get_icon_global_rect(icon)
	var visual_center_in_apps: Vector2 = _global_to_control_local(_apps_root, visual_rect.position + visual_rect.size * 0.5)
	return visual_center_in_apps - _get_icon_visual_center_offset(icon)

func _get_icon_visual_center_offset(icon: Control) -> Vector2:
	var button: Control = icon.get_node_or_null("Button") as Control
	if button != null:
		return button.position + button.size * 0.5
	return icon.size * 0.5

func _get_nearest_slot_from_page_position(page_position: Vector2) -> int:
	var col: int = clampi(roundi((page_position.x - 图标起点.x) / 图标水平间距), 0, 每页列数 - 1)
	var row: int = clampi(roundi((page_position.y - 图标起点.y) / 图标垂直间距), 0, 每页行数 - 1)
	return row * 每页列数 + col

func _get_nearest_dock_slot_for_icon(icon: Control) -> int:
	var dock_space: Control = _dock_root if _dock_root != null else self
	var local_center: Vector2 = _global_to_control_local(dock_space, _get_icon_center(icon))
	var best_slot: int = 0
	var best_distance: float = 1.0e30
	for slot in range(Dock槽位数量):
		var slot_center: Vector2 = _get_dock_slot_center(slot)
		var distance: float = local_center.distance_squared_to(slot_center)
		if distance < best_distance:
			best_distance = distance
			best_slot = slot
	return best_slot

func _find_nearest_free_slot(page: int, preferred_slot: int) -> int:
	for distance in range(_get_slots_per_page()):
		var forward: int = (preferred_slot + distance) % _get_slots_per_page()
		if _is_app_slot_available(page, forward) and not _slot_owner.has(_get_slot_key(page, forward)):
			return forward
		var backward: int = (preferred_slot - distance + _get_slots_per_page()) % _get_slots_per_page()
		if _is_app_slot_available(page, backward) and not _slot_owner.has(_get_slot_key(page, backward)):
			return backward
	return preferred_slot

func _is_app_slot_available(page: int, slot: int) -> bool:
	if page != 0:
		return true
	return slot >= 每页列数 * 首页顶部大组件占用行数

func _get_slot_key(page: int, slot: int) -> String:
	return str(page) + ":" + str(slot)

func _get_min_position(positions: Array[Vector2]) -> Vector2:
	var result: Vector2 = positions[0]
	for position in positions:
		result.x = min(result.x, position.x)
		result.y = min(result.y, position.y)
	return result

func _infer_axis_spacing(positions: Array[Vector2], use_x: bool, fallback: float) -> float:
	var values: Array[float] = []
	for position in positions:
		var value: float = position.x if use_x else position.y
		if not _has_close_value(values, value):
			values.append(value)
	values.sort()
	var best_spacing: float = fallback
	for i in range(1, values.size()):
		var diff: float = values[i] - values[i - 1]
		if diff > 8.0:
			best_spacing = diff
			break
	return best_spacing

func _has_close_value(values: Array[float], value: float) -> bool:
	for item in values:
		if absf(item - value) < 4.0:
			return true
	return false
