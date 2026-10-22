## 直接测试战斗场景（用_process检查状态）
extends Node

var _log_path := "user://test_battle_process_log.txt"
var _faf: FileAccess
var _phase := 0
var _elapsed := 0.0

func _ready():
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 战斗场景测试(_process) ===")
	call_deferred("_run")

func _log(msg: String) -> void:
	if _faf:
		_faf.store_line(msg)
	print(msg)

func _run() -> void:
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

	_log("Step 2: 启动战斗")
	var enemy_db := EnemyDatabase.new()
	var enemy := enemy_db.get_enemy("腐化法师")
	GameManager.start_battle([enemy])
	_log("  start_battle called, phase=0")

func _process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		0:
			if _elapsed > 1.0:
				_log("\n--- 检查战斗状态 ---")
				var scene = get_tree().get_current_scene()
				_log("  current_scene: %s" % str(scene))
				_log("  GameManager.current_scene: %s" % str(GameManager.current_scene))

				var bc_node = GameManager.current_scene
				if bc_node:
					_log("  scene name: %s" % bc_node.name)
					_log("  scene script: %s" % bc_node.get_script().resource_path)
					var bc = bc_node.get("battle_controller")
					if bc:
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
						_log("  pending_plays: %d" % bc._pending_plays.size())
						for play in bc._pending_plays:
							var src = "玩家" if play.is_player else "敌人%d" % play.enemy_index
							_log("    %s 速度=%d 卡=%s" % [src, play.speed, play.card.name])
					else:
						_log("  ERROR: battle_controller is null!")
				else:
					_log("  ERROR: current_scene is null!")

				_log("\n=== 测试完成 ===")
				if _faf:
					_faf.close()
				get_tree().quit()