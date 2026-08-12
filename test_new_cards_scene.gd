## 无头测试：新卡机制（2026-08-12）
## 覆盖：热寂（支付生命+伤害）/ 生死轮转（换牌堆）/ 批命（迷惑眩晕+消耗）/ 逆流（出牌条件）/ 契约（击杀永久上限-1）/ 支付生命触发终末轮回
## 运行方式：godot --headless --path . res://test_new_cards.tscn
extends Node

var bc
var fail_count: int = 0
var _elapsed: float = 0.0

func _ready() -> void:
	_run()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 25.0:
		print("[CARD-TEST] !!! 看门狗超时强制退出")
		get_tree().quit()

func _log(msg: String) -> void:
	print("[CARD-TEST] ", msg)

func _check(cond: bool, label: String) -> void:
	if cond:
		_log("PASS: " + label)
	else:
		fail_count += 1
		_log("FAIL: " + label)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _setup(deck_entries: Array, with_relic: bool = false, dex: int = 5, hp: int = 50, enemy_count: int = 1) -> void:
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = dex
	GameData.player_max_hp = hp
	GameData.player_current_hp = hp
	if with_relic:
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
	var deck: Array = []
	for entry in deck_entries:
		deck += card_db.create_deck([{"card_id": entry[0], "count": entry[1]}])
	var enemy_db := EnemyDatabase.new()
	var enemies: Array = []
	for i in enemy_count:
		enemies.append(enemy_db.get_enemy("test_dummy"))

	bc = BattleController.new()
	bc.setup_battle(root_ui, deck, enemies)
	bc.start_battle()

## 从手牌找一张指定 id 的卡
func _find_in_hand(card_id: String):
	for c in bc.card_system.get_hand():
		if c.id == card_id:
			return c
	return null

## 确保目标卡在手牌（不在则加入），返回该卡
func _ensure_in_hand(card_id: String):
	var card = _find_in_hand(card_id)
	if card == null:
		card = CardDatabase.new().get_card(card_id)
		bc.card_system.add_to_hand(card)
	return card

func _run() -> void:
	await _test_heat_death()
	await _test_life_cycle()
	await _test_batch_ming()
	await _test_flow_reversal()
	await _test_contract()
	await _test_pay_life_relic()
	_log("=== 新卡测试结束，失败数=%d ===" % fail_count)
	get_tree().quit()

## 场景1：热寂 —— 支付5生命 + 20伤害
func _test_heat_death() -> void:
	_setup([["热寂", 20]])
	await _wait(0.6)
	_log("--- [场景1] 热寂：支付生命+伤害 ---")
	var pm = bc.player_manager
	var enemy = bc.enemy_system.get_alive_enemies()[0]
	var card = _ensure_in_hand("热寂")
	_check(card != null, "手牌中有热寂")
	await bc.play_card(card, enemy)
	_check(pm.current_hp == 45, "支付5生命后 HP=45（实际 %d）" % pm.current_hp)
	_check(enemy.current_hp == 80, "造成20伤害后敌人 HP=80（实际 %d）" % enemy.current_hp)

## 场景2：生死轮转 —— 支付20 + 交换抽牌堆与弃牌堆
func _test_life_cycle() -> void:
	_setup([["格挡", 10], ["生死轮转", 10]])
	await _wait(0.6)
	_log("--- [场景2] 生死轮转：交换牌堆 ---")
	var pm = bc.player_manager
	# 先打 2 张格挡进弃牌堆
	for i in 2:
		var g = _find_in_hand("格挡")
		if g:
			await bc.play_card(g)
	var draw_before = bc.card_system.get_draw_pile_count()
	var discard_before = bc.card_system.get_discard_pile_count()
	_log("交换前：抽牌堆=%d 弃牌堆=%d" % [draw_before, discard_before])
	var card = _ensure_in_hand("生死轮转")
	await bc.play_card(card)
	_check(pm.current_hp == 30, "支付20生命后 HP=30（实际 %d）" % pm.current_hp)
	_check(bc.card_system.get_draw_pile_count() == discard_before, "交换后抽牌堆=原弃牌堆（%d）" % bc.card_system.get_draw_pile_count())
	_check(bc.card_system.get_discard_pile_count() > discard_before, "交换后弃牌堆增加（含打出的生死轮转）")

