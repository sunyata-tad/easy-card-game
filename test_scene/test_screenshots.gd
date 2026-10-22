## 启动窗口截图测试：导航各界面并停留（供外部截图）
extends Control

var _phase := 0
var _elapsed := 0.0
var _log

func _ready() -> void:
	_log = FileAccess.open("user://test_screenshots_log.txt", FileAccess.WRITE)
	_log_line("=== 截图测试开始 (0s) ===")
	call_deferred("_setup")

func _log_line(msg: String) -> void:
	if _log:
		_log.store_line(msg)
		_log.flush()

func _setup() -> void:
	var main_menu = load("res://scenes/start.tscn").instantiate()
	get_tree().root.add_child(main_menu)
	GameManager.current_scene = main_menu
	GameManager.current_scene_type = GameManager.GameScene.MAIN_MENU
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

func _process(delta: float) -> void:
	_elapsed += delta
	# 每个界面停留 8 秒，供外部截图
	match _phase:
		0:
			if _elapsed > 8.0:
				_log_line("阶段1→战斗前 (~8s)")
				_go_prebattle()
				_phase = 1
				_elapsed = 0.0
		1:
			if _elapsed > 8.0:
				_log_line("阶段2→卡组编辑 (~16s)")
				_go_deck_config()
				_phase = 2
				_elapsed = 0.0
		2:
			if _elapsed > 8.0:
				_log_line("阶段3→战斗 (~24s)")
				_go_battle()
				_phase = 3
				_elapsed = 0.0
		3:
			if _elapsed > 8.0:
				_log_line("=== 截图测试结束 (~32s) ===")
				if _log: _log.close()
				get_tree().quit()

func _go_prebattle() -> void:
	var enemy_db := EnemyDatabase.new()
	var enemy := enemy_db.get_enemy("腐化法师")
	GameManager.go_to_pre_battle_select([enemy], true)

func _go_deck_config() -> void:
	var enemy_db := EnemyDatabase.new()
	var enemy := enemy_db.get_enemy("腐化法师")
	GameManager.go_to_deck_config_from_prebattle([enemy], true)

func _go_battle() -> void:
	var enemy_db := EnemyDatabase.new()
	var enemy := enemy_db.get_enemy("腐化法师")
	var card_db := CardDatabase.new()
	GameData.player_deck = card_db.create_deck([
		{"card_id": "斩击", "count": 2},
		{"card_id": "格挡", "count": 2},
		{"card_id": "重斩", "count": 1},
		{"card_id": "铁壁", "count": 1},
		{"card_id": "攻守兼备", "count": 2},
		{"card_id": "烈斩", "count": 1}
	])
	GameManager.start_battle([enemy], true)