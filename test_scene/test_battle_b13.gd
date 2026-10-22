## 测试B1-B3改动：牌堆简化+能量系统+速度槽位
extends Control

var _log_path := "user://test_battle_b13_log.txt"
var _phase := 0
var _elapsed := 0.0
var _faf

func _ready() -> void:
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== B1-B3 战斗测试开始 ===")
	call_deferred("_setup")

func _setup() -> void:
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5
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
	var enemy_db := EnemyDatabase.new()
	var enemies := [enemy_db.get_enemy("腐化法师")]
	GameManager.start_battle(enemies, true)
	_phase = 1

func _log(msg: String) -> void:
	if _faf:
		_faf.store_line(msg)

func _process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		1:
			if _elapsed > 2.0:
				_verify_battle()
				_phase = 2
				_elapsed = 0.0
		2:
			if _elapsed > 1.0:
				_log("=== 测试结束 ===")
				if _faf:
					_faf.close()
				get_tree().quit()

func _verify_battle() -> void:
	var root = GameManager.current_scene
	_log("当前场景: " + (root.name if root else "null"))
	if root == null:
		_log("FAIL: current_scene 为空")
		return
	var bc = root.get_node_or_null("BattleController")
	if bc == null:
		_log("FAIL: 未找到 BattleController")
		return
	_log("BattleController 找到")
	var cs = bc.card_system
	if cs == null:
		_log("FAIL: card_system 为空")
		return
	_log("牌库数量: " + str(cs.get_draw_pile_count()))
	_log("手牌数量: " + str(cs.get_hand().size()))
	_log("弃牌堆数量: " + str(cs.get_discard_pile_count()))
	var pm = bc.player_manager
	if pm == null:
		_log("FAIL: player_manager 为空")
		return
	_log("玩家HP: " + str(pm.current_hp) + "/" + str(pm.max_hp))
	_log("玩家能量: " + str(pm.energy) + "/" + str(pm.max_energy))
	_log("玩家速度属性: " + str(pm.speed))
	_log("玩家槽位: " + str(pm.slots))
	for card in cs.get_hand():
		_log("  手牌: " + card.id + " cost=" + str(card.cost) + " desc=" + card.description)
	_log("验证完成")