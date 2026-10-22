## 模拟从主菜单进入战斗的完整流程测试
extends Node

var _log_path := "user://test_full_flow_log.txt"
var _faf: FileAccess

func _ready():
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 完整流程测试 ===")
	call_deferred("_run")

func _log(msg: String) -> void:
	if _faf:
		_faf.store_line(msg)
	print(msg)

func _run() -> void:
	# Step 1: Initialize game data
	_log("Step 1: 初始化游戏数据")
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5
	GameData.player_max_hp = 80
	GameData.player_current_hp = 80
	CardPoolManager.unlock_all_cards()
	_log("  player_deck size: %d" % GameData.player_deck.size())
	_log("  player_hp: %d/%d" % [GameData.player_current_hp, GameData.player_max_hp])

	# Step 2: Go to endless map
	_log("Step 2: 进入无尽地图")
	GameManager.go_to_endless_map()
	await get_tree().process_frame
	await get_tree().process_frame
	_log("  current_scene: %s" % str(get_tree().get_current_scene()))
	_log("  GameManager.current_scene: %s" % str(GameManager.current_scene))

	# Step 3: Check map state
	var map = GameManager.current_scene
	if map == null:
		_log("  ERROR: map is null!")
		_finish()
		return
	_log("  map script: %s" % map.get_script().resource_path)
	_log("  map name: %s" % map.name)

	# Step 4: Start a battle directly
	_log("Step 3: 直接启动战斗")
	var enemy_db := EnemyDatabase.new()
	var enemy := enemy_db.get_enemy("腐化法师")
	_log("  enemy: %s hp=%d" % [enemy.name, enemy.max_hp])

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
	_log("  deck size: %d" % deck.size())

	GameManager.start_battle([enemy])
	await get_tree().process_frame
	await get_tree().process_frame
	_log("  battle scene: %s" % str(get_tree().get_current_scene()))

	var battle_scene = get_tree().get_current_scene()
	if battle_scene == null:
		_log("  ERROR: battle scene is null!")
		_finish()
		return

	_log("  battle script: %s" % battle_scene.get_script().resource_path)

	# Check battle controller
	var bc = battle_scene.get("battle_controller")
	if bc == null:
		_log("  ERROR: battle_controller is null!")
		_finish()
		return

	_log("  use_new_flow: %s" % str(bc.use_new_flow))
	_log("  state: %s" % bc.state_machine.get_state_name(bc.state_machine.current_state))
	_log("  player hp: %d/%d" % [bc.player_manager.current_hp, bc.player_manager.max_hp])
	_log("  player energy: %d/%d" % [bc.player_manager.energy, bc.player_manager.max_energy])
	_log("  player speed: %d slots: %d" % [bc.player_manager.speed, bc.player_manager.slots])
	_log("  hand size: %d" % bc.card_system.get_hand().size())
	_log("  enemies: %d" % bc.enemy_system.enemies.size())

	for enemy_unit in bc.enemy_system.enemies:
		_log("  enemy: %s hp=%d/%d energy=%d speed=%d slots=%d" % [
			enemy_unit.name, enemy_unit.current_hp, enemy_unit.max_hp,
			enemy_unit.energy, enemy_unit.speed, enemy_unit.slots
		])

	_log("\n=== 测试完成 ===")
	_finish()

func _finish() -> void:
	if _faf:
		_faf.close()
	get_tree().quit()