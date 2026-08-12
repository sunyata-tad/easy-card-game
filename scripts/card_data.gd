## 卡牌数据模型：存储单张卡牌的所有静态属性（来自 JSON 配置）。
## Godot 特色：
## - _init(data, upgraded) 是构造函数，可以通过 CardData.new(dict, true) 创建升级版
## - Array 的 .has() 和 .erase() 是内置方法
class_name CardData

var id: String              ## 卡牌唯一 id，如 "斩击"
var name: String            ## 显示名称
var type: String            ## 类型："attack"（攻击）、"skill"（技能）、"power"（能力）
var description: String     ## 描述文本（可包含 {key} 占位符）
var rarity: String          ## 稀有度："basic"、"common"、"uncommon"、"rare"、"epic"
var target_type: String     ## 目标类型："self"、"single_enemy"、"single_ally"、"all_enemies" 等
var effects: Array          ## 效果列表，每个元素是 Dictionary
var is_upgraded: bool = false  ## 是否已升级
var tags: Array = []           ## 标签列表（用于卡牌效果检索，如 "蓄力流"）
var treated_as: Array = []     ## 视为标签（"视为某标签"但不真正拥有该标签）
var play_condition: Dictionary = {}  ## 出牌条件（如 {"type": "hp_below_percent", "value": 10}），不满足不可打出

## 构造函数：从 JSON 数据创建卡牌，upgraded=true 时读取 upgrade 字段
func _init(data: Dictionary, upgraded: bool = false):
	id = data.get("id", "")
	is_upgraded = upgraded

	# 升级版读取 upgrade 子对象的数据
	if upgraded and data.has("upgrade"):
		var upgrade_data = data.upgrade
		name = upgrade_data.get("name", data.name + "+")
		description = upgrade_data.get("description", data.description)
		effects = upgrade_data.get("effects", data.effects)
	else:
		name = data.get("name", "")
		description = data.get("description", "")
		effects = data.get("effects", [])

	type = data.get("type", "attack")
	rarity = data.get("rarity", "common")
	target_type = data.get("target_type", "single_enemy")
	tags = data.get("tags", [])
	treated_as = data.get("treated_as", [])
	play_condition = data.get("play_condition", {})

## 获取描述文本（替换 {scaling_key} 占位符为实际效果值）
func get_description_text() -> String:
	var text = description
	for effect in effects:
		var key = effect.get("scaling_key", "")
		if key != "":
			# 将 {key} 替换为效果值，如 "{damage}" → "5"
			var placeholder = "{" + key + "}"
			text = text.replace(placeholder, str(effect.value))
	return text

## 深拷贝卡牌数据
func duplicate() -> CardData:
	var data = {
		"id": id,
		"name": name,
		"type": type,
		"description": description,
		"rarity": rarity,
		"target_type": target_type,
		"effects": effects.duplicate(true),
		"tags": tags.duplicate(),
		"treated_as": treated_as.duplicate(),
		"play_condition": play_condition.duplicate(true)
	}
	return CardData.new(data, is_upgraded)

## 判断出牌条件是否满足（当前支持 hp_below_percent：生命低于最大值的 X%）
func can_play(player = null) -> bool:
	if play_condition.is_empty():
		return true
	match play_condition.get("type", ""):
		"hp_below_percent":
			if player:
				var pct = play_condition.get("value", 10)
				return player.current_hp < player.max_hp * pct / 100.0
	return true

## 检查是否拥有某标签（包括 treated_as 中的"视为"标签）
func has_tag(tag: String) -> bool:
	return tags.has(tag) or treated_as.has(tag)

## 检查是否拥有任意一个标签
func has_any_tag(check_tags: Array) -> bool:
	for tag in check_tags:
		if has_tag(tag):
			return true
	return false

## 检查是否拥有所有标签
func has_all_tags(check_tags: Array) -> bool:
	for tag in check_tags:
		if not has_tag(tag):
			return false
	return true

## 获取所有标签（tags + treated_as 去重合并）
func get_all_tags() -> Array:
	var all_tags = tags.duplicate()
	for tag in treated_as:
		if not all_tags.has(tag):
			all_tags.append(tag)
	return all_tags

func add_tag(tag: String) -> void:
	if not tags.has(tag):
		tags.append(tag)

func remove_tag(tag: String) -> void:
	tags.erase(tag)

## 添加"视为"标签
func add_treated_as(tag: String) -> void:
	if not treated_as.has(tag):
		treated_as.append(tag)

func remove_treated_as(tag: String) -> void:
	treated_as.erase(tag)
