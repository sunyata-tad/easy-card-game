## 测试B4-B5新流程：同时出牌+速度结算+敌人AI
extends Node

func _log(f: FileAccess, msg: String) -> void:
	if f:
		f.store_line(msg)

func _ready() -> void:
	var f := FileAccess.open("user://test_b45_flow_log.txt", FileAccess.WRITE)
	_log(f, "=== B4-B5 新流程测试 ===")
	
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5
	CardPoolManager.unlock_all_cards()
	
	var db := CardDatabase.new()
	var deck := db.create_deck([
		{"card_id": "斩击", "count": 2},
		{"card_id": "格挡", "count": 2},
		{"card_id": "重斩", "count": 1},
		{"card_id": "铁壁", "count": 1},
		{"card_id": "攻守兼备", "count": 2},
		{"card_id": "烈斩", "count": 1}
	])
	
	var bc := BattleController.new()
	var enemy_db := EnemyDatabase.new()
	var enemy := enemy_db.get_enemy("腐化法师")
	bc.setup_battle(Control.new(), deck, [enemy])
	bc.use_new_flow = true
	
	_log(f, "use_new_flow=%s" % str(bc.use_new_flow))
	_log(f, "玩家 slots=%d speed=%d energy=%d/%d" % [bc.player_manager.slots, bc.player_manager.speed, bc.player_manager.energy, bc.player_manager.max_energy])
	_log(f, "敌人数量=%d" % bc.enemy_system.enemies.size())
	
	var en = bc.enemy_system.enemies[0]
	_log(f, "敌人: %s HP=%d/%d slots=%d speed=%d energy=%d/%d" % [en.data.name, en.current_hp, en.max_hp, en.slots, en.speed, en.energy, en.max_energy])
	
	bc.card_system.draw_cards(5)
	_log(f, "玩家手牌: %d" % bc.card_system.get_hand().size())
	for card in bc.card_system.get_hand():
		_log(f, "  %s cost=%d desc=%s" % [card.name, card.cost, card.description])
	
	bc._roll_all_speeds()
	_log(f, "玩家槽位速度: %s" % str(bc._player_slot_speeds))
	_log(f, "敌人槽位速度: %s" % str(bc._enemy_slot_speeds))
	
	var enemy_deck := bc._get_enemy_deck(en)
	_log(f, "敌人卡组: %d张" % enemy_deck.size())
	
	var enemy_cs := CardSystem.new()
	enemy_cs.initialize_deck(enemy_deck)
	enemy_cs.draw_cards(5)
	_log(f, "敌人手牌: %d" % enemy_cs.get_hand().size())
	
	var EnemyAIClass = load("res://scripts/battle/enemy_ai.gd")
	var plays = EnemyAIClass.decide_plays(en, enemy_cs, bc.player_manager, bc.enemy_system.enemies)
	_log(f, "敌人AI决定出牌: %d张" % plays.size())
	for p in plays:
		_log(f, "  槽位%d: %s -> %s" % [p.slot_index, p.card.name, "玩家" if p.target == bc.player_manager else "自己"])
	
	_log(f, "=== 测试完成 ===")
	f.close()
	get_tree().quit()