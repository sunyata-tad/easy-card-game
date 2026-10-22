## 调试战斗启动后场景树状态
extends Node

var _log_path := "user://test_debug_log.txt"
var _faf: FileAccess
var _frame_count := 0
var _battle_started := false

func _ready():
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 调试测试 ===")
	call_deferred("_run")

func _process(delta: float) -> void:
	_frame_count += 1
	if _frame_count <= 3:
		_log("  frame %d: in_tree=%s parent=%s" % [_frame_count, str(is_inside_tree()), str(get_parent())])
	if _frame_count == 100:
		_log("  100 frames reached!")
		_check_battle_state()
	if _frame_count == 200:
		_log("=== 完成 ===")
		_finish()

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
		{"card_id": "斩击", "count": 2}, {"card_id": "格挡", "count": 2},
		{"card_id": "重斩", "count": 1}, {"card_id": "铁壁", "count": 1},
		{"card_id": "攻守兼备", "count": 2}, {"card_id": "烈斩", "count": 1}
	])

	_log("启动战斗")
	var enemy_db := EnemyDatabase.new()
	var enemy := enemy_db.get_enemy("腐化法师")
	GameManager.start_battle([enemy])
	_battle_started = true

	_log("start_battle返回")
	_log("  in_tree=%s" % str(is_inside_tree()))
	_log("  parent=%s" % str(get_parent()))
	_log("  root children: %d" % get_tree().root.get_child_count())
	for i in get_tree().root.get_child_count():
		var c = get_tree().root.get_child(i)
		_log("    child %d: %s (type=%s)" % [i, c.name, c.get_class()])
	_log("  tree paused=%s" % str(get_tree().paused))
	_log("  current_scene=%s" % str(get_tree().get_current_scene()))

func _check_battle_state() -> void:
	_log("--- 检查战斗状态 ---")
	_log("  in_tree=%s" % str(is_inside_tree()))
	var bs = GameManager.current_scene
	if bs:
		_log("  battle scene: %s" % bs.name)
		var bc = bs.get("battle_controller")
		if bc:
			_log("  state: %s" % bc.state_machine.get_state_name(bc.state_machine.current_state))
			_log("  player hp: %d/%d" % [bc.player_manager.current_hp, bc.player_manager.max_hp])
			_log("  hand: %d" % bc.card_system.get_hand().size())

func _finish() -> void:
	if _faf:
		_faf.close()
	get_tree().quit()