class_name CharacterData

var id: String
var name: String
var created_time: int

var base_stats: Dictionary = {
	"max_hp": 80,
	"strength": 0,
	"dexterity": 0,
	"initial_block": 0
}

var current_stats: Dictionary = {}

var deck_card_ids: Array = []

var traits: Array = []

var items: Array = []

var battles_won: int = 0
var total_damage_dealt: int = 0
var levels_cleared: int = 0

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

func generate_id() -> String:
	return "char_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)

func get_max_hp() -> int:
	return current_stats.get("max_hp", base_stats.max_hp)

func get_strength() -> int:
	return current_stats.get("strength", base_stats.strength)

func get_dexterity() -> int:
	return current_stats.get("dexterity", base_stats.dexterity)

func get_initial_block() -> int:
	return current_stats.get("initial_block", base_stats.initial_block)

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

static func deserialize(data: Dictionary) -> CharacterData:
	return CharacterData.new(data)
