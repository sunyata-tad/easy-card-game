extends Control

@onready var title_label: Label = $TitleLabel
@onready var reward_container: VBoxContainer = $ScrollContainer/RewardContainer

func _ready():
	_setup_exit_button()
	_setup_ui()
	_show_default_rewards()

func _setup_exit_button():
	var exit_button = get_node_or_null("ExitButton")
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)

func _on_exit_pressed():
	SaveManager.save_game(SaveManager.GameProgress.IN_REWARD)
	GameManager.go_to_main_menu()

func _setup_ui():
	if title_label:
		title_label.text = "战斗胜利!"

func _show_default_rewards():
	if reward_container == null:
		return
	
	for child in reward_container.get_children():
		child.queue_free()
	
	_add_reward_option("强化卡牌", "upgrade_card", {})
	_add_reward_option("获得属性", "gain_hp", {"amount": 10})
	_add_reward_option("获得新卡", "new_card", {})
	_add_reward_option("继续战斗", "continue", {})

func _add_reward_option(text: String, reward_type: String, data: Dictionary) -> void:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 50)
	button.pressed.connect(_on_reward_button_pressed.bind(reward_type, data))
	reward_container.add_child(button)

func _on_reward_button_pressed(reward_type: String, data: Dictionary) -> void:
	match reward_type:
		"upgrade_card":
			_show_card_upgrade_selection()
		"gain_hp":
			GameData.heal(data.get("amount", 10))
			_continue_to_next_battle()
		"new_card":
			_show_new_card_selection()
		"continue":
			_continue_to_next_battle()

func _show_card_upgrade_selection():
	if reward_container == null:
		return
	
	for child in reward_container.get_children():
		child.queue_free()
	
	var label = Label.new()
	label.text = "选择要强化的卡牌:"
	reward_container.add_child(label)
	
	var strength = 0
	var dexterity = 0
	
	if CharacterManager.has_current_character():
		var char = CharacterManager.get_current_character()
		strength = char.get_strength()
		dexterity = char.get_dexterity()
	
	var deck = GameData.get_deck()
	for i in range(deck.size()):
		var card = deck[i]
		var button = Button.new()
		var upgrade_info = _get_card_upgrade_info(card, strength, dexterity)
		button.text = "%s (%s: %d → %d)" % [card.name, upgrade_info.type_name, upgrade_info.current_value, upgrade_info.upgraded_value]
		button.custom_minimum_size = Vector2(200, 40)
		button.pressed.connect(_on_card_upgrade_selected.bind(i))
		reward_container.add_child(button)
	
	var back_button = Button.new()
	back_button.text = "返回"
	back_button.pressed.connect(_show_default_rewards)
	reward_container.add_child(back_button)

func _get_card_upgrade_info(card: CardData, strength: int, dexterity: int) -> Dictionary:
	for effect in card.effects:
		var effect_type = effect.get("effect_type", "")
		var base_stat = effect.get("base_stat", "")
		var multiplier = effect.get("multiplier", 1.0)
		
		if base_stat != "":
			var stat_value = 0
			if base_stat == "strength":
				stat_value = strength
			elif base_stat == "dexterity":
				stat_value = dexterity
			
			var current_value = int(stat_value * multiplier)
			var upgraded_multiplier = multiplier + 0.5
			var upgraded_value = int(stat_value * upgraded_multiplier)
			
			if effect_type == "damage":
				return {"type_name": "伤害", "current_value": current_value, "upgraded_value": upgraded_value}
			elif effect_type == "block":
				return {"type_name": "护甲", "current_value": current_value, "upgraded_value": upgraded_value}
		else:
			var base_value = effect.get("value", 0)
			if effect_type == "damage":
				return {"type_name": "伤害", "current_value": base_value, "upgraded_value": base_value + 3}
			if effect_type == "block":
				return {"type_name": "护甲", "current_value": base_value, "upgraded_value": base_value + 3}
	
	return {"type_name": "效果", "current_value": 0, "upgraded_value": 0}

func _get_card_effect_info(card: CardData) -> Dictionary:
	var strength = 0
	var dexterity = 0
	
	if CharacterManager.has_current_character():
		var char = CharacterManager.get_current_character()
		strength = char.get_strength()
		dexterity = char.get_dexterity()
	
	for effect in card.effects:
		var effect_type = effect.get("effect_type", "")
		var base_stat = effect.get("base_stat", "")
		var multiplier = effect.get("multiplier", 1.0)
		var base_value = effect.get("value", 0)
		
		if base_stat != "":
			var stat_value = 0
			if base_stat == "strength":
				stat_value = strength
			elif base_stat == "dexterity":
				stat_value = dexterity
			var final_value = int(stat_value * multiplier)
			
			if effect_type == "damage":
				return {"type_name": "伤害", "value": final_value}
			elif effect_type == "block":
				return {"type_name": "护甲", "value": final_value}
		else:
			if effect_type == "damage":
				return {"type_name": "伤害", "value": base_value}
			if effect_type == "block":
				return {"type_name": "护甲", "value": base_value}
	
	return {"type_name": "效果", "value": 0}

func _show_new_card_selection():
	if reward_container == null:
		return
	
	for child in reward_container.get_children():
		child.queue_free()
	
	var card_db = CardDatabase.new()
	var all_card_ids = card_db.get_all_card_ids()
	
	var available_cards: Array = []
	for card_id in all_card_ids:
		var card = card_db.get_card(card_id)
		if card:
			available_cards.append(card)
	
	available_cards.shuffle()
	var max_choices = mini(3, available_cards.size())
	var offered_cards = available_cards.slice(0, max_choices)
	
	if offered_cards.is_empty():
		var no_cards_label = Label.new()
		no_cards_label.text = "没有可用的卡牌"
		reward_container.add_child(no_cards_label)
		
		var back_button = Button.new()
		back_button.text = "返回"
		back_button.pressed.connect(_show_default_rewards)
		reward_container.add_child(back_button)
		return
	
	var label = Label.new()
	label.text = "选择一张卡牌加入卡组:"
	reward_container.add_child(label)
	
	for i in range(offered_cards.size()):
		var card = offered_cards[i]
		var button = Button.new()
		var effect_info = _get_card_effect_info(card)
		button.text = "%s (%s: %d)" % [card.name, effect_info.type_name, effect_info.value]
		button.custom_minimum_size = Vector2(200, 40)
		button.pressed.connect(_on_new_card_selected.bind(card.id))
		reward_container.add_child(button)
	
	var skip_button = Button.new()
	skip_button.text = "跳过"
	skip_button.pressed.connect(_continue_to_next_battle)
	reward_container.add_child(skip_button)

func _on_new_card_selected(card_id: String):
	var card_db = CardDatabase.new()
	var card = card_db.get_card(card_id)
	if card:
		GameData.add_card_to_deck(card)
	
	_continue_to_next_battle()

func _on_card_upgrade_selected(card_index: int):
	var deck = GameData.get_deck()
	var card = deck[card_index] if card_index >= 0 and card_index < deck.size() else null
	
	if card:
		GameData.upgrade_card_at_index(card_index)
	
	_continue_to_next_battle()

func _continue_to_next_battle():
	GameData.record_battle_won()
	SaveManager.save_at_reward_screen()
	
	var enemy = GameData.get_random_enemy_for_battle()
	if enemy:
		GameManager.start_battle([enemy])
	else:
		GameManager.go_to_game_over(GameData.get_battle_stats())
