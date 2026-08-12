## 无头测试：弃牌攻击机制（2026-08-12 重构后）
## 覆盖：弃牌攻击基本流程 / 一回合一次 / 回合末无自动攻击 / 蓄力已删除
## 运行方式：godot --headless --path . res://test_discard_attack.tscn
extends Node

var bc                        ## BattleController 实例
var fail_count: int = 0       ## 失败断言计数
var _elapsed: float = 0.0

func _ready() -> void:
	_run()

func _process(delta: float) -> void:
	_elapsed += delta
	## 看门狗：25 秒后强制退出，防止挂起
	if _elapsed > 25.0:
		print("[ATK-TEST] !!! 看门狗超时强制退出")
		get_tree().quit()

func _log(msg: String) -> void:
	print("[ATK-TEST] ", msg)

func _check(cond: bool, label: String) -> void:
	if cond:
		_log("PASS: " + label)
	else:
		fail_count += 1
		_log("FAIL: " + label)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

## 搭建最小战斗场景（复用 test_discard 的搭建方式）
func _setup() -> void:
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

	# 只用"格挡"卡组，保证弃牌攻击是唯一伤害来源
	var card_db := CardDatabase.new()
	var deck: Array = card_db.create_deck([{"card_id": "格挡", "count": 20}])
	var enemy_db := EnemyDatabase.new()
	var enemy = enemy_db.get_enemy("test_dummy")

	bc = BattleController.new()
	bc.setup_battle(root_ui, deck, [enemy])
	bc.start_battle()

func _run() -> void:
	await _test_basic_discard_attack()
	await _test_once_per_turn()
	await _test_no_auto_attack()
	_test_store_damage_removed()
	_log("=== 弃牌攻击测试结束，失败数=%d ===" % fail_count)
	get_tree().quit()

## 场景1：基本弃牌攻击流程（弃1牌 → 立即结算 → 选目标 → get_strength() 伤害）
func _test_basic_discard_attack() -> void:
	_setup()
	await _wait(0.6)
	_log("--- [场景1] 基本弃牌攻击 ---")
	var enemy = bc.enemy_system.get_alive_enemies()[0]
	var hp_before = enemy.current_hp

	# 1. 请求弃牌攻击 → 进入卡牌选择模式
	bc._on_discard_attack_requested()
	_check(bc.ui_controller.is_card_select_active(), "请求后进入卡牌选择模式")
	_check(bc.discard_attack_available, "本回合攻击可用")

	# 2. 选择一张牌并确认（走完整 UI 确认路径）→ 弃牌立即结算 → 进入目标选择
	var hand: Array = bc.card_system.get_hand()
	var hand_before = hand.size()
	var discard_before = bc.card_system.get_discard_pile_count()
	bc.ui_controller._card_selected_cards = [hand[0]]
	bc.ui_controller._on_card_select_confirm()
	_check(not bc.ui_controller.is_card_select_active(), "确认后退出卡牌选择模式")
	_check(bc.card_system.get_hand().size() == hand_before - 1, "弃牌后手牌 -1")
	_check(bc.card_system.get_discard_pile_count() == discard_before + 1, "弃牌堆 +1")
	_check(bc.ui_controller.is_selecting_target, "弃牌后进入目标选择")
	_check(not bc.discard_attack_available, "弃牌代价已支付，本回合名额消耗")

	# 3. 选目标 → 攻击 = get_strength() = 5
	bc._on_discard_attack_target_selected(enemy)
	var dealt = hp_before - enemy.current_hp
	_check(dealt == 5, "造成 5 点伤害（get_strength()），实际 %d" % dealt)

## 场景2：一回合一次；下回合恢复
func _test_once_per_turn() -> void:
	_setup()
	await _wait(0.6)
	_log("--- [场景2] 一回合一次 ---")
	var enemy = bc.enemy_system.get_alive_enemies()[0]

	bc._on_discard_attack_requested()
	var hand: Array = bc.card_system.get_hand()
	bc.ui_controller._card_selected_cards = [hand[0]]
	bc.ui_controller._on_card_select_confirm()
	bc._on_discard_attack_target_selected(enemy)
	var hand_size_after = bc.card_system.get_hand().size()

	# 第二次请求应被拒绝（available=false）
	bc._on_discard_attack_requested()
	_check(not bc.ui_controller.is_card_select_active(), "第二次请求被拒绝（不再进入选择模式）")
	_check(bc.card_system.get_hand().size() == hand_size_after, "第二次未再弃牌")

	# 结束回合 → 下回合应恢复可用
	bc.end_player_turn()
	await _wait(1.2)
	_check(bc.discard_attack_available, "下回合弃牌攻击恢复可用")

## 场景3：回合末不再自动攻击（敌人不掉血）
func _test_no_auto_attack() -> void:
	_setup()
	await _wait(0.6)
	_log("--- [场景3] 回合末无自动攻击 ---")
	var enemy = bc.enemy_system.get_alive_enemies()[0]
	var hp_before = enemy.current_hp
	bc.end_player_turn()
	await _wait(1.2)
	_check(enemy.current_hp == hp_before, "回合末敌人不掉血（无自动攻击）")

## 场景4：蓄力机制已删除
func _test_store_damage_removed() -> void:
	_log("--- [场景4] 蓄力机制已删除 ---")
	_check(not bc.effect_resolver.has_handler("store_damage"), "store_damage 效果处理器已移除")
	_check(bc.player_manager.get("pending_stored_damage") == null, "PlayerManager 无 pending_stored_damage 字段")