## 场景3：批命 —— 迷惑眩晕（敌人本回合无法行动）+ 消耗
func _test_batch_ming() -> void:
	_setup([["批命", 10], ["格挡", 10]], false, 0)  # dex=0：若敌人行动则玩家掉血
	await _wait(0.6)
	_log("--- [场景3] 批命：迷惑眩晕+消耗 ---")
	var pm = bc.player_manager
	var enemy = bc.enemy_system.get_alive_enemies()[0]
	var card = _ensure_in_hand("批命")
	await bc.play_card(card, enemy)
	_check(enemy.buff_manager.has_buff("stun"), "敌人获得迷惑 buff")
	_check(bc.card_system.exhaust_pile.has(card), "批命进入消耗堆（Exhaust）")
	var hp_before = pm.current_hp
	bc.end_player_turn()
	await _wait(1.5)
	_check(pm.current_hp == hp_before, "迷惑使敌人本回合无法行动，玩家不掉血（HP=%d）" % pm.current_hp)
	_check(not enemy.buff_manager.has_buff("stun"), "回合结束迷惑层数-1（已移除）")

## 场景4：逆流 —— 出牌条件（生命<最大10%才可打出）
func _test_flow_reversal() -> void:
	_setup([["逆流", 20]], false, 5, 50)
	await _wait(0.6)
	_log("--- [场景4] 逆流：出牌条件 ---")
	var pm = bc.player_manager
	var card = _ensure_in_hand("逆流")
	_check(card != null, "手牌中有逆流")
	_check(pm.current_hp == 50, "开局 HP=50")
	# HP 50（≥10%=5）→ 不可打出
	var played_high: bool = await bc.play_card(card)
	_check(not played_high, "生命未低于10%时无法打出")
	_check(bc.card_system.hand.has(card), "未打出，逆流仍在手牌")
	# 压血到 4（<5）→ 可打出，进入选择
	pm.current_hp = 4
	pm.hp_changed.emit(pm.current_hp, pm.max_hp)
	var played_low: bool = await bc.play_card(card)
	_check(played_low, "生命低于10%时可以打出")
	_check(bc.ui_controller.is_card_select_active(), "打出后进入选择界面（选5张手牌回牌库）")

## 场景5：契约 —— 造成50伤害；击杀则生命永久上限-1（跨战斗）
func _test_contract() -> void:
	_setup([["契约", 20]])
	await _wait(0.6)
	_log("--- [场景5] 契约：击杀惩罚 ---")
	var pm = bc.player_manager
	var enemy = bc.enemy_system.get_alive_enemies()[0]
	var max_before = GameData.player_max_hp
	# 未击杀：50 伤害，敌人 100→50
	var c1 = _ensure_in_hand("契约")
	await bc.play_card(c1, enemy)
	_check(enemy.current_hp == 50, "契约造成50伤害（敌人 HP=%d）" % enemy.current_hp)
	_check(GameData.player_max_hp == max_before, "未击杀时上限不变（%d）" % GameData.player_max_hp)
	# 击杀：把敌人压到 30 再打
	enemy.current_hp = 30
	enemy.hp_changed.emit(enemy.current_hp, enemy.max_hp)
	var c2 = _ensure_in_hand("契约")
	await bc.play_card(c2, enemy)
	_check(enemy.is_dead, "敌人被契约击杀")
	_check(GameData.player_max_hp == max_before - 1, "击杀后生命上限-1（GameData=%d）" % GameData.player_max_hp)
	_check(pm.max_hp == max_before - 1, "玩家 max_hp 同步-1（%d）" % pm.max_hp)

## 场景6：支付生命触发终末轮回（归零判定）
func _test_pay_life_relic() -> void:
	_setup([["格挡", 20]], true, 5, 50)
	await _wait(0.6)
	_log("--- [场景6] 支付生命触发终末轮回 ---")
	var pm = bc.player_manager
	pm.pay_life(50)  # HP 50 → 0 → 归零触发效果①+②
	_check(pm.is_alive(), "支付归零后存活（终末轮回）")
	_check(pm.current_hp == 0, "支付归零保持 0（实际 %d）" % pm.current_hp)
	_check(pm.relic_manager.is_awakened("immortal_cycle"), "支付归零触发终末轮回效果②")
	pm.pay_life(1)   # 0 → -1 → 允许负数
	_check(pm.is_alive() and pm.current_hp == -1, "支付可扣至负数（实际 %d）" % pm.current_hp)
