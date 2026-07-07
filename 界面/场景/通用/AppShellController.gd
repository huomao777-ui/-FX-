extends Control
class_name AppShellController

## 通用 APP 外壳：
## 1. 负责进入/离开时的手机状态切换
## 2. 负责外部双击回退到 FullMobile
## 3. 可把当前场景自动注册到 FullMobile 指定软件图标

const FULL_MOBILE_SCENE_PATH: String = "res://界面/场景/手机/full_mobile.tscn"
static var _app_scene_registry: Dictionary = {}
static var _discovered_app_scene_registry: Dictionary = {}

@export var 进入时启用汇率专注时间: bool = true
@export var 进入时启用盯盘耗电: bool = true
@export var 离开时恢复普通状态: bool = true

## 对应 FullMobile 场景里“软件”节点下的软件名，例如“联系人”。
@export var FullMobile软件节点名: String = ""
## 留空时自动使用当前场景文件路径。
@export_file("*.tscn") var 当前APP场景路径: String = ""

var _app_root: Node = null


func _ready() -> void:
	if _has_game_data_manager():
		if 进入时启用汇率专注时间 and GameDataManager.时间 != null:
			GameDataManager.时间.进入汇率专注时间流动()
		if 进入时启用盯盘耗电 and GameDataManager.手机 != null:
			GameDataManager.手机.进入汇率盯盘使用状态()

	_app_root = _find_descendant_by_name(self, "APP")
	_register_current_scene_to_full_mobile()


func _exit_tree() -> void:
	if not 离开时恢复普通状态 or not _has_game_data_manager():
		return

	if GameDataManager.时间 != null:
		GameDataManager.时间.进入普通时间流动()
	if GameDataManager.手机 != null:
		GameDataManager.手机.进入普通手机使用状态()


func 执行外部双击回退() -> String:
	if _app_root != null and _app_root.has_method("执行APP内部回退"):
		if bool(_app_root.call("执行APP内部回退")):
			return "popup"

	if _return_to_full_mobile():
		return "scene"
	return ""


func _return_to_full_mobile() -> bool:
	if ResourceLoader.exists(FULL_MOBILE_SCENE_PATH):
		get_tree().change_scene_to_file(FULL_MOBILE_SCENE_PATH)
		return true
	return false


func _register_current_scene_to_full_mobile() -> void:
	if FullMobile软件节点名.is_empty():
		return

	var scene_path: String = _resolve_current_scene_path()
	if scene_path.is_empty():
		push_warning("AppShellController: 无法解析当前 APP 场景路径，未注册到 FullMobile。")
		return

	register_app_scene_path(FullMobile软件节点名, scene_path)


func _resolve_current_scene_path() -> String:
	if not 当前APP场景路径.is_empty():
		return 当前APP场景路径
	if not scene_file_path.is_empty():
		return scene_file_path

	var current_scene: Node = get_tree().current_scene
	if current_scene != null and not current_scene.scene_file_path.is_empty():
		return current_scene.scene_file_path
	return ""


func _has_game_data_manager() -> bool:
	return get_node_or_null("/root/GameDataManager") != null


func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if root.name == target_name:
		return root

	for child: Node in root.get_children():
		var found: Node = _find_descendant_by_name(child, target_name)
		if found != null:
			return found
	return null


static func register_app_scene_path(app_name: String, scene_path: String) -> void:
	if app_name.is_empty() or scene_path.is_empty():
		return
	_app_scene_registry[app_name] = scene_path


static func get_registered_app_scene_path(app_name: String) -> String:
	return str(_app_scene_registry.get(app_name, ""))


static func get_scene_path_for_app(app_name: String) -> String:
	var runtime_path: String = get_registered_app_scene_path(app_name)
	if not runtime_path.is_empty():
		return runtime_path

	if _discovered_app_scene_registry.is_empty():
		_discover_app_scene_paths()
	return str(_discovered_app_scene_registry.get(app_name, ""))


static func _discover_app_scene_paths() -> void:
	_discovered_app_scene_registry.clear()

	var search_roots: Array[String] = [
		"res://界面/场景/联系人",
		"res://界面/场景/外汇应用"
	]
	for root_path: String in search_roots:
		_scan_scene_directory(root_path)


static func _scan_scene_directory(root_path: String) -> void:
	var directory: DirAccess = DirAccess.open(root_path)
	if directory == null:
		return

	directory.list_dir_begin()
	while true:
		var entry_name: String = directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue

		var full_path: String = root_path.path_join(entry_name)
		if directory.current_is_dir():
			_scan_scene_directory(full_path)
			continue

		if entry_name.get_extension() != "tscn":
			continue

		var app_name: String = entry_name.get_basename()
		if not _discovered_app_scene_registry.has(app_name):
			_discovered_app_scene_registry[app_name] = full_path
	directory.list_dir_end()
