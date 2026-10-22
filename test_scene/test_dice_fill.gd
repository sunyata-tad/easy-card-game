## 测试骰子装载/卸载流程
extends Control

func _ready() -> void:
	call_deferred("_setup")

func _setup() -> void:
	var main_menu = load("res://scenes/start.tscn").instantiate()
	get_tree().root.add_child(main_menu)
	GameManager.current_scene = main_menu
	GameManager.current_scene_type = GameManager.GameScene.MAIN_MENU
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5
	GameData.player_max_hp = 80
	GameData.player_current_hp = 80
	CardPoolManager.unlock_all_cards()
	GameData.player_deck = CardDatabase.new().create_deck([
		{"card_id": "斩击", "count": 2}, {"card_id": "格挡", "count": 2},
		{"card_id": "重斩", "count": 1}, {"card_id": "铁壁", "count": 1},
		{"card_id": "攻守兼备", "count": 2}, {"card_id": "烈斩", "count": 1}
	])
	var enemy = EnemyDatabase.new().get_enemy("腐化法师")
	GameManager.start_battle([enemy], true)
	await get_tree().create_timer(2.5).timeout
	_run_test()

func _run_test() -> void:
	var f := FileAccess.open("user://test_dice_fill.txt", FileAccess.WRITE)
	var root = GameManager.current_scene
	f.store_line("场景: %s" % (root.name if root else "null"))
	var bc = root.get("battle_controller")
	if bc == null:
		f.store_line("FAIL: battle_controller 为空")
		f.close()
		get_tree().quit()
		return
	var ui = bc.ui_controller
	f.store_line("状态: %s" % bc.state_machine.get_state_name(bc.state_machine.current_state))
	f.store_line("骰子节点数: %d" % ui._dice_nodes.size())
	f.store_line("骰子速度: %s" % str(ui._dice_speeds))
	f.store_line("骰子卡牌(初始): %s" % str(ui._dice_cards))
	f.store_line("手牌数: %d" % bc.card_system.get_hand().size())
	# 模拟激活骰子0
	ui._active_dice_index = 0
	ui._apply_dice_style(ui._dice_nodes[0], true)
	f.store_line("激活骰子0: active_index=%d has_active=%s" % [ui._active_dice_index, str(ui.has_active_dice())])
	# 模拟装载第一张手牌
	var hand = bc.card_system.get_hand()
	if hand.size() > 0:
		var card = hand[0]
		var ok = ui.load_card_to_dice(card, null)
		f.store_line("装载卡牌: ok=%s card=%s" % [str(ok), card.id])
		f.store_line("骰子卡牌(装载后): %s" % str(ui._dice_cards))
		f.store_line("手牌数(装载后): %d" % bc.card_system.get_hand().size())
	# 模拟右键卸载
	ui._unload_dice_card(0, false, -1)
	f.store_line("骰子卡牌(卸载后): %s" % str(ui._dice_cards))
	f.store_line("手牌数(卸载后): %d" % bc.card_system.get_hand().size())
	# 验证 get_loaded_plays
	if hand.size() > 0:
		ui._active_dice_index = 0
		ui.load_card_to_dice(bc.card_system.get_hand()[0], null)
		f.store_line("get_loaded_plays: %d" % ui.get_loaded_plays().size())
	f.close()
	get_tree().quit()