## 战斗场景脚本：挂载到 BattleScene.tscn 的根 Control 节点上。
## 负责创建 BattleController、接收数据、处理战斗结束和弃牌阶段。
extends Control

var battle_controller: BattleController  ## 战斗核心控制器
var battle_stats: Dictionary = {         ## 本场战斗统计
	"damage_dealt": 0,
	"cards_played": 0
}
var is_initialized: bool = false         ## 是否已初始化（防止重复初始化）

func _ready():
	_setup_exit_button()

func _setup_exit_button():
	var exit_button = get_node_or_null("ExitButton")
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)

## 接收 GameManager.change_scene 传入的数据
func receive_data(data: Dictionary) -> void:
	if not is_initialized:
		is_initialized = true
		_initialize_battle(data)

## 初始化战斗：创建 BattleController，加载牌组和敌人
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

## 显示退出确认对话框
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

## 保存当前地图状态并返回地图
func _save_and_exit():
	var save_info = SaveManager.load_game()
	var map_id = save_info.get("map_id", "endless")
	var additional = save_info.get("additional", {})
	var is_test = additional.get("is_test_mode", false)
	var cached = SaveManager.get_cached_map_state()
	
	# 记录战斗中存活的敌人（用于回到地图后删除已死敌人的交互物）
	if battle_controller and battle_controller.enemy_system:
		var alive_ids: Array = []
		for unit in battle_controller.enemy_system.get_alive_enemies():
			if unit.data:
				alive_ids.append(unit.data.id)
		if not cached.is_empty():
			cached["alive_enemy_ids"] = alive_ids
			cached["survived_battle"] = true
			SaveManager._cached_map_state = cached
	
	# 测试模式下不保存，直接返回测试地图
	if is_test:
		GameManager.go_to_map("test", SaveManager.get_cached_map_state())
		return
	
	SaveManager.save_map_state()
	GameManager.go_to_map(map_id, SaveManager.get_cached_map_state())

## 战斗结束时：胜利 → 地图 / 失败 → 结束画面
func _on_battle_ended(victory: bool):
	battle_stats.victory = victory

	if victory:
		await get_tree().create_timer(0.5).timeout
		if GameData:
			GameData.record_battle_won()
			var cached = SaveManager.get_cached_map_state()
			var is_test = cached.get("test_mode", false)
			
			# 战斗胜利获得经验：普通层30 + 层数×5，Boss层额外+50
			var save_info = SaveManager.load_game()
			var additional = save_info.get("additional", {})
			var endless_layer = int(additional.get("endless_layer", 0))
			if endless_layer > 0:
				var exp_gain = 30 + endless_layer * 5
				if endless_layer % 10 == 0:
					exp_gain += 50  ## Boss层额外奖励
				GameData.gain_exp(exp_gain)
				print("获得 %d 经验值（第%d层）" % [exp_gain, endless_layer])
			
			# 胜利后标记楼层已清除（在返回地图前）
			if endless_layer > 0:
				if not cached.is_empty():
					cached["endless_layer_cleared"] = endless_layer
					SaveManager._cached_map_state = cached
			
			# 确定返回的地图ID
			var return_map_id = "test" if is_test else "endless"
			
			# 测试模式下不存档
			if not is_test:
				SaveManager.save_map_state()
			
			if endless_layer > 0:
				if endless_layer % 10 == 0:
					# Boss 战后：遗物三选一
					GameManager.go_to_relic_reward()
				else:
					GameManager.go_to_map(return_map_id, SaveManager.get_cached_map_state())
			else:
				GameManager.go_to_reward(battle_stats)
		else:
			_show_victory_screen()
	else:
		await get_tree().create_timer(0.5).timeout
		if GameData:
			var stats = GameData.get_battle_stats()
			stats.victory = false
			GameManager.go_to_game_over(stats)
		else:
			_show_defeat_screen()

func _on_turn_changed(is_player_turn: bool):
	if is_player_turn:
		print("玩家回合")
	else:
		print("敌人回合")

## 弃牌阶段：进入卡牌选择模式，让玩家选择要弃掉的牌
func _on_discard_phase_started(cards_to_discard: int) -> void:
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
		GameManager.go_to_map("test_map", SaveManager.get_cached_map_state())

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