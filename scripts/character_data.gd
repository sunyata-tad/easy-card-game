## 角色数据模型：存储一个角色的全部信息（属性、牌组、特质、物品等）。
## Godot 特色：
## - static func 是静态方法，用 CharacterData.deserialize(data) 调用
## - Time.get_unix_time_from_system() 获取系统时间戳
## - randi() % N 生成 0~N-1 的随机整数
class_name CharacterData

var id: String                ## 角色唯一 id
var name: String              ## 角色名
var created_time: int         ## 创建时间（Unix 时间戳）

var base_stats: Dictionary = {   ## 基础属性（不可被临时 buff 修改的底层值）
	"max_hp": 80,
	"strength": 0,
	"dexterity": 0,
	"initial_block": 0
}

var current_stats: Dictionary = {}  ## 当前属性（升级后的值，覆盖 base_stats）

var deck_card_ids: Array = []  ## 牌组中的卡牌 id 列表

var traits: Array = []  ## 特质列表（被动能力）

var items: Array = []   ## 物品列表

var battles_won: int = 0          ## 胜利战斗次数
var total_damage_dealt: int = 0   ## 累计造成伤害
var levels_cleared: int = 0       ## 已清除层数

func _init(data: Dictionary = {}):
	id = data.get("id", generate_id())
	name = data.get("name", "新角色")
	created_time = data.get("created_time", Time.get_unix_time_from_system())
	
	var saved_base_stats = data.get("base_stats", {})
	for key in saved_base_stats:
		base_stats[key] = saved_base_stats[key]
	
	var saved_current_stats = data.get("current_stats", {})
	for key in saved_current_stats:
		current_stats[key] = saved_current_stats[key]
	
	deck_card_ids = data.get("deck_card_ids", [])
	traits = data.get("traits", [])
	items = data.get("items", [])
	battles_won = data.get("battles_won", 0)
	total_damage_dealt = data.get("total_damage_dealt", 0)
	levels_cleared = data.get("levels_cleared", 0)

## 生成唯一 id（时间戳 + 随机数）
func generate_id() -> String:
	return "char_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)

## 获取实际属性值（优先 current_stats，否则取 base_stats）
func get_max_hp() -> int:
	return current_stats.get("max_hp", base_stats.max_hp)

func get_strength() -> int:
	return current_stats.get("strength", base_stats.strength)

func get_dexterity() -> int:
	return current_stats.get("dexterity", base_stats.dexterity)

func get_initial_block() -> int:
	return current_stats.get("initial_block", base_stats.initial_block)

## 升级属性
func upgrade_stat(stat_name: String, amount: int = 1) -> void:
	if not current_stats.has(stat_name):
		current_stats[stat_name] = base_stats.get(stat_name, 0)
	current_stats[stat_name] += amount

func record_battle_won(damage: int = 0) -> void:
	battles_won += 1
	total_damage_dealt += damage

func record_level_cleared() -> void:
	levels_cleared += 1

func get_deck_size() -> int:
	return deck_card_ids.size()

func add_card_to_deck(card_id: String) -> void:
	if not deck_card_ids.has(card_id):
		deck_card_ids.append(card_id)

func remove_card_from_deck(card_id: String) -> void:
	deck_card_ids.erase(card_id)

func has_trait(trait_id: String) -> bool:
	return traits.has(trait_id)

func add_trait(trait_id: String) -> void:
	if not traits.has(trait_id):
		traits.append(trait_id)

func remove_trait(trait_id: String) -> void:
	traits.erase(trait_id)

func has_item(item_id: String) -> bool:
	return items.has(item_id)

func add_item(item_id: String) -> void:
	if not items.has(item_id):
		items.append(item_id)

func remove_item(item_id: String) -> void:
	items.erase(item_id)

## 序列化角色数据为字典（用于存档）
func serialize() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"created_time": created_time,
		"base_stats": base_stats.duplicate(),
		"current_stats": current_stats.duplicate(),
		"deck_card_ids": deck_card_ids.duplicate(),
		"traits": traits.duplicate(),
		"items": items.duplicate(),
		"battles_won": battles_won,
		"total_damage_dealt": total_damage_dealt,
		"levels_cleared": levels_cleared
	}

## 从字典反序列化创建角色（静态工厂方法）
static func deserialize(data: Dictionary) -> CharacterData:
	return CharacterData.new(data)
