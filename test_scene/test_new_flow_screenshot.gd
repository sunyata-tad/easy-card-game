## 新流程UI截图测试：从主菜单进入战斗，截图验证新流程UI视觉效果
extends Control

var _log_path := "user://test_new_flow_screenshot_log.txt"
var _phase := 0
var _elapsed := 0.0
var _faf

func _ready() -> void:
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 新流程UI截图测试 ===")
	call_deferred("_setup")

func _log(msg: String) -> void:
	if _faf: _faf.store_line(msg)

func _setup() -> void:
	var main_menu = load("res://scenes/start.tscn").instantiate()
	get_tree().root.add_child(main_menu)
	GameManager.current_scene = main_menu
	GameManager.current_scene_type = GameManager.GameScene.MAIN_MENU
	_log("主菜单加载完成")

func _process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		0:
			if _elapsed > 1.5:
				_enter_battle()
				_phase = 1
				_elapsed = 0.0
		1:
			# 等待进入PLAYER_SELECT状态
			if _elapsed > 2.5:
				var root = GameManager.current_scene
				var bc = root.get("battle_controller") if root else null
				if bc and bc.state_machine.is_player_select():
					_log("进入PLAYER_SELECT状态")
					_log("玩家速度: %s" % str(bc._player_slot_speeds))
				_log("敌人速度: %s" % str(bc._enemy_slot_speeds))
				_take_screenshot("new_flow_player_select")
					_phase = 2
					_elapsed = 0.0
				else:
					var state_name = "未知"
					if bc:
						state_name = bc.state_machine.get_state_name(bc.state_machine.current_state)
					_log("等待中... 当前状态: %s" % state_name)
					if _elapsed > 5.0:
						_log("超时：未进入PLAYER_SELECT")
						_take_screenshot("new_flow_timeout")
						_phase = 3
						_elapsed = 0.0
		2:
			if _elapsed > 2.0:
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

func _take_screenshot(name: String) -> void:
	var img = get_viewport().get_texture().get_image()
	var path = "user://%s.png" % name
	img.save_png(path)
	_log("截图保存: %s (尺寸: %dx%d)" % [path, img.get_width(), img.get_height()])