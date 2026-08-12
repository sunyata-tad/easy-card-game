## 全局游戏数据：作为单例节点持有玩家在当前 run 中的所有状态（血量/属性/牌组/金币等）。
## Godot 特色：
## - extends Node 配合全局自动加载（autoload）实现单例模式（类似 Java 的 Singleton）
## - process_mode = PROCESS_MODE_ALWAYS 确保节点在暂停时仍然运行
extends Node

var player_deck: Array = []       ## 玩家当前牌组
var player_max_hp: int = 50       ## 最大血量
var player_current_hp: int = 50   ## 当前血量
var player_strength: int = 5      ## 力量属性
var player_dexterity: int = 0     ## 敏捷属性
var relics: Array = []            ## 本局持有的遗物实例列表（RelicData，每个独立、不去重）
var gold: int = 0                 ## 金币
var battles_won: int = 0          ## 胜利次数
var total_damage_dealt: int = 0   ## 累计造成伤害
var cards_played: int = 0         ## 累计打出卡牌数
var player_exp: int = 0           ## 当前经验值
var player_level: int = 1         ## 玩家等级
var player_attribute_points: int = 0  ## 未分配属性点

var card_database: CardDatabase   ## 卡牌数据库
var enemy_database: EnemyDatabase ## 敌人数据库
var relic_database: RelicDatabase ## 遗物数据库

signal deck_changed(deck: Array)                           ## 牌组变化
signal hp_changed(current: int, maximum: int)              ## 血量变化
signal gold_changed(amount: int)                           ## 金币变化
signal stats_changed(strength: int, dexterity: int)        ## 属性变化
signal exp_changed(current: int, needed: int)              ## 经验值变化
signal level_changed(level: int)                           ## 等级变化
signal attribute_points_changed(points: int)               ## 属性点变化

func _ready():
	# 设置为始终运行模式（即使场景切换也不暂停更新）
	process_mode = Node.PROCESS_MODE_ALWAYS
	card_database = CardDatabase.new()
	enemy_database = EnemyDatabase.new()
	relic_database = RelicDatabase.new()

## 初始化一次新的 run（使用默认初始牌组和属性）
func initialize_new_run() -> void:
	player_deck = card_database.load_starter_deck()
	player_max_hp = 50
	player_current_hp = player_max_hp
	player_strength = 5
	player_dexterity = 0
	relics = []
	gold = 0
	battles_won = 0
	total_damage_dealt = 0
	cards_played = 0
	player_exp = 0
	player_level = 1
	player_attribute_points = 0

	deck_changed.emit(player_deck)
	hp_changed.emit(player_current_hp, player_max_hp)
	stats_changed.emit(player_strength, player_dexterity)
	exp_changed.emit(player_exp, get_exp_for_next_level())
	level_changed.emit(player_level)
	attribute_points_changed.emit(player_attribute_points)

## 从角色数据初始化 run（用于选角后的开局）
func initialize_run_from_character(character: CharacterData) -> void:
	player_max_hp = character.get_max_hp()
	player_current_hp = player_max_hp
	player_strength = character.get_strength()
	player_dexterity = character.get_dexterity()
	gold = 0
	battles_won = 0
	total_damage_dealt = 0
	cards_played = 0
	player_exp = 0
	player_level = 1
	player_attribute_points = 0

	player_deck.clear()
	var card_db := CardDatabase.new()
	for card_id in character.deck_card_ids:
		var card = card_db.get_card(card_id)
		if card:
			player_deck.append(card.duplicate())

	deck_changed.emit(player_deck)
	hp_changed.emit(player_current_hp, player_max_hp)
	stats_changed.emit(player_strength, player_dexterity)

## 获得一个遗物：创建独立实例加入列表（不去重；可重复遗物可拥有多个）
func grant_relic(relic_id: String) -> void:
	var relic = relic_database.get_relic(relic_id)
	if relic:
		relics.append(relic.duplicate())

## 获取遗物实例列表副本（RelicData，每个独立）
func get_relics() -> Array:
	return relics.duplicate()

## 获取已拥有遗物 id 列表（含重复，供遗物池过滤等使用）
func get_relic_ids() -> Array:
	var ids: Array = []
	for relic in relics:
		ids.append(relic.id)
	return ids

func get_deck() -> Array:
	return player_deck.duplicate()

