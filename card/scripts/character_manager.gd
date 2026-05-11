extends Node

const CHARACTERS_PATH := "user://characters.json"

var characters: Array = []
var current_character: CharacterData = null

signal character_created(character: CharacterData)
signal character_deleted(character_id: String)
signal current_character_changed(character: CharacterData)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_characters()

func _load_characters() -> void:
	var file := FileAccess.open(CHARACTERS_PATH, FileAccess.READ)
	if file == null:
		characters = []
		return
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_text) != OK:
		characters = []
		return
	
	var data_array: Array = json.data
	characters = []
	for char_data in data_array:
		characters.append(CharacterData.deserialize(char_data))

func _save_characters() -> void:
	var data_array: Array = []
	for char in characters:
		data_array.append(char.serialize())
	
	var json_string := JSON.stringify(data_array, "  ")
	var file := FileAccess.open(CHARACTERS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

func create_character(name: String, base_stats: Dictionary, deck_ids: Array, traits: Array, items: Array) -> CharacterData:
	var char_data := CharacterData.new({
		"name": name,
		"base_stats": base_stats,
		"deck_card_ids": deck_ids,
		"traits": traits,
		"items": items
	})
	
	characters.append(char_data)
	_save_characters()
	character_created.emit(char_data)
	
	return char_data

func delete_character(character_id: String) -> bool:
	for i in range(characters.size()):
		if characters[i].id == character_id:
			var deleted_char = characters[i]
			characters.erase(deleted_char)
			_save_characters()
			
			if current_character and current_character.id == character_id:
				current_character = null
			
			character_deleted.emit(character_id)
			return true
	return false

func get_character(character_id: String) -> CharacterData:
	for char in characters:
		if char.id == character_id:
			return char
	return null

func get_all_characters() -> Array:
	return characters.duplicate()

func select_character(character_id: String) -> bool:
	var char = get_character(character_id)
	if char:
		current_character = char
		current_character_changed.emit(char)
		return true
	return false

func get_current_character() -> CharacterData:
	return current_character

func has_current_character() -> bool:
	return current_character != null

func update_current_character() -> void:
	if current_character:
		_save_characters()

func get_character_count() -> int:
	return characters.size()

func has_characters() -> bool:
	return characters.size() > 0
