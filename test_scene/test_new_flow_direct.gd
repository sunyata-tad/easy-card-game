## 新流程直接测试：验证同时出牌+速度排序结算的完整流程
extends Control

var _log_path := "user://test_new_flow_log.txt"
var _faf
var _phase := 0
var _elapsed := 0.0
var _bc: BattleController = null

func _ready() -> void:
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 新流程直接测试 ===")
	call_deferred("_setup")

func _log(msg: String) -> void:
	if _faf: _faf.store_line(msg)
	print(msg)

func _setup() -> void:
	# 初始化游戏数据
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5
	GameData.player_max_hp = 80
	GameData.player_current_hp = 80
	CardPoolManager.unlock_all_cards()
	var card_db := CardDatabase.new()
	GameData.player_deck = card_db.create_deck([
		{"card_id": "斩击", "count": 2},
		{"card_id": "格挡", "count": 2},
		{"card_id": "重斩", "count": 1},
		{"card_id": "铁壁", "count": 1},
		{"card_id": "攻守兼备", "count": 2},
		{"card_id": "烈斩", "count": 1}
	])
	_log("牌组: %d张" % GameData.player_deck.size())
	
	# 创建战斗控制器
	_bc = BattleController.new()
	_bc.use_new_flow = true
	_bc.battle_ended.connect(_on_battle_ended)
	
	var enemy_db := EnemyDatabase.new()
	var enemy := enemy_db.get_enemy("腐化法师")
	_log("敌人: %s HP=%d" % [enemy.name, enemy.max_hp])
	
	_bc.setup_battle(self, GameData.player_deck, [enemy])
	_bc.start_battle()
	_log("战斗启动")
	_log("初始状态: %s" % _bc.state_machine.get_state_name(_bc.state_machine.current_state))
	_log("玩家 HP=%d/%d 能量=%d/%d speed=%d slots=%d" % [
		_bc.player_manager.current_hp, _bc.player_manager.max_hp,
		_bc.player_manager.energy, _bc.player_manager.max_energy,
		_bc.player_manager.speed, _bc.player_manager.slots
	])
	_log("手牌: %d张" % _bc.card_system.get_hand().size())
	for card in _bc.card_system.get_hand():
		_log("  %s cost=%d target=%s" % [card.name, card.cost, card.target_type])

func _process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		0:  # 等待进入PLAYER_SELECT
			if _bc and _bc.state_machine.is_player_select():
				_log("\n--- 进入PLAYER_SELECT ---")
				_log("状态: %s" % _bc.state_machine.get_state_name(_bc.state_machine.current_state))
				_log("玩家速度: %s" % str(_bc._player_slot_speeds))
				_log("敌人速度: %s" % str(_bc._enemy_slot_speeds))
				_log("待结算: %d" % _bc._pending_plays.size())
				for play in _bc._pending_plays:
					var src = "玩家" if play.is_player else "敌人%d" % play.enemy_index
					_log("  %s 速度=%d 卡=%s" % [src, play.speed, play.card.name])
				# 队列一些卡牌
				_queue_test_cards()
				_phase = 1
				_elapsed = 0.0
		1:  # 等待一帧后确认
			if _elapsed > 0.5:
				_log("\n--- 确认出牌 ---")
				_log("队列: %d张" % _bc._player_queued_plays.size())
				for p in _bc._player_queued_plays:
					_log("  %s cost=%d" % [p.card.name, p.card.cost])
				_bc.confirm_player_plays(_bc._player_queued_plays)
				_bc._player_queued_plays.clear()
				_phase = 2
				_elapsed = 0.0
		2:  # 验证结算结果
			if _elapsed > 1.0:
				_log("\n--- 结算后 ---")
				_log("状态: %s" % _bc.state_machine.get_state_name(_bc.state_machine.current_state))
				_log("玩家 HP=%d/%d block=%d 能量=%d" % [
					_bc.player_manager.current_hp, _bc.player_manager.max_hp,
					_bc.player_manager.block, _bc.player_manager.energy
				])
				for enemy in _bc.enemy_system.enemies:
					_log("敌人 HP=%d/%d block=%d" % [enemy.current_hp, enemy.max_hp, enemy.block])
				_log("手牌: %d 牌库: %d" % [
					_bc.card_system.get_hand().size(),
					_bc.card_system.get_draw_pile_count()
				])
				_log("\n=== 测试完成 ===")
				if _faf: _faf.close()
				get_tree().quit()

func _queue_test_cards() -> void:
	var hand = _bc.card_system.get_hand()
	_log("\n--- 队列测试卡牌 ---")
	# 找一张攻击牌和一张防御牌
	var attack_card = null
	var defend_card = null
	for card in hand:
		for effect in card.effects:
			if effect.get("effect_type") == "damage" and attack_card == null:
				attack_card = card
			if effect.get("effect_type") == "block" and defend_card == null:
				defend_card = card
	# 队列攻击牌
	if attack_card:
		var target = null
		for e in _bc.enemy_system.get_alive_enemies():
			target = e
			break
		_bc._queue_player_card(attack_card, target)
		_log("队列攻击: %s (cost=%d)" % [attack_card.name, attack_card.cost])
	# 队列防御牌
	if defend_card:
		_bc._queue_player_card(defend_card, _bc.player_manager)
		_log("队列防御: %s (cost=%d)" % [defend_card.name, defend_card.cost])

func _on_battle_ended(victory: bool) -> void:
	_log("战斗结束: %s" % ("胜利" if victory else "失败"))