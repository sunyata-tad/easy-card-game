## 主菜单场景脚本：挂载到 start.tscn 的根 Control 节点上。
## 处理"新游戏"、"继续游戏"、"退出"按钮，检测存档状态并引导玩家进入游戏或恢复进度。
extends Control

var _confirmation_dialog: ConfirmationDialog = null  ## 新游戏确认对话框（覆盖存档提示）

func _ready():
	_setup_buttons()
	_update_continue_button()
	_play_entry_animation()

## 连接按钮信号，动态创建测试按钮
func _setup_buttons():
	var start_button = get_node_or_null("MenuCenter/MenuBox/Button_start")
	var continue_button = get_node_or_null("MenuCenter/MenuBox/Button_continue")
	var exit_button = get_node_or_null("MenuCenter/MenuBox/Button_exit")

	if start_button:
		if UIStyle:
			UIStyle.style_primary_button(start_button)
			UIStyle.attach_button_anim(start_button)
		if not start_button.pressed.is_connected(_on_start_pressed):
			start_button.pressed.connect(_on_start_pressed)

	if continue_button:
		if UIStyle:
			UIStyle.attach_button_anim(continue_button)
		if not continue_button.pressed.is_connected(_on_continue_pressed):
			continue_button.pressed.connect(_on_continue_pressed)

	if exit_button:
		if UIStyle:
			UIStyle.attach_button_anim(exit_button)
		if not exit_button.pressed.is_connected(_on_exit_pressed):
			exit_button.pressed.connect(_on_exit_pressed)

	# 动态创建测试按钮（场景中可能不存在）
	var test_button = get_node_or_null("Button_test")
	if test_button == null:
		test_button = Button.new()
		test_button.name = "Button_test"
		test_button.text = "测试"
		test_button.position = Vector2(10, 10)
		test_button.custom_minimum_size = Vector2(80, 30)
		add_child(test_button)
	if not test_button.pressed.is_connected(_on_test_pressed):
		test_button.pressed.connect(_on_test_pressed)

## 根据是否有存档更新"继续"按钮的可见性
func _update_continue_button():
	var continue_button = get_node_or_null("MenuCenter/MenuBox/Button_continue")
	if continue_button:
		var has_save = SaveManager.has_save()
		continue_button.visible = has_save
		continue_button.disabled = not has_save

## 主菜单入场：可见按钮从下方错峰滑入并淡入（4.7 Offset Transform）
func _play_entry_animation() -> void:
	var btns: Array = []
	var sb = get_node_or_null("MenuCenter/MenuBox/Button_start")
	var cb = get_node_or_null("MenuCenter/MenuBox/Button_continue")
	var eb = get_node_or_null("MenuCenter/MenuBox/Button_exit")
	if sb:
		btns.append(sb)
	if cb and cb.visible:
		btns.append(cb)
	if eb:
		btns.append(eb)
	if UIStyle and btns.size() > 0:
		UIStyle.stagger_in(btns)

## 新游戏：有存档时先弹确认框，无存档直接开始
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
		_confirmation_dialog.ok_button_text = "确认"
		_confirmation_dialog.cancel_button_text = "取消"
		_confirmation_dialog.confirmed.connect(_start_new_game)
		add_child(_confirmation_dialog)

	_confirmation_dialog.popup_centered()

## 开始新游戏：清除存档，初始化数据，跳转到无尽地图
func _start_new_game():
	SaveManager.delete_save()
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5
	CardPoolManager.initialize_with_starter_cards()
	GameManager.go_to_endless_map()

func _on_cancel_new_game():
	pass

## 继续游戏：读取存档，根据进度跳转到对应场景
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
	var map_id = save_data.get("map_id", "endless")
	var map_state = save_data.get("map_state", {})
	var enemy_id = save_data.get("enemy_id", "")

	match progress:
		SaveManager.GameProgress.IN_MAP:
			if map_id == "endless":
				GameManager.go_to_endless_map(map_state)
			else:
				GameManager.go_to_map(map_id, map_state)
		SaveManager.GameProgress.IN_BATTLE:
			if map_id == "endless":
				GameManager.go_to_endless_map(map_state)
			else:
				GameManager.go_to_map(map_id, map_state)
		SaveManager.GameProgress.GAME_OVER:
			GameManager.go_to_game_over(GameData.get_battle_stats())
		_:
			if map_id == "endless":
				GameManager.go_to_endless_map(map_state)
			else:
				GameManager.go_to_map(map_id, map_state)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_test_pressed() -> void:
	GameManager.go_to_test_map()

func _on_button_start_pressed() -> void:
	_on_start_pressed()

func _on_button_continue_pressed() -> void:
	_on_continue_pressed()

func _on_button_exit_pressed() -> void:
	_on_exit_pressed()