## 升级指定索引的卡牌（增加伤害/护甲值）
func upgrade_card_at_index(card_index: int, increase: int = 3) -> bool:
	if card_index < 0 or card_index >= player_deck.size():
		return false
	
	var card = player_deck[card_index]
	var upgraded = false
	
	for effect in card.effects:
		var effect_type = effect.get("effect_type", "")
		var base_stat = effect.get("base_stat", "")
		
		if effect_type == "damage" or effect_type == "block":
			if base_stat != "":
				var current_multiplier = effect.get("multiplier", 1.0)
				effect.multiplier = current_multiplier + 0.5
			else:
				effect.value = effect.get("value", 0) + increase
			upgraded = true
	
	if upgraded:
		card.is_upgraded = true
		if card.name.find("+") == -1:
			card.name = card.name + "+"
		deck_changed.emit(player_deck)
	
	return upgraded

func add_card_to_deck(card: CardData) -> void:
	player_deck.append(card.duplicate())
	deck_changed.emit(player_deck)

func remove_card_from_deck(card: CardData) -> void:
	if player_deck.has(card):
		player_deck.erase(card)
		deck_changed.emit(player_deck)

func heal(amount: int) -> void:
	player_current_hp = mini(player_current_hp + amount, player_max_hp)
	hp_changed.emit(player_current_hp, player_max_hp)

func take_damage(amount: int) -> void:
	player_current_hp = maxi(player_current_hp - amount, 0)
	hp_changed.emit(player_current_hp, player_max_hp)

func increase_max_hp(amount: int) -> void:
	player_max_hp += amount
	player_current_hp += amount
	hp_changed.emit(player_current_hp, player_max_hp)

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false

## 记录战斗统计
func record_battle_won() -> void:
	battles_won += 1

func record_damage_dealt(amount: int) -> void:
	total_damage_dealt += amount

func record_card_played() -> void:
	cards_played += 1

func get_battle_stats() -> Dictionary:
	return {
		"battles_won": battles_won,
		"total_damage": total_damage_dealt,
		"cards_played": cards_played,
		"final_hp": player_current_hp,
		"max_hp": player_max_hp
	}

func is_player_alive() -> bool:
	return player_current_hp > 0

## 牌组内标签检索
func get_cards_in_deck_by_tag(tag: String) -> Array:
	var result: Array = []
	for card in player_deck:
		if card.has_tag(tag):
			result.append(card)
	return result

func get_cards_in_deck_by_any_tags(tags: Array) -> Array:
	var result: Array = []
	for card in player_deck:
		if card.has_any_tag(tags):
			result.append(card)
	return result

func get_cards_in_deck_by_all_tags(tags: Array) -> Array:
	var result: Array = []
	for card in player_deck:
		if card.has_all_tags(tags):
			result.append(card)
	return result

func count_cards_with_tag(tag: String) -> int:
	var count = 0
	for card in player_deck:
		if card.has_tag(tag):
			count += 1
	return count

func has_card_with_tag(tag: String) -> bool:
	for card in player_deck:
		if card.has_tag(tag):
			return true
	return false

## 获取升到下一级所需经验值（公式：等级 × 100）
func get_exp_for_next_level() -> int:
	return player_level * 100

## 获得经验值（溢出自动升级）
func gain_exp(amount: int) -> void:
	player_exp += amount
	var needed = get_exp_for_next_level()
	while player_exp >= needed:
		player_exp -= needed
		player_level += 1
		player_attribute_points += 1
		needed = get_exp_for_next_level()
		level_changed.emit(player_level)
		attribute_points_changed.emit(player_attribute_points)
	exp_changed.emit(player_exp, needed)
	level_changed.emit(player_level)

## 使用1点属性点增加力量
func use_attribute_point_strength() -> bool:
	if player_attribute_points <= 0:
		return false
	player_attribute_points -= 1
	player_strength += 1
	attribute_points_changed.emit(player_attribute_points)
	stats_changed.emit(player_strength, player_dexterity)
	return true

## 使用1点属性点增加敏捷
func use_attribute_point_dexterity() -> bool:
	if player_attribute_points <= 0:
		return false
	player_attribute_points -= 1
	player_dexterity += 1
	attribute_points_changed.emit(player_attribute_points)
	stats_changed.emit(player_strength, player_dexterity)
	return true

## 使用1点属性点增加5点最大血量
func use_attribute_point_hp() -> bool:
	if player_attribute_points <= 0:
		return false
	player_attribute_points -= 1
	player_max_hp += 5
	player_current_hp += 5
	attribute_points_changed.emit(player_attribute_points)
	hp_changed.emit(player_current_hp, player_max_hp)
	return true

## 随机获取一个敌人用于战斗
func get_random_enemy_for_battle() -> EnemyData:
	var all_enemies = enemy_database.get_all_enemy_ids()
	if all_enemies.is_empty():
		return null
	var enemy_id = all_enemies.pick_random()
	return enemy_database.get_enemy(enemy_id)
