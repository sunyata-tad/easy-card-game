## 敌人数据库：从 JSON 文件加载所有敌人配置，提供按 ID 检索敌人的方法。
## 结构与 CardDatabase 对称。
class_name EnemyDatabase

const ENEMIES_PATH := "res://data/enemies/"  ## 敌人 JSON 文件目录
var _enemies: Dictionary = {}  ## 所有敌人的原始数据 { enemy_id: dict }

func _init():
	_load_all_enemies()

## 遍历 enemies 目录，加载所有 .json 文件
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

## 根据 id 获取敌人数据
func get_enemy(enemy_id: String) -> EnemyData:
	if _enemies.has(enemy_id):
		return EnemyData.new(_enemies[enemy_id])
	push_warning("EnemyDatabase: Enemy not found: " + enemy_id)
	return null

func get_all_enemy_ids() -> Array:
	return _enemies.keys()
