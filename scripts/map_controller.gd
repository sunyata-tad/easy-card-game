class_name MapController

enum Direction {
	NORTH,
	NORTH_EAST,
	EAST,
	SOUTH_EAST,
	SOUTH,
	SOUTH_WEST,
	WEST,
	NORTH_WEST
}

const DIRECTION_NAMES := {
	Direction.NORTH: "north",
	Direction.NORTH_EAST: "north_east",
	Direction.EAST: "east",
	Direction.SOUTH_EAST: "south_east",
	Direction.SOUTH: "south",
	Direction.SOUTH_WEST: "south_west",
	Direction.WEST: "west",
	Direction.NORTH_WEST: "north_west"
}

const DIRECTION_VECTORS := {
	Direction.NORTH: Vector2i(0, -1),
	Direction.NORTH_EAST: Vector2i(1, -1),
	Direction.EAST: Vector2i(1, 0),
	Direction.SOUTH_EAST: Vector2i(1, 1),
	Direction.SOUTH: Vector2i(0, 1),
	Direction.SOUTH_WEST: Vector2i(-1, 1),
	Direction.WEST: Vector2i(-1, 0),
	Direction.NORTH_WEST: Vector2i(-1, -1)
}

var map_database: MapDatabase
var map_state: MapState
var current_map_data: Dictionary = {}

signal location_changed(location_data: Dictionary)
signal interactable_selected(interactable_data: Dictionary)
signal interactable_deselected()
signal battle_requested(enemy_id: String)
signal log_message(text: String)

var selected_interactable_id: String = ""

func _init():
	map_database = MapDatabase.new()
	map_state = MapState.new()
	map_state.log_added.connect(_on_log_added)

func _on_log_added(entry: Dictionary):
	var text = entry.get("text", "")
	log_message.emit(text)

func load_map(map_id: String) -> bool:
	current_map_data = map_database.get_map(map_id)
	if current_map_data.is_empty():
		push_error("MapController: Failed to load map: " + map_id)
		return false
	
	var start_location = current_map_data.get("start_location", "")
	if start_location.is_empty():
		push_error("MapController: No start location defined")
		return false
	
	map_state.initialize(map_id, start_location)
	
	_notify_location_changed()
	return true

func get_current_location_data() -> Dictionary:
	if map_state.current_location_id.is_empty():
		return {}
	return map_database.get_location(map_state.current_map_id, map_state.current_location_id)

func get_location_grid() -> Array:
	var grid := []
	for i in 9:
		grid.append({"id": "", "name": "", "reachable": false, "has_connection": false})
	
	var current_location = get_current_location_data()
	if current_location.is_empty():
		return grid
	
	grid[4] = {
		"id": current_location.get("id", ""),
		"name": current_location.get("name", ""),
		"reachable": true,
		"has_connection": true,
		"is_current": true
	}
	
	var connections = current_location.get("connections", {})
	
	var direction_to_grid := {
		"north": 1,
		"north_east": 2,
		"east": 5,
		"south_east": 8,
		"south": 7,
		"south_west": 6,
		"west": 3,
		"north_west": 0
	}
	
	for dir_name in connections:
		var location_id = connections[dir_name]
		var grid_idx = direction_to_grid.get(dir_name, -1)
		
		if grid_idx >= 0 and grid_idx < 9:
			var location_data = map_database.get_location(map_state.current_map_id, location_id)
			var is_enabled = map_state.is_connection_enabled(map_state.current_location_id, dir_name)
			var is_reachable = is_enabled or true
			
			grid[grid_idx] = {
				"id": location_id,
				"name": location_data.get("name", location_id),
				"reachable": is_reachable,
				"has_connection": true,
				"is_current": false
			}
	
	return grid

func can_move_to(direction: Direction) -> bool:
	var current_location = get_current_location_data()
	if current_location.is_empty():
		return false
	
	var dir_name = DIRECTION_NAMES.get(direction, "")
	var connections = current_location.get("connections", {})
	
	if not connections.has(dir_name):
		return false
	
	return true

func move_to_direction(direction: Direction) -> bool:
	if not can_move_to(direction):
		return false
	
	var current_location = get_current_location_data()
	var dir_name = DIRECTION_NAMES.get(direction, "")
	var connections = current_location.get("connections", {})
	var target_location_id = connections.get(dir_name, "")
	
	if target_location_id.is_empty():
		return false
	
	var target_data = map_database.get_location(map_state.current_map_id, target_location_id)
	var location_name = target_data.get("name", target_location_id)
	
	map_state.move_to(target_location_id)
	selected_interactable_id = ""
	interactable_deselected.emit()
	
	map_state.add_log("move", "你进入了【%s】" % location_name)
	
	_notify_location_changed()
	return true

