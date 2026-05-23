extends Control

var _confirmation_dialog: ConfirmationDialog = null

func _ready():
	_setup_buttons()
	_update_continue_button()

func _setup_buttons():
	var start_button = get_node_or_null("Button_start")
	var continue_button = get_node_or_null("Button_continue")
	var exit_button = get_node_or_null("Button_exit")
	
	if start_button:
		if not start_button.pressed.is_connected(_on_start_pressed):
			start_button.pressed.connect(_on_start_pressed)
	
	if continue_button:
		if not continue_button.pressed.is_connected(_on_continue_pressed):
			continue_button.pressed.connect(_on_continue_pressed)
	
	if exit_button:
		if not exit_button.pressed.is_connected(_on_exit_pressed):
			exit_button.pressed.connect(_on_exit_pressed)

func _update_continue_button():
	var continue_button = get_node_or_null("Button_continue")
	if continue_button:
		var has_save = SaveManager.has_save()
		continue_button.visible = has_save
		continue_button.disabled = not has_save

func _on_start_pressed() -> void:
	if SaveManager.has_save():
		_show_new_game_confirmation()
	else:
		_start_new_game()

func _show_new_game_confirmation():
	if _confirmation_dialog == null:
		_confirmation_dialog = ConfirmationDialog.new()
		_confirmation_dialog.dialog_text = "检测到已有存档！\n\n开始新游戏将覆盖旧存档。"
		_confirmation_dialog.title = "提示"
		_confirmation_dialog.confirmed.connect(_start_new_game)
		add_child(_confirmation_dialog)
	
	_confirmation_dialog.popup_centered()

func _start_new_game():
	SaveManager.delete_save()
	GameData.initialize_new_run()
	GameManager.go_to_character_select()

func _on_cancel_new_game():
	pass

func _on_continue_pressed() -> void:
	if not SaveManager.has_save():
		push_warning("No save file found")
		return
	
	var save_data = SaveManager.load_game()
	if save_data.is_empty():
		push_error("Failed to load save")
		return
	
	SaveManager.apply_game_data(save_data)
	
	var progress = int(save_data.get("progress", SaveManager.GameProgress.IN_MAP))
	var map_id = save_data.get("map_id", "test_map")
	var map_state = save_data.get("map_state", {})
	var enemy_id = save_data.get("enemy_id", "")
	
	match progress:
		SaveManager.GameProgress.IN_MAP:
			GameManager.go_to_map(map_id, map_state)
		SaveManager.GameProgress.IN_BATTLE:
			GameManager.go_to_map(map_id, map_state)
		SaveManager.GameProgress.GAME_OVER:
			GameManager.go_to_game_over(GameData.get_battle_stats())
		_:
			GameManager.go_to_map(map_id, map_state)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_button_start_pressed() -> void:
	_on_start_pressed()

func _on_button_continue_pressed() -> void:
	_on_continue_pressed()

func _on_button_exit_pressed() -> void:
	_on_exit_pressed()
