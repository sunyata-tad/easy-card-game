extends Node

const CARD_POOL_PATH := "user://card_pool.json"
var unlocked_card_ids: Array = []

signal card_pool_changed()

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_pool()

func add_card(card_id: String) -> void:
	if not unlocked_card_ids.has(card_id):
		unlocked_card_ids.append(card_id)
		save_pool()
		card_pool_changed.emit()

func add_cards(card_ids: Array) -> void:
	var changed := false
	for card_id in card_ids:
		if not unlocked_card_ids.has(card_id):
			unlocked_card_ids.append(card_id)
			changed = true
	if changed:
		save_pool()
		card_pool_changed.emit()

func has_card(card_id: String) -> bool:
	return unlocked_card_ids.has(card_id)

func get_all_card_ids() -> Array:
	return unlocked_card_ids.duplicate()

func get_card_count() -> int:
	return unlocked_card_ids.size()

func initialize_with_starter_cards() -> void:
	if not unlocked_card_ids.is_empty():
		return

	var path := "res://data/decks.json"
	var json_text := FileAccess.get_file_as_string(path)
	if json_text.is_empty():
		return

	var json := JSON.new()
	if json.parse(json_text) != OK:
		return

	var starter_list = json.data.get("starter_deck", [])
	for entry in starter_list:
		var card_id = entry.get("card_id", "")
		if not card_id.is_empty() and not unlocked_card_ids.has(card_id):
			unlocked_card_ids.append(card_id)

	save_pool()
	card_pool_changed.emit()

func save_pool() -> void:
	var data := {
		"version": 1,
		"unlocked_card_ids": unlocked_card_ids
	}
	var json_string := JSON.stringify(data, "  ")
	var file := FileAccess.open(CARD_POOL_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

func load_pool() -> void:
	if not FileAccess.file_exists(CARD_POOL_PATH):
		return

	var file := FileAccess.open(CARD_POOL_PATH, FileAccess.READ)
	if file == null:
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) == OK:
		var data = json.data
		unlocked_card_ids = data.get("unlocked_card_ids", [])

func clear_pool() -> void:
	unlocked_card_ids.clear()
	save_pool()
	card_pool_changed.emit()
