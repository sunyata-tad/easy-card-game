extends Node

const SAVE_PATH := "user://savegame.json"

enum GameProgress {
	NONE,
	IN_BATTLE,
	IN_REWARD,
	GAME_OVER
}

func save_game(progress: int = GameProgress.IN_BATTLE, additional_data: Dictionary = {}) -> bool:
	var save_data := {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"progress": progress,
		"game_data": _serialize_game_data(),
		"additional": additional_data
	}
	
	var json_string := JSON.stringify(save_data, "  ")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	
	if file == null:
		push_error("SaveManager: Failed to open save file")
		return false
	
	file.store_string(json_string)
	file.close()
	print("SaveManager: Game saved successfully")
	return true

func load_game() -> Dictionary:
	if not has_save():
		return {}
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open save file for reading")
		return {}
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("SaveManager: Failed to parse save file")
		return {}
	
	var save_data: Dictionary = json.data
	return save_data

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
		print("SaveManager: Save deleted")

func get_save_info() -> Dictionary:
	if not has_save():
		return {"exists": false}
	
	var save_data := load_game()
	if save_data.is_empty():
		return {"exists": false}
	
	var timestamp = save_data.get("timestamp", 0)
	var datetime := Time.get_datetime_dict_from_unix_time(timestamp)
	
	return {
		"exists": true,
		"progress": save_data.get("progress", GameProgress.NONE),
		"timestamp": timestamp,
		"datetime": datetime,
		"battles_won": save_data.get("game_data", {}).get("battles_won", 0),
		"player_hp": save_data.get("game_data", {}).get("player_current_hp", 0)
	}

func _serialize_game_data() -> Dictionary:
	if not GameData:
		return {}
	
	var deck_data: Array = []
	for card in GameData.player_deck:
		deck_data.append({
			"id": card.id,
			"name": card.name,
			"is_upgraded": card.is_upgraded,
			"effects": card.effects.duplicate(true),
			"tags": card.tags.duplicate(),
			"treated_as": card.treated_as.duplicate()
		})
	
	return {
		"player_deck": deck_data,
		"player_max_hp": GameData.player_max_hp,
		"player_current_hp": GameData.player_current_hp,
		"player_strength": GameData.player_strength,
		"player_dexterity": GameData.player_dexterity,
		"gold": GameData.gold,
		"battles_won": GameData.battles_won,
		"total_damage_dealt": GameData.total_damage_dealt,
		"cards_played": GameData.cards_played
	}

func apply_game_data(data: Dictionary) -> void:
	if not GameData:
		return
	
	var game_data = data.get("game_data", {})
	
	GameData.player_max_hp = game_data.get("player_max_hp", 80)
	GameData.player_current_hp = game_data.get("player_current_hp", 80)
	GameData.player_strength = game_data.get("player_strength", 0)
	GameData.player_dexterity = game_data.get("player_dexterity", 0)
	GameData.gold = game_data.get("gold", 0)
	GameData.battles_won = game_data.get("battles_won", 0)
	GameData.total_damage_dealt = game_data.get("total_damage_dealt", 0)
	GameData.cards_played = game_data.get("cards_played", 0)
	
	var deck_data = game_data.get("player_deck", [])
	GameData.player_deck.clear()
	
	var card_db := CardDatabase.new()
	for card_info in deck_data:
		var card_id = card_info.get("id", "")
		var card = card_db.get_card(card_id)
		if card:
			card = card.duplicate()
			card.is_upgraded = card_info.get("is_upgraded", false)
			var saved_name = card_info.get("name", "")
			if saved_name != "":
				card.name = saved_name
			var effects = card_info.get("effects", [])
			if effects.size() > 0:
				card.effects = effects
			var tags = card_info.get("tags", [])
			if tags.size() > 0:
				card.tags = tags
			var treated_as = card_info.get("treated_as", [])
			if treated_as.size() > 0:
				card.treated_as = treated_as
			GameData.player_deck.append(card)
			print("加载卡牌: %s, is_upgraded=%s, effects=%s, tags=%s" % [card.name, str(card.is_upgraded), str(card.effects), str(card.tags)])
	
	print("加载角色属性: HP=%d/%d, 力量=%d, 敏捷=%d" % [GameData.player_current_hp, GameData.player_max_hp, GameData.player_strength, GameData.player_dexterity])
	
	GameData.deck_changed.emit(GameData.player_deck)
	GameData.hp_changed.emit(GameData.player_current_hp, GameData.player_max_hp)
	GameData.gold_changed.emit(GameData.gold)
	GameData.stats_changed.emit(GameData.player_strength, GameData.player_dexterity)

func save_before_battle_exit() -> bool:
	return save_game(GameProgress.IN_BATTLE, {"was_in_battle": true})

func save_at_reward_screen() -> bool:
	return save_game(GameProgress.IN_REWARD, {"was_in_battle": false})

func save_game_over() -> bool:
	return save_game(GameProgress.GAME_OVER, {"was_in_battle": false})

func get_progress_description(progress: int) -> String:
	match progress:
		GameProgress.IN_BATTLE:
			return "战斗中"
		GameProgress.IN_REWARD:
			return "结算中"
		GameProgress.GAME_OVER:
			return "游戏结束"
		_:
			return "未知"
