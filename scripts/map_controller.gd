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

var endless_mode: bool = false
var current_layer: int = 0
var max_layer_reached: int = 0
var _endless_nodes: Dictionary = {}
var _endless_interactables: Dictionary = {}

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
	if endless_mode:
		return _init_endless()
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

func _init_endless() -> bool:
	endless_mode = true
	current_layer = 0
	max_layer_reached = 0
	_endless_nodes.clear()
	_endless_interactables.clear()
	
	_endless_nodes["layer_0"] = {
		"id": "layer_0",
		"name": "营地",
		"description": "旅程的起点。从这里向北出发，迎接无尽的挑战。",
		"connections": {"north": "layer_1"},
		"interactables": ["endless_camp_rest", "endless_camp_table"]
	}
	_endless_interactables["endless_camp_table"] = {
		"id": "endless_camp_table",
		"name": "卡组桌",
		"description": "在这里可以编辑你的卡组，自由添加已解锁的卡牌。",
		"type": "deck_view",
		"states": {
			"default": {"interactions": ["查看卡组"], "description": "在这里可以编辑你的卡组。"}
		}
	}
	_endless_interactables["endless_camp_rest"] = {
		"id": "endless_camp_rest",
		"name": "休息营地",
		"description": "在这里可以回复生命值，准备迎接新的挑战。",
		"type": "heal",
		"heal_amount": 0,
		"states": {
			"default": {"interactions": ["休息"], "description": "在这里休息可以恢复生命值。"},
			"used": {"interactions": [], "description": "你刚刚休息过了。"}
		}
	}
	
	map_state.initialize("endless", "layer_0")
	map_state.current_map_id = "endless"
	_notify_location_changed()
	return true

func _generate_layer_node(layer: int) -> void:
	var layer_id = "layer_" + str(layer)
	if _endless_nodes.has(layer_id):
		return
	
	var south_id = "layer_" + str(layer - 1)
	
	var is_chest = randi() % 100 < 30
	
	if is_chest:
		var interactable_id = "endless_chest_" + str(layer)
		map_state.interactable_states["%s:%s" % [layer_id, interactable_id]] = "closed"
		_endless_nodes[layer_id] = {
			"id": layer_id,
			"name": "第%d层" % layer,
			"description": "无尽的试炼之塔，第%d层。前方发现了一个宝箱。" % layer,
			"connections": {"south": south_id},
			"interactables": [interactable_id]
		}
		if layer < max_layer_reached:
			_endless_nodes[layer_id]["connections"]["north"] = "layer_" + str(layer + 1)
		var already_cleared = layer < max_layer_reached
		_endless_interactables[interactable_id] = {
			"id": interactable_id,
			"name": "宝箱",
			"description": "一个华丽的宝箱！",
			"type": "container",
			"layer": layer,
			"states": {
				"closed": {"interactions": ["打开"] if not already_cleared else [], "description": "一个华丽的宝箱。"},
				"opened": {"interactions": [], "description": "已经打开过的宝箱。"}
			}
		}
		if already_cleared:
			_endless_interactables[interactable_id]["states"]["opened"] = {"interactions": [], "description": "已经打开过的宝箱。"}
			_endless_interactables[interactable_id]["states"]["closed"] = {"interactions": [], "description": "已经打开过的宝箱。"}
	else:
		var enemy_db = EnemyDatabase.new()
		var all_enemies = enemy_db.get_all_enemy_ids()
		var enemy_id = all_enemies[0] if all_enemies.size() > 0 else "test_dummy"
		if all_enemies.size() > 1:
			enemy_id = all_enemies[randi() % all_enemies.size()]
		var interactable_id = "endless_battle_" + str(layer)
		map_state.interactable_states["%s:%s" % [layer_id, interactable_id]] = "default"
		_endless_nodes[layer_id] = {
			"id": layer_id,
			"name": "第%d层" % layer,
			"description": "无尽的试炼之塔，第%d层。前方还有更强大的敌人等待着你。" % layer,
			"connections": {"south": south_id},
			"interactables": [interactable_id]
		}
		if layer < max_layer_reached:
			_endless_nodes[layer_id]["connections"]["north"] = "layer_" + str(layer + 1)
		var already_cleared = layer < max_layer_reached
		_endless_interactables[interactable_id] = {
			"id": interactable_id,
			"name": "敌人",
			"description": "前方出现了敌人！",
			"type": "battle_trigger",
			"enemy_id": enemy_id,
			"layer": layer,
			"states": {
				"default": {"interactions": ["战斗"] if not already_cleared else [], "description": "前方出现了敌人！"},
				"cleared": {"interactions": [], "description": "这层的敌人已经被打败了。"}
			}
		}
		if already_cleared:
			_endless_interactables[interactable_id]["states"]["default"] = {"interactions": [], "description": "这层的敌人已经被打败了。"}

