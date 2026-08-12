## 无头测试：遗物"终末轮回"（immortal_cycle）
## 覆盖：效果①归零不死亡 / 效果②首次跌破0触发 / 负数生命不死 / 抽空牌组死亡 / 每回合抽满≥10 / 自己回合内伤害转移全体敌方 / 效果③战后50%
## 运行方式：godot --headless --path . res://test_relic.tscn
extends Node

var bc
var fail_count: int = 0
var _elapsed: float = 0.0

func _ready() -> void:
	_run()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 25.0:
		print("[RELIC-TEST] !!! 看门狗超时强制退出")
		get_tree().quit()

func _log(msg: String) -> void:
	print("[RELIC-TEST] ", msg)

func _check(cond: bool, label: String) -> void:
	if cond:
		_log("PASS: " + label)
	else:
		fail_count += 1
		_log("FAIL: " + label)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _setup(enemy_count: int = 1) -> void:
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5
	GameData.grant_relic("immortal_cycle")

	var root_ui := Control.new()
	root_ui.name = "BattleRoot"
	var bg := Control.new()
	bg.name = "Background"
	root_ui.add_child(bg)
	var hand_area := Control.new()
	hand_area.name = "HandArea"
	bg.add_child(hand_area)
	var enemy_area := Control.new()
	enemy_area.name = "EnemyArea"
	bg.add_child(enemy_area)
	var player_area := Control.new()
	player_area.name = "PlayerArea"
	bg.add_child(player_area)
	var end_turn_btn := Button.new()
	end_turn_btn.name = "EndTurnButton"
	root_ui.add_child(end_turn_btn)
	var deck_info := Control.new()
	deck_info.name = "DeckInfo"
	root_ui.add_child(deck_info)
	add_child(root_ui)

	var card_db := CardDatabase.new()
	var deck: Array = card_db.create_deck([{"card_id": "格挡", "count": 20}])
	var enemy_db := EnemyDatabase.new()
	var enemies: Array = []
	for i in enemy_count:
		enemies.append(enemy_db.get_enemy("test_dummy"))

	bc = BattleController.new()
	bc.setup_battle(root_ui, deck, enemies)
	bc.start_battle()

## 触发效果②：生命归零（≤0，原死亡条件）→ 存活 + 觉醒；随后到负数（效果③）
func _awaken() -> void:
	var pm = bc.player_manager
	pm.take_damage(pm.current_hp)          # 归零 → 触发效果②（觉醒）
	bc.state_machine.current_state = StateMachine.BattleState.ENEMY_TURN
	pm.take_damage(1)                       # 负数（效果③）
	bc.state_machine.current_state = StateMachine.BattleState.PLAYER_TURN

func _run() -> void:
	await _test_lock_awaken_negative_death()
	await _test_draw_to_ten()
	await _test_redirect_all_enemies()
	await _test_victory_half_hp()
	_log("=== 遗物测试结束，失败数=%d ===" % fail_count)
	get_tree().quit()

## 场景1：效果①归零不死亡 + 效果②首次跌破0触发 + 负数生命不死 + 抽空牌组死亡
func _test_lock_awaken_negative_death() -> void:
	_setup()
	await _wait(0.6)
	_log("--- [场景1] 效果①归零 / 效果②触发 / 负数生命 / 抽空死亡 ---")
	var pm = bc.player_manager

	_check(pm.current_hp == 50, "开局 HP=50（实际 %d）" % pm.current_hp)
	_check(pm.relic_manager.has_relic("immortal_cycle"), "已持有终末轮回遗物")

	# 效果①+②：生命归零（≤0，原死亡条件）→ 不死亡 + 触发效果②；生命可为负数
	pm.take_damage(50)
	_check(pm.is_alive(), "归零后存活")
	_check(pm.current_hp == 0, "归零保持 0 点（实际 %d）" % pm.current_hp)
	_check(pm.relic_manager.is_awakened("immortal_cycle"), "第一次归零（≤0）触发效果②")

	# 效果③：已触发② → 生命可为负数（非玩家回合验证，避免伤害转移）
	bc.state_machine.current_state = StateMachine.BattleState.ENEMY_TURN
	pm.take_damage(1)
	_check(pm.is_alive(), "触发②后存活")
	_check(pm.current_hp == -1, "生命可为负数（实际 %d）" % pm.current_hp)
	pm.take_damage(9)
	_check(pm.current_hp == -10, "负数生命继续累积（实际 %d）" % pm.current_hp)
	bc.state_machine.current_state = StateMachine.BattleState.PLAYER_TURN

	# 效果②：失败条件改为卡组为空时抽卡 → 死亡
	bc.card_system.draw_pile.clear()
	bc.card_system.discard_pile.clear()
	bc.card_system.draw_cards(1)
	_check(pm.is_dead, "抽空牌组触发死亡")

## 场景2：觉醒后每回合抽满 10 张手牌
func _test_draw_to_ten() -> void:
	_setup()
	await _wait(0.6)
	_log("--- [场景2] 每回合抽满10 ---")
	var pm = bc.player_manager
	_awaken()   # 效果②触发（hp=-1）
	_check(bc.card_system.hand.size() == 5, "觉醒时手牌 5 张")
	bc.end_player_turn()
	await _wait(1.5)
	_check(bc.card_system.hand.size() == 10, "下回合抽满到 10（实际 %d）" % bc.card_system.hand.size())
	_check(pm.is_alive(), "抽满后玩家存活")

## 场景3：自己回合内受到的伤害转移给全体敌方（每个敌人各承担完整伤害）
func _test_redirect_all_enemies() -> void:
	_setup(2)
	await _wait(0.6)
	_log("--- [场景3] 自己回合内伤害转移全体 ---")
	var pm = bc.player_manager
	_awaken()   # 效果②触发（hp=-1）
	var alive = bc.enemy_system.get_alive_enemies()
	var e1 = alive[0]
	var e2 = alive[1]
	var e1_hp = e1.current_hp
	var e2_hp = e2.current_hp

	# 当前是 PLAYER_TURN，玩家受 7 点伤害 → 全体敌方各承担 7，玩家不掉血
	pm.take_damage(7)
	_check(pm.current_hp == -1, "玩家不掉血（实际 %d）" % pm.current_hp)
	_check(e1.current_hp == e1_hp - 7, "敌人1受到完整伤害 %d" % (e1_hp - e1.current_hp))
	_check(e2.current_hp == e2_hp - 7, "敌人2受到完整伤害 %d" % (e2_hp - e2.current_hp))

## 场景4：战斗结束生命强制为最大值 50%
func _test_victory_half_hp() -> void:
	_setup(2)
	await _wait(0.6)
	_log("--- [场景4] 战斗结束强制50% ---")
	var pm = bc.player_manager
	_awaken()   # 效果②触发（hp=-1）
	# 两个敌人各剩 1 血，自己回合内转移 1 点伤害 → 同时死亡 → 胜利
	for e in bc.enemy_system.get_alive_enemies():
		e.current_hp = 1
		e.block = 0
	pm.take_damage(1)
	await _wait(0.6)
	var expected = int(round(pm.max_hp * 0.5))
	_check(pm.current_hp == expected, "战斗结束后生命为 50%%（%d / 预期 %d）" % [pm.current_hp, expected])
	_check(GameData.player_current_hp == expected, "GameData 已同步 50%%（%d）" % GameData.player_current_hp)
