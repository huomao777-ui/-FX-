extends Control

## 默认读取的 NPC 配置文件路径。
@export_file("*.json") var npc_json_path: String = "res://界面/场景/联系人/NPC.json"
## 当前信息卡显示的 NPC 编号。
@export var npc_id: String = "npc_001"

var portrait_placeholder: TextureRect = null
var portrait_hint: Label = null
var basic_info_title: Label = null
var name_label: Label = null
var gender_label: Label = null
var job_label: Label = null
var location_label: Label = null
var gift_title: Label = null
var skill_title: Label = null
var current_stage_title: Label = null
var name_value: Label = null
var gender_value: Label = null
var job_value: Label = null
var location_value: Label = null
var intro_text: RichTextLabel = null
var gift_like: Label = null
var gift_dislike: Label = null
var skill_rank_labels: Array[Label] = []
var skill_name_labels: Array[Label] = []
var skill_desc_labels: Array[RichTextLabel] = []
var coop_textures: Array[TextureRect] = []


func _ready() -> void:
	cache_nodes()
	apply_static_chinese_labels()
	refresh_from_config()


func refresh_from_config() -> void:
	var config: Dictionary = load_npc_config()
	if config.is_empty():
		return

	var npc_data: Dictionary = find_npc_data(config, npc_id)
	if npc_data.is_empty():
		push_warning("未找到 NPC 数据: %s" % npc_id)
		return

	apply_npc_data(config, npc_data)


func cache_nodes() -> void:
	portrait_placeholder = find_label_parent_texture("PortraitPlaceholder")
	portrait_hint = find_node_by_name("PortraitHint") as Label
	basic_info_title = find_node_by_name("BasicInfoTitle") as Label
	name_label = find_node_by_name("NameLabel") as Label
	gender_label = find_node_by_name("GenderLabel") as Label
	job_label = find_node_by_name("JobLabel") as Label
	location_label = find_node_by_name("LocationLabel") as Label
	gift_title = find_node_by_name("GiftTitle") as Label
	skill_title = find_node_by_name("SkillTitle") as Label
	current_stage_title = find_node_by_name("CurrentStageTitle") as Label
	name_value = find_node_by_name("NameValue") as Label
	gender_value = find_node_by_name("GenderValue") as Label
	job_value = find_node_by_name("JobValue") as Label
	location_value = find_node_by_name("LocationValue") as Label
	intro_text = find_node_by_name("IntroText") as RichTextLabel
	gift_like = find_node_by_name("GiftLike") as Label
	gift_dislike = find_node_by_name("GiftDislike") as Label
	skill_rank_labels = [
		find_node_by_name("SkillARank") as Label,
		find_node_by_name("SkillBRank") as Label,
		find_node_by_name("SkillCRank") as Label
	]
	skill_name_labels = [
		find_node_by_name("SkillAName") as Label,
		find_node_by_name("SkillBName") as Label,
		find_node_by_name("SkillCName") as Label
	]
	skill_desc_labels = [
		find_node_by_name("SkillADesc") as RichTextLabel,
		find_node_by_name("SkillBDesc") as RichTextLabel,
		find_node_by_name("SkillCDesc") as RichTextLabel
	]

	coop_textures.clear()
	for level: int in range(10):
		var texture_node: TextureRect = find_node_by_name("Coop%d" % level) as TextureRect
		if texture_node != null:
			coop_textures.append(texture_node)


func apply_static_chinese_labels() -> void:
	set_label_text(basic_info_title, "基础信息")
	set_label_text(name_label, "姓名")
	set_label_text(gender_label, "性别")
	set_label_text(job_label, "职业")
	set_label_text(location_label, "地区")
	set_label_text(gift_title, "礼物偏好")
	set_label_text(skill_title, "协助技能")
	set_label_text(current_stage_title, "当前阶段")
	if portrait_hint != null and portrait_hint.text == "Portrait Area":
		portrait_hint.text = "立绘区域"