func move_to_direction(direction: Direction) -> bool:
	if endless_mode:
		return _endless_move(direction)
	return _normal_move(direction)

func _normal_move(direction: Direction) -> bool:
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

func _endless_move(direction: Direction) -> bool:
	var current_id = map_state.current_location_id
	var current_layer_num = int(current_id.replace("layer_", ""))
	var target_layer = current_layer_num
	
	if direction == Direction.NORTH:
		target_layer = current_layer_num + 1
	elif direction == Direction.SOUTH:
		target_layer = max(current_layer_num - 1, 0)
	else:
		return false
	
	var target_id = "layer_" + str(target_layer)
	
	if not _endless_nodes.has(target_id):
		if target_layer > current_layer_num:
			_generate_layer_node(target_layer)
			var south_id = "layer_" + str(target_layer - 1)
			if _endless_nodes.has(south_id):
				_endless_nodes[south_id]["connections"]["north"] = target_id
			max_layer_reached = target_layer
		else:
			return false
	
	current_layer = target_layer
	map_state.move_to(target_id)
	selected_interactable_id = ""
	interactable_deselected.emit()
	
	if target_layer == 0:
		map_state.add_log("move", "你回到了营地。")
	else:
		map_state.add_log("move", "你进入了第%d层。" % target_layer)
	
	_notify_location_changed()
	return true

func can_move_to(direction: Direction) -> bool:
	if endless_mode:
		if direction == Direction.NORTH:
			if current_layer == 0:
				return true
			var battle_key = "%s:%s" % [map_state.current_location_id, "endless_battle_" + str(current_layer)]
			if not map_state.interactable_states.has(battle_key):
				return true
			return map_state.interactable_states[battle_key] == "cleared"
		if direction == Direction.SOUTH:
			return current_layer > 0
		return false
	
	var current_location = get_current_location_data()
	if current_location.is_empty():
		return false
	var dir_name = DIRECTION_NAMES.get(direction, "")
	var connections = current_location.get("connections", {})
	return connections.has(dir_name)

func get_current_location_data() -> Dictionary:
	if endless_mode:
		var loc_id = map_state.current_location_id
		return _endless_nodes.get(loc_id, {})
	
	if map_state.current_location_id.is_empty():
		return {}
	return map_database.get_location(map_state.current_map_id, map_state.current_location_id)

func get_location_grid() -> Array:
	if endless_mode:
		return _endless_get_grid()
	return _normal_get_grid()

func _endless_get_grid() -> Array:
	var grid: Array = []
	for i in 9:
		grid.append({"id": "", "name": "", "reachable": false, "has_connection": false})
	
	var current_id = map_state.current_location_id
	var current_layer_num = int(current_id.replace("layer_", ""))
	
	var north_id = "layer_" + str(current_layer_num + 1)
	var north_data = _endless_nodes.get(north_id, {})
	if current_layer_num < max_layer_reached or true:
		grid[1] = {"id": north_id, "name": north_data.get("name", "第%d层" % (current_layer_num + 1)), "reachable": true, "has_connection": true, "is_current": false}
	
	grid[4] = {"id": current_id, "name": _endless_nodes.get(current_id, {}).get("name", "营地" if current_layer_num == 0 else "第%d层" % current_layer_num), "reachable": true, "has_connection": true, "is_current": true}
	
	if current_layer_num > 0:
		var south_id = "layer_" + str(current_layer_num - 1)
		var south_data = _endless_nodes.get(south_id, {})
		grid[7] = {"id": south_id, "name": south_data.get("name", "营地" if current_layer_num - 1 == 0 else "第%d层" % (current_layer_num - 1)), "reachable": true, "has_connection": true, "is_current": false}
	
	return grid

func _normal_get_grid() -> Array:
	var grid := []
	for i in 9:
		grid.append({"id": "", "name": "", "reachable": false, "has_connection": false})
	
	var current_location = get_current_location_data()
	if current_location.is_empty():
		return grid
	
	grid[4] = {"id": current_location.get("id", ""), "name": current_location.get("name", ""), "reachable": true, "has_connection": true, "is_current": true}
	
	var connections = current_location.get("connections", {})
	var direction_to_grid := {"north": 1, "north_east": 2, "east": 5, "south_east": 8, "south": 7, "south_west": 6, "west": 3, "north_west": 0}
	
	for dir_name in connections:
		var location_id = connections[dir_name]
		var grid_idx = direction_to_grid.get(dir_name, -1)
		if grid_idx >= 0 and grid_idx < 9:
			var location_data = map_database.get_location(map_state.current_map_id, location_id)
			var is_enabled = map_state.is_connection_enabled(map_state.current_location_id, dir_name)
			grid[grid_idx] = {"id": location_id, "name": location_data.get("name", location_id), "reachable": is_enabled or true, "has_connection": true, "is_current": false}
	
	return grid

