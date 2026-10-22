## 启动战斗后检查帧是否继续
extends Node

var _log_path := "user://test_battle_frame_log.txt"
var _faf: FileAccess
var _frame_count := 0
var _battle_started := false

func _ready():
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 战斗帧测试 ===")
	call_deferred("_run")

func _process(delta: float) -> void:
	_frame_count += 1
	if _frame_count <= 3 or _frame_count % 100 == 0:
		_log("  frame %d (battle_started=%s)" % [_frame_count, str(_battle_started)])
	if _frame_count == 500:
		_log("=== 500帧完成 ===")
		if _faf:
			_faf.close()
		get_tree().quit()

func _log(msg: String) -> void:
	if _faf:
		_faf.store_line(msg)
	print(msg)

func _run() -> void:
	_log("初始化")
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

	_log("启动战斗")
	var enemy_db := EnemyDatabase.new()
	var enemy := enemy_db.get_enemy("腐化法师")
	GameManager.start_battle([enemy])
	_battle_started = true
	_log("start_battle返回, frame_count=%d" % _frame_count)