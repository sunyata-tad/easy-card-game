## 新流程完整测试：使用实际战斗场景验证同时出牌流程
## 测试内容：状态转换、选牌队列、速度排序、能量消耗、伤害结算
extends Control

var _log_path := "user://test_new_flow_full_log.txt"
var _faf
var _phase := 0
var _elapsed := 0.0
var _bc: BattleController = null
var _test_results: Dictionary = {}
var _hand_container: Control = null
var _enemy_container: Control = null

func _ready() -> void:
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 新流程完整测试 ===")
	_log("时间: %s" % Time.get_datetime_string_from_system())
	call_deferred("_setup")

func _log(msg: String) -> void:
	if _faf: _faf.store_line(msg)

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
	
	# 创建最小UI容器（避免null引用错误）
	_hand_container = HBoxContainer.new()
	_hand_container.name = "HandContainer"
	add_child(_hand_container)
	_enemy_container = HBoxContainer.new()
	_enemy_container.name = "EnemyContainer"
	add_child(_enemy_container)
	
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

func _process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		0:  # 等待进入PLAYER_SELECT
			if _bc and _bc.state_machine.is_player_select():
				_log("\n=== T1: PLAYER_SELECT ===")
				_log("玩家速度: %s" % str(_bc._player_slot_speeds))
				_log("敌人速度: %s" % str(_bc._enemy_slot_speeds))
				_log("待结算(敌人): %d" % _bc._pending_plays.size())
				for play in _bc._pending_plays:
					var src = "玩家" if play.is_player else "敌人%d" % play.enemy_index
					_log("  %s 速度=%d 卡=%s" % [src, play.speed, play.card.name])
				
				# 测试1: 队列卡牌
				var hand = _bc.card_system.get_hand()
				var queued_count = 0
				for card in hand:
					if queued_count >= 2:
						break
					if card.cost <= _bc.player_manager.energy:
						var target = null
						if card.target_type == "single_enemy":
							for e in _bc.enemy_system.get_alive_enemies():
								target = e
								break
						elif card.target_type == "self":
							target = _bc.player_manager
						_bc._queue_player_card(card, target)
						queued_count += 1
						_log("队列: %s (cost=%d)" % [card.name, card.cost])
				
				_test_results["queued_count"] = queued_count
				_test_results["t1_state"] = _bc.state_machine.get_state_name(_bc.state_machine.current_state)
				_phase = 1
				_elapsed = 0.0
		1:  # 确认出牌
			if _elapsed > 0.3:
				_log("\n=== T1: 确认出牌 ===")
				var pre_hp_enemy = _bc.enemy_system.enemies[0].current_hp if _bc.enemy_system.enemies.size() > 0 else 0
				var pre_hp_player = _bc.player_manager.current_hp
				_log("结算前: 玩家HP=%d 敌人HP=%d" % [pre_hp_player, pre_hp_enemy])
				
				_bc.confirm_player_plays(_bc._player_queued_plays)
				_bc._player_queued_plays.clear()
				
				_log("结算后状态: %s" % _bc.state_machine.get_state_name(_bc.state_machine.current_state))
				var post_hp_enemy = _bc.enemy_system.enemies[0].current_hp if _bc.enemy_system.enemies.size() > 0 else 0
				var post_hp_player = _bc.player_manager.current_hp
				_log("结算后: 玩家HP=%d 敌人HP=%d" % [post_hp_player, post_hp_enemy])
				_log("玩家能量=%d/%d" % [_bc.player_manager.energy, _bc.player_manager.max_energy])
				
				_test_results["t1_player_dmg"] = pre_hp_player - post_hp_player
				_test_results["t1_enemy_dmg"] = pre_hp_enemy - post_hp_enemy
				_test_results["t1_post_state"] = _bc.state_machine.get_state_name(_bc.state_machine.current_state)
				_phase = 2
				_elapsed = 0.0
		2:  # 等待第二回合PLAYER_SELECT
			if _bc and _bc.state_machine.is_player_select() and _elapsed > 0.5:
				_log("\n=== T2: 第二回合 ===")
				_log("状态: %s" % _bc.state_machine.get_state_name(_bc.state_machine.current_state))
				_log("玩家 HP=%d/%d 能量=%d/%d" % [
					_bc.player_manager.current_hp, _bc.player_manager.max_hp,
					_bc.player_manager.energy, _bc.player_manager.max_energy
				])
				_log("手牌: %d 牌库: %d" % [
					_bc.card_system.get_hand().size(),
					_bc.card_system.get_draw_pile_count()
				])
				_log("玩家速度: %s" % str(_bc._player_slot_speeds))
				_log("敌人速度: %s" % str(_bc._enemy_slot_speeds))
				_log("敌人意图: %d" % _bc._pending_plays.size())
				for play in _bc._pending_plays:
					var src = "玩家" if play.is_player else "敌人%d" % play.enemy_index
					_log("  %s 速度=%d 卡=%s" % [src, play.speed, play.card.name])
				
				_test_results["t2_state"] = _bc.state_machine.get_state_name(_bc.state_machine.current_state)
				_test_results["t2_energy"] = _bc.player_manager.energy
				_test_results["t2_hand_size"] = _bc.card_system.get_hand().size()
				
				# 不出牌直接确认（测试空出牌）
				_log("\nT2: 空出牌确认")
				_bc.confirm_player_plays([])
				_phase = 3
				_elapsed = 0.0
		3:  # 验证并输出结果
			if _elapsed > 1.0:
				_log("\n=== 测试结果汇总 ===")
				_log("T1状态: %s" % _test_results.get("t1_state", "N/A"))
				_log("T1队列: %d张" % _test_results.get("queued_count", 0))
				_log("T1玩家受伤: %d" % _test_results.get("t1_player_dmg", 0))
				_log("T1敌人受伤: %d" % _test_results.get("t1_enemy_dmg", 0))
				_log("T1结算后状态: %s" % _test_results.get("t1_post_state", "N/A"))
				_log("T2状态: %s" % _test_results.get("t2_state", "N/A"))
				_log("T2能量: %d" % _test_results.get("t2_energy", 0))
				_log("T2手牌: %d" % _test_results.get("t2_hand_size", 0))
				
				# 判定
				var pass_count = 0
				var total = 5
				if _test_results.get("t1_state") == "PLAYER_SELECT": pass_count += 1
				if _test_results.get("queued_count", 0) > 0: pass_count += 1
				if _test_results.get("t1_enemy_dmg", 0) > 0: pass_count += 1
				if _test_results.get("t2_state") == "PLAYER_SELECT": pass_count += 1
				if _test_results.get("t2_energy", 0) > 0: pass_count += 1
				
				_log("\n通过: %d/%d" % [pass_count, total])
				if pass_count == total:
					_log(">>> 全部通过 <<<")
				else:
					_log(">>> 部分失败 <<<")
				
				_log("\n=== 测试结束 ===")
				if _faf: _faf.close()
				get_tree().quit()

func _on_battle_ended(victory: bool) -> void:
	_log("战斗结束: %s" % ("胜利" if victory else "失败"))