func get_interactables() -> Array:
	var result := []
	var current_location = get_current_location_data()
	if current_location.is_empty():
		return result
	
	var interactable_ids = current_location.get("interactables", [])
	
	for interactable_id in interactable_ids:
		var interactable_data = map_database.get_interactable(map_state.current_map_id, interactable_id)
		if not interactable_data.is_empty():
			var state = map_state.get_interactable_state(map_state.current_location_id, interactable_id)
			var state_data = interactable_data.get("states", {}).get(state, {})
			
			var display_data = {
				"id": interactable_id,
				"name": interactable_data.get("name", interactable_id),
				"description": state_data.get("description", interactable_data.get("description", "")),
				"type": interactable_data.get("type", "info"),
				"interactions": state_data.get("interactions", []),
				"state": state
			}
			
			if interactable_data.has("enemy_id"):
				display_data["enemy_id"] = interactable_data.enemy_id
			if interactable_data.has("heal_amount"):
				display_data["heal_amount"] = interactable_data.heal_amount
			
			result.append(display_data)
	
	return result

func select_interactable(interactable_id: String) -> void:
	selected_interactable_id = interactable_id
	var interactables = get_interactables()
	
	for interactable in interactables:
		if interactable.id == interactable_id:
			interactable_selected.emit(interactable)
			return
	
	selected_interactable_id = ""
	interactable_deselected.emit()

func deselect_interactable() -> void:
	selected_interactable_id = ""
	interactable_deselected.emit()

func get_selected_interactable() -> Dictionary:
	if selected_interactable_id.is_empty():
		return {}
	
	var interactables = get_interactables()
	for interactable in interactables:
		if interactable.id == selected_interactable_id:
			return interactable
	return {}

func execute_interaction(interactable_id: String, action: String) -> Dictionary:
	var interactable_data = map_database.get_interactable(map_state.current_map_id, interactable_id)
	if interactable_data.is_empty():
		return {"success": false, "message": "找不到交互对象"}
	
	var current_state = map_state.get_interactable_state(map_state.current_location_id, interactable_id)
	var states = interactable_data.get("states", {})
	var state_data = states.get(current_state, {})
	var interactions = state_data.get("interactions", [])
	
	if action not in interactions:
		return {"success": false, "message": "无效的操作"}
	
	var interactable_type = interactable_data.get("type", "info")
	var interactable_name = interactable_data.get("name", interactable_id)
	
	var result = {"success": true, "message": "", "type": interactable_type}
	
	match interactable_type:
		"battle_trigger":
			if action == "战斗":
				var enemy_id = interactable_data.get("enemy_id", "")
				result.message = "你与%s展开战斗！" % interactable_name
				result.trigger_battle = true
				result.enemy_id = enemy_id
				map_state.add_log("battle", result.message)
		
		"heal":
			if action == "治愈":
				var heal_amount = interactable_data.get("heal_amount", 10)
				result.message = "你恢复了%d点生命值！" % heal_amount
				result.heal_amount = heal_amount
				map_state.add_log("heal", result.message)
			elif action == "祈祷":
				result.message = "你虔诚地祈祷，感受到了神圣的力量..."
				map_state.add_log("interact", result.message)
		
		"container":
			if action == "打开":
				var new_state = "opened"
				map_state.set_interactable_state(map_state.current_location_id, interactable_id, new_state)
				result.message = "你打开了%s。" % interactable_name
				result.state_changed = true
				result.new_state = new_state
				map_state.add_log("interact", result.message)
			elif action == "检查":
				result.message = "你仔细检查了%s。" % interactable_name
				map_state.add_log("interact", result.message)
		
		"info", "portal":
			if action == "阅读" or action == "查看" or action == "观察":
				result.message = interactable_data.get("description", "")
				map_state.add_log("interact", "你%s：%s" % [action, result.message])
			elif action == "进入":
				result.message = "传送门还没有连接到任何地方..."
				map_state.add_log("interact", result.message)
			elif action == "整理":
				result.message = "你整理了道具架，一切变得井井有条。"
				map_state.add_log("interact", result.message)
		
		"deck_view":
			if action == "查看卡组":
				result.message = "你查看了当前卡组。"
				result.show_deck = true
				map_state.add_log("interact", result.message)
			elif action == "整理":
				result.message = "你整理了卡组工作台。"
				map_state.add_log("interact", result.message)
		
		_:
			result.message = "你与%s进行了交互。" % interactable_name
			map_state.add_log("interact", result.message)
	
	return result

func _notify_location_changed() -> void:
	var location_data = get_current_location_data()
	location_changed.emit(location_data)

func get_log_history(count: int = 5) -> Array:
	return map_state.get_recent_logs(count)

func serialize_state() -> Dictionary:
	return map_state.serialize()

func deserialize_state(data: Dictionary) -> void:
	map_state.deserialize(data)
	if not map_state.current_map_id.is_empty():
		current_map_data = map_database.get_map(map_state.current_map_id)
		_notify_location_changed()