func load_npc_config() -> Dictionary:
	if not FileAccess.file_exists(npc_json_path):
		push_warning("NPC 配置文件不存在: %s" % npc_json_path)
		return {}

	var json_text: String = FileAccess.get_file_as_string(npc_json_path)
	if json_text.is_empty():
		push_warning("NPC 配置文件为空: %s" % npc_json_path)
		return {}

	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		push_warning("NPC 配置文件解析失败: %s" % npc_json_path)
		return {}

	return parsed as Dictionary


func find_npc_data(config: Dictionary, target_id: String) -> Dictionary:
	var npc_list: Variant = config.get("npcs", [])
	if not (npc_list is Array):
		return {}

	for item: Variant in npc_list:
		if item is Dictionary and str(item.get("npc_id", "")) == target_id:
			return item as Dictionary
	return {}


func apply_npc_data(config: Dictionary, npc_data: Dictionary) -> void:
	var defaults: Dictionary = config.get("defaults", {}) as Dictionary
	var profile: Dictionary = npc_data.get("profile", {}) as Dictionary
	var preferences: Dictionary = npc_data.get("preferences", {}) as Dictionary
	var coop: Dictionary = npc_data.get("coop", {}) as Dictionary
	var assets: Dictionary = npc_data.get("assets", {}) as Dictionary

	set_label_text(name_value, str(npc_data.get("display_name", "未命名角色")))
	set_label_text(gender_value, str(profile.get("gender", "-")))
	set_label_text(job_value, str(profile.get("job_title", "-")))
	set_label_text(location_value, str(profile.get("location_name", "-")))
	set_rich_text(intro_text, str(profile.get("intro_text", "")))

	var liked_tags: Array = to_string_array(preferences.get("liked_gift_tags", []))
	var disliked_tags: Array = to_string_array(preferences.get("disliked_gift_tags", []))
	set_label_text(gift_like, "喜欢：%s" % join_or_placeholder(liked_tags))
	set_label_text(gift_dislike, "讨厌：%s" % join_or_placeholder(disliked_tags))

	apply_skills(coop.get("skill_unlocks", []))
	apply_portrait_hint(npc_data, assets)


func apply_skills(skill_unlocks_variant: Variant) -> void:
	var skill_unlocks: Array = skill_unlocks_variant if skill_unlocks_variant is Array else []
	for index: int in range(3):
		var skill_data: Dictionary = {}
		if index < skill_unlocks.size() and skill_unlocks[index] is Dictionary:
			skill_data = skill_unlocks[index] as Dictionary

		set_label_text(skill_rank_labels[index], "亲密 %s" % str(skill_data.get("unlock_level", "-")))
		set_label_text(skill_name_labels[index], str(skill_data.get("skill_name", "未设置技能")))
		set_rich_text(skill_desc_labels[index], str(skill_data.get("skill_desc", "技能描述待补充。")))


func apply_portrait_hint(npc_data: Dictionary, assets: Dictionary) -> void:
	if portrait_placeholder != null:
		portrait_placeholder.modulate = Color(1, 1, 1, 0.18)

	if portrait_hint == null:
		return

	var portrait_id: String = str(assets.get("portrait_unlocked_id", assets.get("portrait_id", "")))
	var display_name: String = str(npc_data.get("display_name", "NPC"))
	if portrait_id.is_empty():
		portrait_hint.text = display_name
	else:
		portrait_hint.text = "%s\n%s" % [display_name, portrait_id]


func find_node_by_name(target_name: String) -> Node:
	return find_named_descendant(self, target_name)


func find_named_descendant(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	for child: Node in root.get_children():
		if str(child.name) == target_name:
			return child
		var nested: Node = find_named_descendant(child, target_name)
		if nested != null:
			return nested
	return null


func find_label_parent_texture(target_name: String) -> TextureRect:
	var node: Node = find_node_by_name(target_name)
	if node is TextureRect:
		return node as TextureRect
	return null


func set_label_text(label: Label, value: String) -> void:
	if label != null:
		label.text = value


func set_rich_text(label: RichTextLabel, value: String) -> void:
	if label != null:
		label.text = value


func to_string_array(raw_value: Variant) -> Array:
	var result: Array = []
	if raw_value is Array:
		for item: Variant in raw_value:
			result.append(str(item))
	return result


func join_or_placeholder(values: Array) -> String:
	if values.is_empty():
		return "-"
	return " / ".join(values)
