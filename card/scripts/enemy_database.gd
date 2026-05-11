class_name EnemyDatabase

const ENEMIES_PATH := "res://data/enemies/"
var _enemies: Dictionary = {}

func _init():
	_load_all_enemies()

func _load_all_enemies() -> void:
	var dir = DirAccess.open(ENEMIES_PATH)
	if dir == null:
		push_error("EnemyDatabase: Cannot open enemies directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path = ENEMIES_PATH + file_name
			var json_text: String = FileAccess.get_file_as_string(file_path)
			var json = JSON.new()
			if json.parse(json_text) == OK:
				var enemy_id = json.data.get("id", "")
				if enemy_id != "":
					_enemies[enemy_id] = json.data
		file_name = dir.get_next()
	dir.list_dir_end()

func get_enemy(enemy_id: String) -> EnemyData:
	if _enemies.has(enemy_id):
		return EnemyData.new(_enemies[enemy_id])
	push_warning("EnemyDatabase: Enemy not found: " + enemy_id)
	return null

func get_all_enemy_ids() -> Array:
	return _enemies.keys()
