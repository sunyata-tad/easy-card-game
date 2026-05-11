extends Node

var player_deck: Array = []
var player_max_hp: int = 80
var player_current_hp: int = 80
var gold: int = 0
var battles_won: int = 0
var total_damage_dealt: int = 0
var cards_played: int = 0

var card_database: CardDatabase
var enemy_database: EnemyDatabase

signal deck_changed(deck: Array)
signal hp_changed(current: int, maximum: int)
signal gold_changed(amount: int)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	card_database = CardDatabase.new()
	enemy_database = EnemyDatabase.new()

func initialize_new_run() -> void:
	player_deck = card_database.load_starter_deck()
	player_max_hp = 80
	player_current_hp = player_max_hp
	gold = 0
	battles_won = 0
	total_damage_dealt = 0
	cards_played = 0
	
	deck_changed.emit(player_deck)
	hp_changed.emit(player_current_hp, player_max_hp)

func get_deck() -> Array:
	return player_deck.duplicate()

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

func get_random_enemy_for_battle() -> EnemyData:
	var all_enemies = enemy_database.get_all_enemy_ids()
	if all_enemies.is_empty():
		return null
	var enemy_id = all_enemies.pick_random()
	return enemy_database.get_enemy(enemy_id)