func get_interactables() -> Array:
	if endless_mode:
		return _endless_get_interactables()
	return _normal_get_interactables()

func _endless_get_interactables() -> Array:
	var result: Array = []
	var current_id = map_state.current_location_id
	var current_data = _endless_nodes.get(current_id, {})
	if current_data.is_empty():
		return result
	
	var interactable_ids = current_data.get("interactables", [])
	for interactable_id in interactable_ids:
		var interactable_data = _endless_interactables.get(interactable_id, {})
		if interactable_data.is_empty():
			continue
		
		var state_key = "%s:%s" % [current_id, interactable_id]
		var state = map_state.interactable_states.get(state_key, "default")
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
		if interactable_data.has("layer"):
			display_data["layer"] = interactable_data.layer
		
		result.append(display_data)
	
	return result

func _normal_get_interactables() -> Array:
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

func mark_layer_cleared(layer: int) -> void:
	if layer <= 0:
		return
	var interactable_id = "endless_battle_" + str(layer)
	var location_id = "layer_" + str(layer)
	var key = "%s:%s" % [location_id, interactable_id]
	map_state.interactable_states[key] = "cleared"
	
	if not _endless_interactables.has(interactable_id):
		return
	_endless_interactables[interactable_id]["states"]["default"] = {"interactions": [], "description": "这层的敌人已经被打败了。"}
	_endless_interactables[interactable_id]["states"]["cleared"] = {"interactions": [], "description": "这层的敌人已经被打败了。"}

func get_current_layer() -> int:
	return current_layer

func execute_interaction(interactable_id: String, action: String) -> Dictionary:
	if endless_mode:
		return _endless_execute_interaction(interactable_id, action)
	return _normal_execute_interaction(interactable_id, action)

func _endless_execute_interaction(interactable_id: String, action: String) -> Dictionary:
	var interactable_data = _endless_interactables.get(interactable_id, {})
	if interactable_data.is_empty():
		return {"success": false, "message": "找不到交互对象"}
	
	var interactable_type = interactable_data.get("type", "info")
	var interactable_name = interactable_data.get("name", interactable_id)
	var result = {"success": true, "message": "", "type": interactable_type}
	
	match interactable_type:
		"battle_trigger":
			if action == "战斗":
				var enemy_id = interactable_data.get("enemy_id", "")
				var layer = interactable_data.get("layer", 0)
				result.message = "你与第%d层的敌人展开战斗！" % layer
				result.trigger_battle = true
				result.enemy_id = enemy_id
				result.layer = layer
				map_state.add_log("battle", result.message)
		
		"heal":
			if action == "休息":
				var max_hp = GameData.player_max_hp if GameData else 100
				var heal_amount = int(max_hp * 0.5)
				result.message = "你在营地休息，恢复了%d点生命值。" % heal_amount
				result.heal_amount = heal_amount
				result.state_changed = true
				var location_id = map_state.current_location_id
				var key = "%s:%s" % [location_id, interactable_id]
				map_state.interactable_states[key] = "used"
				_endless_interactables[interactable_id]["states"]["used"] = {"interactions": [], "description": "你刚刚休息过了。"}
				_endless_interactables[interactable_id]["states"]["default"] = {"interactions": [], "description": "你刚刚休息过了。"}
				map_state.add_log("heal", result.message)
		
		"deck_view":
			if action == "查看卡组":
				result.message = "你查看了当前卡组。"
				result.show_deck = true
				map_state.add_log("interact", result.message)
		
		"container":
			if action == "打开":
				var layer = interactable_data.get("layer", 0)
				var location_id = map_state.current_location_id
				var key = "%s:%s" % [location_id, interactable_id]
				map_state.interactable_states[key] = "opened"
				_endless_interactables[interactable_id]["states"]["closed"] = {"interactions": [], "description": "已经打开过的宝箱。"}
				_endless_interactables[interactable_id]["states"]["opened"] = {"interactions": [], "description": "已经打开过的宝箱。"}
				result.state_changed = true
				result.open_chest = true
				result.layer = layer
	
	return result

func _normal_execute_interaction(interactable_id: String, action: String) -> Dictionary:
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
	var state = map_state.serialize()
	if endless_mode:
		state["endless_mode"] = true
		state["current_layer"] = current_layer
		state["max_layer_reached"] = max_layer_reached
	return state

func deserialize_state(data: Dictionary) -> void:
	if data.get("endless_mode", false):
		endless_mode = true
		_init_endless()
		current_layer = data.get("current_layer", 0)
		max_layer_reached = data.get("max_layer_reached", 0)
		for layer in range(1, max_layer_reached + 1):
			_generate_layer_node(layer)
		map_state.deserialize(data)
		_notify_location_changed()
	else:
		map_state.deserialize(data)
		if not map_state.current_map_id.is_empty():
			current_map_data = map_database.get_map(map_state.current_map_id)
			_notify_location_changed()