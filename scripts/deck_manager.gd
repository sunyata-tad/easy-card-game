extends Node

const DECKS_DIR := "user://decks/"
const MIN_DECK_SIZE := 9
const MAX_DECK_SIZE := 9
const MAX_CARD_COPIES := 3

func _ready():
	_ensure_decks_dir()

func _ensure_decks_dir() -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("decks"):
		dir.make_dir("decks")

func save_deck(deck_name: String, cards: Array) -> bool:
	var deck_data = {"name": deck_name, "cards": cards}
	var path = DECKS_DIR + deck_name + ".json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(deck_data, "\t"))
	file.close()
	return true

func load_deck(deck_name: String) -> Dictionary:
	var path = DECKS_DIR + deck_name + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var text = FileAccess.get_file_as_string(path)
	var json = JSON.new()
	if json.parse(text) == OK:
		return json.data
	return {}

func get_all_deck_names() -> Array:
	var names: Array = []
	var dir = DirAccess.open(DECKS_DIR)
	if dir == null:
		return names
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			names.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()
	return names

func delete_deck(deck_name: String) -> bool:
	var path = DECKS_DIR + deck_name + ".json"
	return DirAccess.remove_absolute(path) == OK

func validate_deck(cards: Array) -> Dictionary:
	var total := 0
	var card_db = CardDatabase.new()
	for entry in cards:
		var count = entry.get("count", 0)
		var card_id = entry.get("card_id", "")
		if count > MAX_CARD_COPIES:
			return {"valid": false, "error": "每张卡至多放入%d张" % MAX_CARD_COPIES}
		var card = card_db.get_card(card_id)
		if card and card.rarity == "epic" and count > 1:
			return {"valid": false, "error": "唯一卡牌「%s」只能放入1张" % card.name}
		total += count
	if total < MIN_DECK_SIZE:
		return {"valid": false, "error": "卡组至少需要%d张卡（当前%d张）" % [MIN_DECK_SIZE, total]}
	if total > MAX_DECK_SIZE:
		return {"valid": false, "error": "卡组至多%d张卡（当前%d张）" % [MAX_DECK_SIZE, total]}
	return {"valid": true, "error": ""}

func get_deck_total(cards: Array) -> int:
	var total := 0
	for entry in cards:
		total += entry.get("count", 0)
	return total