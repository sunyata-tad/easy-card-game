## 无头测试：Boss 战后遗物奖励流程（端到端）
## 覆盖：is_boss 存档 → 测试战斗 victory → go_to_relic_reward
## 运行方式：godot --headless --path . res://test_boss_relic_flow.tscn
extends Node

var fail_count: int = 0
var _elapsed: float = 0.0

func _ready() -> void:
	_run()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 15.0:
		_log("!!! 看门狗超时强制退出")
		get_tree().quit()

func _log(msg: String) -> void:
	print("[BOSS-FLOW-TEST] ", msg)

func _check(cond: bool, label: String) -> void:
	if cond:
		_log("PASS: " + label)
	else:
		fail_count += 1
		_log("FAIL: " + label)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _run() -> void:
	_log("=== Boss遗物流程测试开始 ===")
	# 关键：测试场景本身是"当前场景"，胜利后的 change_scene 会 queue_free 它导致挂起。
	# 先把 current_scene 置空，使 change_scene 只新增目标场景而不释放测试节点。
	GameManager.current_scene = null

	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5
	var card_db := CardDatabase.new()
	GameData.player_deck = card_db.create_deck([
		{"card_id": "斩击", "count": 5},
		{"card_id": "格挡", "count": 5}
	])
	GameData.grant_relic("immortal_cycle")

	# 模拟测试地图 Boss 层开战前的存档（is_boss=true, layer=3, test_mode=true）
	SaveManager._cached_map_state = {"test_mode": true, "current_layer": 3}
	var ok: bool = SaveManager.save_before_battle("石甲卫兵", "test", 3, true, true)
	_check(ok, "save_before_battle(is_boss=true) 成功")

	var enemy_db := EnemyDatabase.new()
	var boss = enemy_db.get_enemy("石甲卫兵")
	_check(boss != null, "获取 Boss 敌人 石甲卫兵")

	# 进入战斗场景（test_mode）
	var battle = load("res://scenes/BattleScene.tscn").instantiate()
	add_child(battle)
	battle.receive_data({"enemies": [boss], "test_mode": true})
	await _wait(0.4)

	var bc = battle.battle_controller
	_check(bc != null, "战斗控制器已创建")
	if bc == null:
		_finish()
		return
	_check(bc.enemy_system.get_alive_enemies().size() >= 1, "存在存活敌人")

	# 遗物按钮弹窗：持有遗物列表 + 悬浮详情
	_check(bc.player_manager.relic_manager.has_relic("immortal_cycle"), "战斗内持有 终末轮回 遗物")
	battle._show_relic_popup()
	await _wait(0.2)
	var popup = battle.get_node_or_null("RelicPopup")
	_check(popup != null, "遗物弹窗已创建")

	# 秒杀敌人 → 胜利
	battle._on_kill_enemies_pressed()
	await _wait(1.5)

	_check(GameManager.current_scene_type == GameManager.GameScene.RELIC_REWARD,
		"Boss 胜利后触发遗物奖励 (current_scene_type==RELIC_REWARD, 实际:%d)" % GameManager.current_scene_type)

	_finish()

func _finish() -> void:
	_log("=== Boss遗物流程测试结束 ===")
	if fail_count == 0:
		_log(">>> 全部通过")
	else:
		_log(">>> 失败 %d 项" % fail_count)
	get_tree().quit()
