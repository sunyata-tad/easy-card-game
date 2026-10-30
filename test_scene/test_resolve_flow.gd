## 结算流程验证测试：节点复用、能量扣减、来源标注
extends Control

var _log_path := "user://test_resolve_flow_log.txt"
var _faf

func _ready() -> void:
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 结算流程验证测试 ===")
	call_deferred("_run_test")

func _log(msg: String) -> void:
	if _faf: _faf.store_line(msg)
	print(msg)

func _run_test() -> void:
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
	var bc = _get_bc()
	if bc == null:
		_log("FAIL: battle_controller 为空")
		_finish()
		return
	# 增加敌人血量避免一击结束
	if bc.enemy_system.enemies.size() > 0:
		bc.enemy_system.enemies[0].max_hp = 999
		bc.enemy_system.enemies[0].current_hp = 999
	# 给玩家添加 strength buff 验证来源标注
	var buff_res = load("res://scripts/effects/buff_data.gd").new({
		"id": "strength", "name": "力量", "stacks": 3, "duration": -1
	})
	bc.player_manager.buff_manager.apply_buff(buff_res)
	_log("添加strength buff: stacks=3")
	# 等待进入 TURN_PREPARE
	_log("状态: %s" % bc.state_machine.get_state_name(bc.state_machine.current_state))
	# 触发回合准备
	bc.on_turn_prepare_clicked()
	await get_tree().create_timer(1.0).timeout
	_log("状态(准备后): %s" % bc.state_machine.get_state_name(bc.state_machine.current_state))
	if not bc.state_machine.is_player_select():
		_log("FAIL: 未进入PLAYER_SELECT")
		_finish()
		return
	_log("玩家速度: %s" % str(bc._player_slot_speeds))
	_log("骰子节点数: %d" % bc.ui_controller._dice_nodes.size())
	_log("手牌数: %d" % bc.card_system.get_hand().size())
	_log("玩家力量: %d" % bc.player_manager.get_strength())
	var energy_before = bc.player_manager.energy
	_log("能量(初始): %d/%d" % [energy_before, bc.player_manager.max_energy])
	# 激活骰子0并装载有伤害的卡牌
	var hand = bc.card_system.get_hand()
	var card_to_load = null
	for c in hand:
		for eff in c.effects:
			if eff.get("effect_type") == "damage":
				card_to_load = c
				break
		if card_to_load: break
	if card_to_load == null and hand.size() > 0:
		card_to_load = hand[0]
	if card_to_load == null:
		_log("FAIL: 无可装载卡牌")
		_finish()
		return
	bc.ui_controller._active_dice_index = 0
	_log("装载卡牌: %s (cost=%d)" % [card_to_load.id, card_to_load.cost])
	var ok = bc.ui_controller.load_card_to_dice(card_to_load, null)
	_log("装载结果: %s" % str(ok))
	var card_node_before = null
	if bc.ui_controller._dice_card_nodes.size() > 0:
		card_node_before = bc.ui_controller._dice_card_nodes[0]
		_log("卡牌节点(装载后): %s valid=%s" % [str(card_node_before), str(is_instance_valid(card_node_before)) if card_node_before else "null"])
	_log("手牌数(装载后): %d" % bc.card_system.get_hand().size())
	# 检查来源标注
	var loaded = bc.ui_controller.get_loaded_plays()
	_log("已装载出牌数: %d" % loaded.size())
	if loaded.size() > 0:
		var target = loaded[0].target
		var sources = bc._get_effect_sources(card_to_load, bc.player_manager, target)
		_log("来源标注: %s" % str(sources))
	# 确认出牌→结算
	_log("确认出牌...")
	var energy_after_spend = bc.player_manager.energy
	bc.confirm_player_plays()
	# spend_energy 在 confirm_player_plays 的 await 前同步执行
	energy_after_spend = bc.player_manager.energy
	_log("能量(扣减后,结算前): %d/%d (差%d, cost=%d)" % [energy_after_spend, bc.player_manager.max_energy, energy_before - energy_after_spend, card_to_load.cost])
	await get_tree().create_timer(3.0).timeout
	# 检查结算结果
	bc = _get_bc()
	if bc == null:
		_log("FAIL: bc 为空(结算后)")
		_finish()
		return
	_log("状态(结算后): %s" % bc.state_machine.get_state_name(bc.state_machine.current_state))
	_log("能量(新一轮): %d/%d" % [bc.player_manager.energy, bc.player_manager.max_energy])
	_log("能量扣减验证: %d → %d (差%d, 卡牌cost=%d)" % [energy_before, energy_after_spend, energy_before - energy_after_spend, card_to_load.cost])
	_log("卡牌节点(结算后) valid=%s" % [str(is_instance_valid(card_node_before)) if card_node_before else "null"])
	_log("骰子卡牌节点数组大小: %d" % bc.ui_controller._dice_card_nodes.size())
	_log("牌库数: %d" % bc.card_system.draw_pile.size())
	_log("弃牌数: %d" % bc.card_system.discard_pile.size())
	_log("手牌数(结算后): %d" % bc.card_system.get_hand().size())
	if bc.enemy_system.enemies.size() > 0:
		var e = bc.enemy_system.enemies[0]
		_log("敌人血量: %d/%d" % [e.current_hp, e.max_hp])
	_finish()

func _get_bc():
	var root = GameManager.current_scene
	if root == null: return null
	return root.get("battle_controller")

func _finish() -> void:
	_log("=== 测试结束 ===")
	if _faf: _faf.close()
	get_tree().quit()