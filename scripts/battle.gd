extends Control

var battle_controller: BattleController
var battle_stats: Dictionary = {
	"damage_dealt": 0,
	"cards_played": 0
}
var character_stats: Dictionary = {}
var is_initialized: bool = false
var discard_required_count: int = 0

func _ready():
	_setup_exit_button()

func _setup_exit_button():
	var exit_button = get_node_or_null("ExitButton")
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)

func receive_data(data: Dictionary) -> void:
	if not is_initialized:
		is_initialized = true
		_initialize_battle(data)

func _initialize_battle(data: Dictionary = {}):
	battle_controller = BattleController.new()
	battle_controller.battle_ended.connect(_on_battle_ended)
	battle_controller.turn_changed.connect(_on_turn_changed)
	battle_controller.discard_phase_started.connect(_on_discard_phase_started)
	
	var enemies_data: Array = data.get("enemies", [])
	var deck_data: Array = []
	
	if GameData:
		if enemies_data.is_empty():
			var enemy = GameData.get_random_enemy_for_battle()
			if enemy:
				enemies_data = [enemy]
		deck_data = GameData.get_deck()
	
	battle_controller.setup_battle(self, deck_data, enemies_data)
	battle_controller.start_battle()

func _on_exit_pressed():
	_show_exit_confirmation()

func _show_exit_confirmation():
	var confirmation = AcceptDialog.new()
	confirmation.dialog_text = "确定要退出吗？\n当前进度将会保存。"
	confirmation.add_button("保存并退出", true, "save_exit")
	confirmation.add_cancel_button("取消")
	add_child(confirmation)
	
	confirmation.custom_action.connect(_on_exit_dialog_action)
	confirmation.confirmed.connect(_on_exit_confirmed)
	confirmation.popup_centered()

func _on_exit_dialog_action(action: String):
	if action == "save_exit":
		_save_and_exit()

func _on_exit_confirmed():
	_save_and_exit()

func _save_and_exit():
	SaveManager.save_map_state()
	GameManager.go_to_map("test_map", SaveManager._cached_map_state)

func _on_battle_ended(victory: bool):
	battle_stats.victory = victory
	
	if victory:
		await get_tree().create_timer(0.5).timeout
		if GameData:
			GameData.record_battle_won()
			SaveManager.save_map_state()
			GameManager.go_to_reward(battle_stats)
		else:
			_show_victory_screen()
	else:
		await get_tree().create_timer(0.5).timeout
		if GameData:
			var stats = GameData.get_battle_stats()
			stats.victory = false
			SaveManager.save_game_over()
			GameManager.go_to_game_over(stats)
		else:
			_show_defeat_screen()

func _on_turn_changed(is_player_turn: bool):
	if is_player_turn:
		print("玩家回合")
	else:
		print("敌人回合")

func _on_discard_phase_started(cards_to_discard: int) -> void:
	discard_required_count = cards_to_discard
	if battle_controller and battle_controller.ui_controller:
		battle_controller.ui_controller.enter_card_select_mode(
			"弃牌阶段：选择至多 %d 张牌弃掉" % cards_to_discard,
			0, cards_to_discard,
			_on_discard_select_done
		)

func _on_discard_select_done(selected_cards: Array) -> void:
	battle_controller.confirm_discard_cards(selected_cards)

func _show_victory_screen():
	var victory_label = Label.new()
	victory_label.text = "战斗胜利!"
	victory_label.add_theme_font_size_override("font_size", 48)
	victory_label.add_theme_color_override("font_color", Color.GREEN)
	victory_label.set_anchors_preset(Control.PRESET_CENTER)
	victory_label.position = Vector2(-100, -24)
	add_child(victory_label)
	
	var continue_button = Button.new()
	continue_button.text = "继续"
	continue_button.add_theme_font_size_override("font_size", 24)
	continue_button.set_anchors_preset(Control.PRESET_CENTER)
	continue_button.position = Vector2(-40, 30)
	continue_button.pressed.connect(_on_continue_pressed)
	add_child(continue_button)

func _show_defeat_screen():
	var defeat_label = Label.new()
	defeat_label.text = "战斗失败..."
	defeat_label.add_theme_font_size_override("font_size", 48)
	defeat_label.add_theme_color_override("font_color", Color.RED)
	defeat_label.set_anchors_preset(Control.PRESET_CENTER)
	defeat_label.position = Vector2(-120, -24)
	add_child(defeat_label)
	
	var retry_button = Button.new()
	retry_button.text = "重试"
	retry_button.add_theme_font_size_override("font_size", 24)
	retry_button.set_anchors_preset(Control.PRESET_CENTER)
	retry_button.position = Vector2(-40, 30)
	retry_button.pressed.connect(_on_retry_pressed)
	add_child(retry_button)

func _on_continue_pressed():
	if GameData:
		GameData.record_battle_won()
		SaveManager.save_map_state()
		GameManager.go_to_map("test_map", SaveManager._cached_map_state)

func _on_retry_pressed():
	if GameData:
		SaveManager.delete_save()
		GameData.initialize_new_run()
		GameManager.go_to_main_menu()

func start_new_battle(enemies: Array = []):
	if battle_controller:
		battle_controller.setup_battle(self, [], enemies)
		battle_controller.start_battle()

func record_damage_dealt(amount: int):
	battle_stats.damage_dealt += amount
	if GameData:
		GameData.record_damage_dealt(amount)

func record_card_played():
	battle_stats.cards_played += 1
	if GameData:
		GameData.record_card_played()
