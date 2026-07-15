## 角色管理器：全局单例，管理所有角色的持久化存储（user://characters.json）。
## 负责角色的创建、删除、选择、序列化/反序列化。
## Godot 特色：
## - JSON.stringify(data_array, "  ") 将数组序列化为 JSON 字符串
extends Node

const CHARACTERS_PATH := "user://characters.json"  ## 角色存档文件路径

var characters: Array = []                ## 所有角色的 CharacterData 列表
var current_character: CharacterData = null  ## 当前选中的角色

signal character_created(character: CharacterData)         ## 角色创建
signal character_deleted(character_id: String)             ## 角色删除
signal current_character_changed(character: CharacterData) ## 当前角色切换

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_characters()

## 从 JSON 文件加载所有角色
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

## 将所有角色序列化并保存到 JSON 文件
func _save_characters() -> void:
	var data_array: Array = []
	for char in characters:
		data_array.append(char.serialize())

	var json_string := JSON.stringify(data_array, "  ")
	var file := FileAccess.open(CHARACTERS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

## 创建新角色
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

## 删除角色（按 id）
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

## 选择当前角色
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