extends Control

@onready var title_label: Label = $TitleLabel
@onready var reward_container: VBoxContainer = $ScrollContainer/RewardContainer

var _battle_stats: Dictionary = {}

func _ready():
	_setup_ui()

func receive_data(data: Dictionary) -> void:
	_battle_stats = data.get("battle_stats", {})
	_setup_ui()

func _setup_ui():
	if title_label:
		title_label.text = "战斗胜利!"
	
	if reward_container == null:
		return
	
	for child in reward_container.get_children():
		child.queue_free()
	
	var stats = GameData.get_battle_stats() if GameData else {}
	
	var stats_label = Label.new()
	stats_label.text = "战果统计"
	stats_label.add_theme_font_size_override("font_size", 16)
	reward_container.add_child(stats_label)
	
	var hp_info = Label.new()
	hp_info.text = "当前生命: %d / %d" % [stats.get("final_hp", 0), GameData.player_max_hp if GameData else 80]
	reward_container.add_child(hp_info)
	
	var battle_info = Label.new()
	battle_info.text = "累计胜场: %d" % stats.get("battles_won", 0)
	reward_container.add_child(battle_info)
	
	reward_container.add_child(HSeparator.new())
	
	var card_label = Label.new()
	card_label.text = "选择一张卡牌加入卡组（或跳过）:"
	card_label.add_theme_font_size_override("font_size", 14)
	reward_container.add_child(card_label)
	
	_show_card_choices()
	
	reward_container.add_child(HSeparator.new())
	
	var skip_btn = Button.new()
	skip_btn.text = "跳过，返回地图"
	skip_btn.custom_minimum_size = Vector2(200, 40)
	skip_btn.pressed.connect(_on_return_to_map)
	reward_container.add_child(skip_btn)

func _show_card_choices():
	if reward_container == null:
		return
	
	var card_db = CardDatabase.new()
	var all_card_ids = card_db.get_all_card_ids()
	
	var available_cards: Array = []
	for card_id in all_card_ids:
		var card = card_db.get_card(card_id)
		if card and card.rarity != "basic":
			available_cards.append(card)
	
	available_cards.shuffle()
	var max_choices = mini(3, available_cards.size())
	var offered_cards = available_cards.slice(0, max_choices)
	
	if offered_cards.is_empty():
		var no_cards_label = Label.new()
		no_cards_label.text = "没有可选卡牌"
		reward_container.add_child(no_cards_label)
		return
	
	for card in offered_cards:
		var btn = Button.new()
		btn.text = "%s - %s" % [card.name, card.description]
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_on_card_selected.bind(card.id))
		reward_container.add_child(btn)

func _on_card_selected(card_id: String):
	var card_db = CardDatabase.new()
	var card = card_db.get_card(card_id)
	if card and GameData:
		GameData.add_card_to_deck(card.duplicate())
	_on_return_to_map()

func _on_return_to_map():
	SaveManager.save_map_state()
	var cached_state = SaveManager._cached_map_state
	GameManager.go_to_map("test_map", cached_state)
