## 从主菜单进入战斗的运行时测试（旧流程+新流程）
extends Control

var _log_path := "user://test_runtime_battle_log.txt"
var _phase := 0
var _elapsed := 0.0
var _faf

func _ready() -> void:
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 运行时战斗测试 ===")
	call_deferred("_setup")

func _setup() -> void:
	var main_menu = load("res://scenes/start.tscn").instantiate()
	get_tree().root.add_child(main_menu)
	GameManager.current_scene = main_menu
	GameManager.current_scene_type = GameManager.GameScene.MAIN_MENU
	_log("主菜单加载完成")

func _log(msg: String) -> void:
	if _faf: _faf.store_line(msg)

func _process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		0:
			if _elapsed > 2.0:
				_enter_battle()
				_phase = 1
				_elapsed = 0.0
		1:
			if _elapsed > 3.0:
				_verify_battle("旧流程")
				_log("--- 切换新流程 ---")
				var root = GameManager.current_scene
				var bc = root.get("battle_controller")
				if bc:
					bc.use_new_flow = true
					bc.is_first_turn = true
					bc.state_machine.change_state(StateMachine.BattleState.DRAW_PHASE)
				_phase = 2
				_elapsed = 0.0
		2:
			if _elapsed > 3.0:
				_verify_battle("新流程")
				_phase = 3
				_elapsed = 0.0
		3:
			if _elapsed > 1.0:
				_log("=== 测试结束 ===")
				if _faf: _faf.close()
				get_tree().quit()

func _enter_battle() -> void:
	_log("初始化游戏数据...")
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
	_log("牌组创建: %d张" % GameData.player_deck.size())
	var enemy_db := EnemyDatabase.new()
	var enemy := enemy_db.get_enemy("腐化法师")
	_log("敌人: %s HP=%d" % [enemy.name, enemy.max_hp])
	GameManager.start_battle([enemy], true)
	_log("战斗启动")

func _verify_battle(label: String) -> void:
	var root = GameManager.current_scene
	_log("[%s] 场景: %s" % [label, root.name if root else "null"])
	if root == null:
		_log("FAIL: current_scene 为空")
		return
	var bc = root.get("battle_controller")
	if bc == null:
		_log("FAIL: 未找到 battle_controller")
		return
	_log("[%s] use_new_flow=%s" % [label, str(bc.use_new_flow)])
	_log("[%s] 牌库=%d 手牌=%d 弃牌=%d" % [label, bc.card_system.get_draw_pile_count(), bc.card_system.get_hand().size(), bc.card_system.get_discard_pile_count()])
	_log("[%s] HP=%d/%d 能量=%d/%d speed=%d slots=%d" % [label, bc.player_manager.current_hp, bc.player_manager.max_hp, bc.player_manager.energy, bc.player_manager.max_energy, bc.player_manager.speed, bc.player_manager.slots])
	_log("[%s] 敌人=%d" % [label, bc.enemy_system.enemies.size()])
	for card in bc.card_system.get_hand():
		_log("[%s]   %s cost=%d" % [label, card.name, card.cost])
	var state_name = bc.state_machine.get_state_name(bc.state_machine.current_state)
	_log("[%s] 状态=%s" % [label, state_name])
	if label == "新流程":
		_log("[%s] 待结算=%d 玩家速度=%s 敌人速度=%s" % [label, bc._pending_plays.size(), str(bc._player_slot_speeds), str(bc._enemy_slot_speeds)])
	_log("[%s] 验证完成" % label)