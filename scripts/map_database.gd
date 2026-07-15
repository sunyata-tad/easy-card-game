## 地图数据库：从 JSON 文件加载所有地图配置，提供按 ID 检索地图/位置/交互物的方法。
class_name MapDatabase

const MAPS_PATH := "res://data/maps/"  ## 地图 JSON 文件目录
var _maps: Dictionary = {}  ## 所有地图的原始数据 { map_id: dict }

func _init():
	_load_all_maps()

func _load_all_maps() -> void:
	var dir = DirAccess.open(MAPS_PATH)
	if dir == null:
		push_error("MapDatabase: Cannot open maps directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path = MAPS_PATH + file_name
			var json_text: String = FileAccess.get_file_as_string(file_path)
			var json = JSON.new()
			if json.parse(json_text) == OK:
				var map_id = json.data.get("id", "")
				if map_id != "":
					_maps[map_id] = json.data
		file_name = dir.get_next()
	dir.list_dir_end()

func get_map(map_id: String) -> Dictionary:
	if _maps.has(map_id):
		return _maps[map_id]
	push_warning("MapDatabase: Map not found: " + map_id)
	return {}

func get_location(map_id: String, location_id: String) -> Dictionary:
	var map_data = get_map(map_id)
	if map_data.is_empty():
		return {}
	
	var locations = map_data.get("locations", {})
	if locations.has(location_id):
		return locations[location_id]
	return {}

func get_interactable(map_id: String, interactable_id: String) -> Dictionary:
	var map_data = get_map(map_id)
	if map_data.is_empty():
		return {}
	
	var interactables = map_data.get("interactables", {})
	if interactables.has(interactable_id):
		return interactables[interactable_id]
	return {}

func get_all_map_ids() -> Array:
	return _maps.keys()
