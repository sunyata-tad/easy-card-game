## 启动窗口截图测试：快速导航各界面（供外部截图）
extends Control

var _phase := 0
var _elapsed := 0.0
var _log
var _logged_pre := false
var _logged_battle := false

func _ready() -> void:
	_log = FileAccess.open("user://test_screenshots_log.txt", FileAccess.WRITE)
	_log_line("=== 截图测试开始 ===")
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
	GameData.player_deck = CardDatabase.new().create_deck([
		{"card_id": "斩击", "count": 2}, {"card_id": "格挡", "count": 2},
		{"card_id": "重斩", "count": 1}, {"card_id": "铁壁", "count": 1},
		{"card_id": "攻守兼备", "count": 2}, {"card_id": "烈斩", "count": 1}
	])

func _process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		0:
			if _elapsed > 2.5:
				_log_line("阶段1→战斗前")
				_go_prebattle()
				_phase = 1
				_elapsed = 0.0
		1:
			if _elapsed > 1.5 and not _logged_pre:
				_logged_pre = true
				var root = GameManager.current_scene
				_log_line("战斗前场景: %s" % (root.name if root else "null"))
			if _elapsed > 2.5:
				_log_line("阶段2→战斗")
				_go_battle()
				_phase = 2
				_elapsed = 0.0
		2:
			if _elapsed > 1.5 and not _logged_battle:
				_logged_battle = true
				var root = GameManager.current_scene
				_log_line("战斗场景: %s" % (root.name if root else "null"))
			if _elapsed > 2.5:
				_log_line("=== 截图测试结束 ===")
				if _log: _log.close()
				get_tree().quit()

func _go_prebattle() -> void:
	var enemy = EnemyDatabase.new().get_enemy("腐化法师")
	GameManager.go_to_pre_battle_select([enemy], true)

func _go_battle() -> void:
	var enemy = EnemyDatabase.new().get_enemy("腐化法师")
	GameManager.start_battle([enemy], true)