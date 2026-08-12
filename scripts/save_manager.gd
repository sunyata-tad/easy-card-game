## 存档管理器：持久化游戏进度到本地 JSON 文件（user://savegame.json）。
## Godot 特色：
## - user:// 路径指向用户数据目录（跨平台自动适配）
## - Time.get_datetime_dict_from_unix_time() 将时间戳转为可读的日期时间字典
## - DirAccess.remove_absolute() 删除文件
## - JSON.stringify(data, "  ") 格式化为带缩进的 JSON
extends Node

const SAVE_PATH := "user://savegame.json"  ## 存档文件路径

## 游戏进度状态枚举
enum GameProgress {
	NONE,        ## 无存档
	IN_BATTLE,   ## 战斗中
	IN_MAP,      ## 地图探索中
	GAME_OVER    ## 游戏结束
}

var _cached_map_state: Dictionary = {}  ## 缓存的地图状态（用于非当前场景时也能保存）

## 保存游戏
## @param progress: 当前进度类型
## @param additional_data: 额外数据（如敌人 id、地图 id 等）
func save_game(progress: int = GameProgress.IN_MAP, additional_data: Dictionary = {}) -> bool:
	var save_data := {
		"version": 2,
		"timestamp": Time.get_unix_time_from_system(),
		"progress": progress,
		"game_data": _serialize_game_data(),
		"map_state": _serialize_map_state(),
		"enemy_id": additional_data.get("enemy_id", ""),
		"map_id": additional_data.get("map_id", "endless"),
		"additional": additional_data
	}
	
	var json_string := JSON.stringify(save_data, "  ")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	
	if file == null:
		push_error("SaveManager: Failed to open save file")
		return false
	
	file.store_string(json_string)
	file.close()
	return true

## 读取存档
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

## 检查存档是否存在
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## 删除存档
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

## 获取存档摘要信息（用于 UI 显示）
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

## 序列化 GameData 的当前状态
func _serialize_game_data() -> Dictionary:
	if not GameData:
		return {}
	
	# 序列化牌组（每张卡牌单独保存，确保 tags/treated_as 等动态修改能恢复）
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
	
	# 序列化遗物（每个独立实例存为 id，保留重复；可重复遗物可多个）
	var relic_ids: Array = []
	for relic in GameData.relics:
		if relic is String:
			relic_ids.append(relic)
		else:
			relic_ids.append(relic.id)

	return {
		"player_deck": deck_data,
		"relics": relic_ids,
		"player_max_hp": GameData.player_max_hp,
		"player_current_hp": GameData.player_current_hp,
		"player_strength": GameData.player_strength,
		"player_dexterity": GameData.player_dexterity,
		"gold": GameData.gold,
		"battles_won": GameData.battles_won,
		"total_damage_dealt": GameData.total_damage_dealt,
		"cards_played": GameData.cards_played,
		"player_exp": GameData.player_exp,
		"player_level": GameData.player_level,
		"player_attribute_points": GameData.player_attribute_points
	}

## 序列化地图状态
func _serialize_map_state() -> Dictionary:
	var map_screen = _get_map_screen()
	if map_screen and map_screen.has_method("get_map_state"):
		var state = map_screen.get_map_state()
		if not state.is_empty():
			_cached_map_state = state
		return state
	return _cached_map_state

## 获取当前地图场景节点
func _get_map_screen() -> Node:
	if not GameManager:
		return null
	var current = GameManager.current_scene
	if current and current.has_method("get_map_state"):
		return current
	return null

## 将存档数据恢复到 GameData
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
	GameData.player_exp = game_data.get("player_exp", 0)
	GameData.player_level = game_data.get("player_level", 1)
	GameData.player_attribute_points = game_data.get("player_attribute_points", 0)
	
	# 恢复牌组（优先使用存档中的升级/标签数据）
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
	
	# 恢复遗物（每个独立实例；重复 id 保留为多个）
	GameData.relics.clear()
	var relic_db := RelicDatabase.new()
	for rid in game_data.get("relics", []):
		var relic = relic_db.get_relic(rid)
		if relic:
			GameData.relics.append(relic.duplicate())
	
	GameData.deck_changed.emit(GameData.player_deck)
	GameData.hp_changed.emit(GameData.player_current_hp, GameData.player_max_hp)
	GameData.gold_changed.emit(GameData.gold)
	GameData.stats_changed.emit(GameData.player_strength, GameData.player_dexterity)

## 快捷存档方法
func save_map_state() -> bool:
	return save_game(GameProgress.IN_MAP)

func save_before_battle(enemy_id: String, map_id: String = "endless", endless_layer: int = 0, is_test_mode: bool = false, is_boss: bool = false) -> bool:
	return save_game(GameProgress.IN_BATTLE, {"enemy_id": enemy_id, "map_id": map_id, "endless_layer": endless_layer, "is_test_mode": is_test_mode, "is_boss": is_boss})

func get_cached_map_state() -> Dictionary:
	return _cached_map_state

func save_game_over() -> bool:
	return save_game(GameProgress.GAME_OVER)

## 获取进度描述文字（用于 UI 显示）
func get_progress_description(progress: int) -> String:
	match progress:
		GameProgress.IN_MAP:
			return "探索地图"
		GameProgress.IN_BATTLE:
			return "战斗中"
		GameProgress.GAME_OVER:
			return "游戏结束"
		_:
			return "未知"