## 直接测试战斗场景（跳过地图）
extends Node

var _log_path := "user://test_battle_only_log.txt"
var _faf: FileAccess

func _ready():
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 战斗场景直接测试 ===")
	call_deferred("_run")

func _log(msg: String) -> void:
	if _faf:
		_faf.store_line(msg)
	print(msg)

func _run() -> void:
	# Initialize game data
	_log("Step 1: 初始化")
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5
	GameData.player_max_hp = 80
	GameData.player_current_hp = 80
	CardPoolManager.unlock_all_cards()

	var card_db := CardDatabase.new()
	var deck = card_db.create_deck([
		{"card_id": "斩击", "count": 2},
		{"card_id": "格挡", "count": 2},
		{"card_id": "重斩", "count": 1},
		{"card_id": "铁壁", "count": 1},
		{"card_id": "攻守兼备", "count": 2},
		{"card_id": "烈斩", "count": 1}
	])
	GameData.player_deck = deck
	_log("  deck: %d" % deck.size())

	# Start battle directly
	_log("Step 2: 启动战斗")
	var enemy_db := EnemyDatabase.new()
	var enemy := enemy_db.get_enemy("腐化法师")
	_log("  enemy: %s hp=%d" % [enemy.name, enemy.max_hp])

	GameManager.start_battle([enemy])
	_log("  start_battle called")
	await get_tree().process_frame
	_log("  frame 1 done")
	await get_tree().process_frame
	_log("  frame 2 done")

	var battle_scene = get_tree().get_current_scene()
	_log("  scene: %s" % str(battle_scene))

	if battle_scene == null:
		_log("  ERROR: scene is null!")
		_finish()
		return

	var bc = battle_scene.get("battle_controller")
	if bc == null:
		_log("  ERROR: bc is null!")
		_finish()
		return

	_log("  use_new_flow: %s" % str(bc.use_new_flow))
	_log("  state: %s" % bc.state_machine.get_state_name(bc.state_machine.current_state))
	_log("  player hp: %d/%d" % [bc.player_manager.current_hp, bc.player_manager.max_hp])
	_log("  player energy: %d/%d" % [bc.player_manager.energy, bc.player_manager.max_energy])
	_log("  player speed: %d slots: %d" % [bc.player_manager.speed, bc.player_manager.slots])
	_log("  hand: %d" % bc.card_system.get_hand().size())
	_log("  enemies: %d" % bc.enemy_system.enemies.size())

	for e in bc.enemy_system.enemies:
		_log("  enemy: %s hp=%d/%d energy=%d speed=%d slots=%d" % [
			e.name, e.current_hp, e.max_hp, e.energy, e.speed, e.slots
		])

	_log("\n=== 测试完成 ===")
	_finish()

func _finish() -> void:
	if _faf:
		_faf.close()
	get_tree().quit()