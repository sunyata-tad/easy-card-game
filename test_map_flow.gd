## 无头测试：测试地图（test）完整接线
## 覆盖：层级结构(0营地/1普通/2精英/3Boss/4试用) / is_boss_layer / is_boss存档 / 清Boss层 / 遗物三选一界面
## 运行方式：godot --headless --path . res://test_map_flow.tscn
extends Node

var map_screen: Control
var map_controller
var fail_count: int = 0
var _elapsed: float = 0.0

func _ready() -> void:
	_run()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 25.0:
		_log("!!! 看门狗超时强制退出")
		get_tree().quit()

func _log(msg: String) -> void:
	print("[MAP-FLOW-TEST] ", msg)

func _check(cond: bool, label: String) -> void:
	if cond:
		_log("PASS: " + label)
	else:
		fail_count += 1
		_log("FAIL: " + label)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _run() -> void:
	_log("=== 测试地图接线测试开始 ===")
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5

	# 加载地图场景并进入测试模式
	map_screen = load("res://scenes/MapScreen.tscn").instantiate()
	add_child(map_screen)
	map_screen.receive_data({"map_id": "test", "test_mode": true})
	map_controller = map_screen.map_controller
	await _wait(0.1)

	_check(map_controller.test_mode == true, "测试模式已启用")
	_check(map_controller.max_layer_reached == 5, "测试地图共5层 (max_layer_reached=5)")
	_check(map_controller.get_current_layer() == 0, "出生在营地 (layer_0)")
	for i in range(0, 5):
		_check(map_controller._endless_nodes.has("layer_%d" % i), "存在 layer_%d" % i)

	# Boss 层标记
	var l3: Dictionary = map_controller._endless_nodes.get("layer_3", {})
	_check(l3.get("boss", false) == true, "layer_3 标记为 Boss 层")
	_check(map_controller.is_boss_layer(3) == true, "is_boss_layer(3) == true")
	_check(map_controller.is_boss_layer(1) == false, "is_boss_layer(1) == false")
	_check(map_controller.is_boss_layer(0) == false, "is_boss_layer(0) == false")

	# 移动: layer_0 -> layer_1
	_check(map_controller.move_to_direction(map_controller.Direction.NORTH), "可前进到 layer_1")
	_check(map_controller.get_current_layer() == 1, "到达 layer_1")
	var l1_int: Array = map_controller._endless_nodes["layer_1"].get("interactables", [])
	_check(l1_int.size() == 1, "layer_1 有1个战斗交互物")
	var l1_enemy: String = map_controller._endless_interactables[l1_int[0]].get("enemy_id", "")
	_check(l1_enemy == "石甲卫兵", "layer_1 敌人为石甲卫兵 (实际:%s)" % l1_enemy)

	# layer_1 -> layer_2 (精英)
	_check(map_controller.move_to_direction(map_controller.Direction.NORTH), "可前进到 layer_2")
	var l2_int: Array = map_controller._endless_nodes["layer_2"].get("interactables", [])
	_check(l2_int.size() == 2, "layer_2 有2个精英战斗交互物")

	# layer_2 -> layer_3 (Boss)
	_check(map_controller.move_to_direction(map_controller.Direction.NORTH), "可前进到 layer_3")
	var l3_int: Array = map_controller._endless_nodes["layer_3"].get("interactables", [])
	_check(l3_int.size() == 2, "layer_3 有2个Boss战斗交互物")

	# 保存 is_boss 标志
	var ok: bool = SaveManager.save_before_battle("石甲卫兵", "test", 3, true, true)
	var additional: Dictionary = SaveManager.load_game().get("additional", {})
	_check(ok == true, "save_before_battle 保存成功")
	_check(additional.get("endless_layer", 0) == 3, "存档 endless_layer==3")
	_check(additional.get("is_test_mode", false) == true, "存档 is_test_mode==true")
	_check(additional.get("is_boss", false) == true, "存档 is_boss==true")

	# 清除 Boss 层
	map_controller.mark_layer_cleared(3)
	var l3_int2: Array = map_controller._endless_nodes["layer_3"].get("interactables", [])
	_check(l3_int2.size() == 0, "清除后 layer_3 无战斗交互物")
	_check(map_controller._endless_nodes["layer_3"].get("enemy_ids", []).is_empty(), "清除后 layer_3 enemy_ids 为空")

	# layer_3 -> layer_4 (试用层)
	_check(map_controller.move_to_direction(map_controller.Direction.NORTH), "可前进到 layer_4")
	var l4_int: Array = map_controller._endless_nodes["layer_4"].get("interactables", [])
	_check(l4_int.size() == 1, "layer_4 有1个战斗交互物")
	var l4_enemy: String = map_controller._endless_interactables[l4_int[0]].get("enemy_id", "")
	_check(l4_enemy == "暗影刺客", "layer_4 敌人为暗影刺客 (实际:%s)" % l4_enemy)

	# 遗物三选一界面
	var reward_screen = load("res://scenes/RelicRewardScreen.tscn").instantiate()
	add_child(reward_screen)
	await _wait(0.1)
	var choices: Array = reward_screen.get_choices()
	_check(choices.size() == 3, "三选一始终有3个选项 (实际:%d)" % choices.size())
	var all_valid: bool = true
	var crown_count: int = 0
	var real_count: int = 0
	for c in choices:
		if c == null or c.id == "":
			all_valid = false
		elif c.id == "placeholder_crown":
			crown_count += 1
		else:
			real_count += 1
	_check(all_valid, "所有遗物选项有效 (id 非空)")
	_check(real_count == 1 and crown_count == 2, "1个正常遗物+2个头环补齐 (实际:%d正常+%d头环)" % [real_count, crown_count])

	# 地图查看遗物按钮：弹出可滚动面板
	GameData.grant_relic("immortal_cycle")
	map_screen._on_relic_pressed()
	await _wait(0.1)
	var map_popup = map_screen.get_node_or_null("RelicPopup")
	_check(map_popup != null, "地图可弹出遗物查看弹窗")
	if map_popup:
		var mpanel = map_popup.get_child(0)
		_check(mpanel != null and mpanel.get_node_or_null("Margin/VBox/TitleLabel") != null, "地图遗物面板已填充")
		map_popup.queue_free()

	_log("=== 测试地图接线测试结束 ===")
	if fail_count == 0:
		_log(">>> 全部通过 (%d 项)" % _total_checks())
	else:
		_log(">>> 失败 %d 项" % fail_count)
	get_tree().quit()

func _total_checks() -> int:
	return 26
