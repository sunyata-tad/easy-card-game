## 场景版无头测试：通过启动场景的方式运行（autoload 单例已注册），
## 驱动 20 张蓄势 + 测试假人的战斗，验证弃牌阶段逻辑。
## 运行方式：godot --headless --path . res://test_discard.tscn
extends Node

var bc                        ## BattleController 实例
var discard_started_count: int = 0   ## discard_phase_started 触发次数
var last_discard_excess: int = -1    ## 最近一次弃牌需要弃的张数
var _elapsed: float = 0.0

func _ready() -> void:
	_run()

func _process(delta: float) -> void:
	_elapsed += delta
	## 看门狗：25 秒后强制退出，防止挂起时无限等待
	if _elapsed > 25.0:
		print("[DISCARD-TEST] !!! 看门狗超时强制退出（可能死锁/死循环）")
		get_tree().quit()

func _log(msg: String) -> void:
	print("[DISCARD-TEST] ", msg)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _state() -> String:
	return bc.state_machine.get_state_name(bc.state_machine.current_state)

func _setup() -> Control:
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5

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
	var deck: Array = card_db.create_deck([{"card_id": "蓄势", "count": 20}])
	var enemy_db := EnemyDatabase.new()
	var enemy = enemy_db.get_enemy("test_dummy")

	bc = BattleController.new()
	bc.discard_phase_started.connect(func(n: int):
		discard_started_count += 1
		last_discard_excess = n
		_log(">>> 弃牌阶段触发 #%d：需要弃 %d 张，手牌=%d，上限=%d" % [discard_started_count, n, bc.card_system.hand.size(), bc.card_system.max_hand_size])
	)
	bc.setup_battle(root_ui, deck, [enemy])
	bc.start_battle()
	return root_ui

## 打出蓄势直到手牌超过上限
func _play_until_over() -> int:
	var guard := 0
	while bc.state_machine.is_player_turn() and bc.card_system.hand.size() <= bc.card_system.max_hand_size and guard < 30:
		var hand: Array = bc.card_system.get_hand()
		var target_card = null
		for c in hand:
			if c.id == "蓄势":
				target_card = c
				break
		if target_card == null:
			break
		await bc.play_card(target_card)
		guard += 1
	return guard

func _run() -> void:
	await _test_discard_normal()
	await _test_no_discard()
	_log("=== 全部测试结束 ===")
	get_tree().quit()

## 场景一：普通弃牌流程（手牌>上限 → 弃牌 → 下回合抽 1 到 11）
func _test_discard_normal() -> void:
	_setup()
	await _wait(0.6)
	_log("--- [场景1] 普通弃牌：开局 手牌=%d 抽牌堆=%d 状态=%s ---" % [bc.card_system.hand.size(), bc.card_system.get_draw_pile_count(), _state()])

	var played := await _play_until_over()
	_log("打了 %d 张蓄势后：手牌=%d 抽牌堆=%d 弃牌堆=%d" % [played, bc.card_system.hand.size(), bc.card_system.get_draw_pile_count(), bc.card_system.get_discard_pile_count()])

	bc.end_player_turn()
	await _wait(0.9)
	_log("结束回合：弃牌触发=%d 手牌=%d 状态=%s" % [discard_started_count, bc.card_system.hand.size(), _state()])

	# 验证：弃牌本身是否真的生效（直接验证 discard_specific_card）
	var hand_before: Array = bc.card_system.get_hand()
	var hand_before_count := hand_before.size()
	if hand_before_count > 0:
		var removed: bool = bc.card_system.discard_specific_card(hand_before[0])
		_log("直接调用 discard_specific_card：成功=%s 手牌 %d -> %d（若手牌不变则弃牌逻辑有问题）" % [removed, hand_before_count, bc.card_system.hand.size()])
		## 把它加回去，保持现场
		bc.card_system.add_to_hand(hand_before[0])

	# 确认弃牌（弃掉需要弃的数量）
	if last_discard_excess > 0:
		var to_discard: Array = bc.card_system.get_hand().slice(0, last_discard_excess)
		_log("确认弃牌 %d 张（弃牌前手牌=%d）..." % [to_discard.size(), bc.card_system.hand.size()])
		await bc.confirm_discard_cards(to_discard)
		await _wait(0.3)
		## 预期：确认后手牌先降到上限（10），随后下一回合抽 1 张回到 11（正常游戏王规则，抽到上限+1）
		_log("确认弃牌后：手牌=%d（若为 10 是刚弃完；11 是下回合已抽 1 张=正常）抽牌堆=%d 弃牌堆=%d 状态=%s 弃牌触发累计=%d" % [bc.card_system.hand.size(), bc.card_system.get_draw_pile_count(), bc.card_system.get_discard_pile_count(), _state(), discard_started_count])

	# 进入第 2 回合，观察是否再次触发弃牌
	await _wait(1.2)
	_log("--- [场景1] 第 2 回合开始：手牌=%d 弃牌触发累计=%d ---" % [bc.card_system.hand.size(), discard_started_count])

	# 第 2 回合直接结束（不操作）：若手牌>10（=11），弃牌会再次触发——这是正常规则（手牌>上限时弃牌）
	bc.end_player_turn()
	await _wait(0.9)
	_log("第 2 回合结束：弃牌触发累计=%d（手牌>上限时每回合都会触发=符合规则）" % discard_started_count)

## 场景二：no_discard 能力（本场不弃牌）——验证 check_discard 规则门
func _test_no_discard() -> void:
	_log("--- [场景2] no_discard 能力（本场不弃牌）---")
	_setup()
	await _wait(0.6)

	# 模拟能力卡打出后施加 no_discard buff（duration=-1 = 本场战斗永久）
	bc.player_manager.buff_manager.apply_buff(BuffData.new({"id": "no_discard", "name": "不弃", "buff_type": "buff", "duration": -1, "stacks": 1}))
	_log("已施加 no_discard buff：has_buff=%s" % bc.player_manager.buff_manager.has_buff("no_discard"))

	# 打出蓄势把手牌堆过上限（>10）
	var played := await _play_until_over()
	_log("打了 %d 张蓄势后：手牌=%d（>10，但应被 no_discard 阻止弃牌）" % [played, bc.card_system.hand.size()])

	# 回合末：弃牌规则门应阻止弃牌阶段
	var before := discard_started_count
	bc.end_player_turn()
	await _wait(0.9)
	var fired := discard_started_count - before
	_log("结束回合：新增弃牌触发=%d（应为 0）状态=%s 手牌=%d" % [fired, _state(), bc.card_system.hand.size()])
	if fired == 0:
		_log("✅ 通过：no_discard 阻止了回合末弃牌阶段")
	else:
		_log("!! 失败：no_discard 未能阻止回合末弃牌")

	# 直接验证卡牌弃牌效果也被阻止
	var res: Dictionary = bc.effect_resolver._resolve_discard_random(1, bc.player_manager)
	_log("调用 discard_random 弃牌效果：blocked=%s（应为 true）" % res.get("blocked", false))
	if res.get("blocked", false):
		_log("✅ 通过：no_discard 阻止了卡牌弃牌效果")
	else:
		_log("!! 失败：no_discard 未能阻止卡牌弃牌效果")
