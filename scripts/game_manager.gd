extends Node

enum GameScene {
	MAIN_MENU,
	CHARACTER_SELECT,
	CHARACTER_CREATION,
	MAP,
	BATTLE,
	REWARD,
	GAME_OVER
}

const SCENES := {
	GameScene.MAIN_MENU: "res://scenes/start.tscn",
	GameScene.CHARACTER_SELECT: "res://scenes/CharacterSelectScreen.tscn",
	GameScene.CHARACTER_CREATION: "res://scenes/CharacterCreationScreen.tscn",
	GameScene.MAP: "res://scenes/MapScreen.tscn",
	GameScene.BATTLE: "res://scenes/BattleScene.tscn",
	GameScene.REWARD: "res://scenes/RewardScreen.tscn",
	GameScene.GAME_OVER: "res://scenes/GameOverScreen.tscn"
}

var current_scene: Node = null
var previous_scene_type: int = -1
var current_scene_type: int = -1

signal scene_changed(scene_type: int)
signal battle_started()
signal battle_ended(victory: bool)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	current_scene_type = GameScene.MAIN_MENU

func change_scene(scene_type: int, data: Dictionary = {}) -> void:
	if not SCENES.has(scene_type):
		push_error("GameManager: Invalid scene type: %d" % scene_type)
		return
	
	previous_scene_type = current_scene_type
	current_scene_type = scene_type
	
	var scene_path = SCENES[scene_type]
	var scene_resource = load(scene_path)
	var new_scene = scene_resource.instantiate()
	
	if current_scene:
		current_scene.queue_free()
	
	get_tree().root.add_child(new_scene)
	current_scene = new_scene
	
	if data.size() > 0:
		_notify_scene_data(new_scene, data)
	
	scene_changed.emit(scene_type)

func _notify_scene_data(scene: Node, data: Dictionary) -> void:
	if scene.has_method("receive_data"):
		scene.receive_data(data)

func go_to_main_menu() -> void:
	change_scene(GameScene.MAIN_MENU)

func go_to_character_select() -> void:
	change_scene(GameScene.CHARACTER_SELECT)

func go_to_character_creation() -> void:
	change_scene(GameScene.CHARACTER_CREATION)

func go_to_map(map_id: String = "test_map", map_state: Dictionary = {}) -> void:
	var data: Dictionary = {"map_id": map_id}
	if not map_state.is_empty():
		data["map_state"] = map_state
	change_scene(GameScene.MAP, data)

func start_battle(enemies: Array = []) -> void:
	var data = {"enemies": enemies}
	change_scene(GameScene.BATTLE, data)
	battle_started.emit()

func end_battle(victory: bool, battle_stats: Dictionary = {}) -> void:
	battle_ended.emit(victory)
	if victory:
		go_to_reward(battle_stats)
	else:
		var stats = GameData.get_battle_stats() if GameData else {}
		stats.victory = false
		go_to_game_over(stats)

func go_to_reward(battle_stats: Dictionary = {}) -> void:
	var data: Dictionary = {"battle_stats": battle_stats}
	change_scene(GameScene.REWARD, data)

func go_to_game_over(stats: Dictionary = {}) -> void:
	var data = {"stats": stats}
	change_scene(GameScene.GAME_OVER, data)

func restart_game() -> void:
	go_to_main_menu()

func get_current_scene_type() -> int:
	return current_scene_type

func is_in_battle() -> bool:
	return current_scene_type == GameScene.BATTLE
