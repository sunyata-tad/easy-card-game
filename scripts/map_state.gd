class_name MapState

var current_map_id: String = ""
var current_location_id: String = ""
var visited_locations: Array = []
var interactable_states: Dictionary = {}
var enabled_connections: Dictionary = {}
var interaction_log: Array = []

signal location_changed(location_id: String)
signal interactable_state_changed(location_id: String, interactable_id: String)
signal log_added(entry: Dictionary)

func reset() -> void:
	current_map_id = ""
	current_location_id = ""
	visited_locations.clear()
	interactable_states.clear()
	enabled_connections.clear()
	interaction_log.clear()

func initialize(map_id: String, start_location: String) -> void:
	reset()
	current_map_id = map_id
	current_location_id = start_location
	visited_locations.append(start_location)

func move_to(location_id: String) -> void:
	if location_id.is_empty():
		return
	
	current_location_id = location_id
	if not visited_locations.has(location_id):
		visited_locations.append(location_id)
	
	location_changed.emit(location_id)

func get_interactable_state(location_id: String, interactable_id: String) -> String:
	var key = "%s:%s" % [location_id, interactable_id]
	return interactable_states.get(key, "default")

func set_interactable_state(location_id: String, interactable_id: String, state: String) -> void:
	var key = "%s:%s" % [location_id, interactable_id]
	interactable_states[key] = state
	interactable_state_changed.emit(location_id, interactable_id)

func is_connection_enabled(location_id: String, direction: String) -> bool:
	var location_enabled = enabled_connections.get(location_id, [])
	return direction in location_enabled

func enable_connection(location_id: String, direction: String) -> void:
	if not enabled_connections.has(location_id):
		enabled_connections[location_id] = []
	if direction not in enabled_connections[location_id]:
		enabled_connections[location_id].append(direction)

func add_log(log_type: String, text: String, speaker: String = "") -> void:
	var entry = {
		"type": log_type,
		"text": text,
		"speaker": speaker,
		"time": Time.get_ticks_msec()
	}
	interaction_log.append(entry)
	log_added.emit(entry)

func get_recent_logs(count: int = 5) -> Array:
	var start_idx = maxi(interaction_log.size() - count, 0)
	return interaction_log.slice(start_idx)

func serialize() -> Dictionary:
	return {
		"current_map_id": current_map_id,
		"current_location_id": current_location_id,
		"visited_locations": visited_locations.duplicate(),
		"interactable_states": interactable_states.duplicate(),
		"enabled_connections": enabled_connections.duplicate(),
		"interaction_log": interaction_log.duplicate()
	}

func deserialize(data: Dictionary) -> void:
	current_map_id = data.get("current_map_id", "")
	current_location_id = data.get("current_location_id", "")
	visited_locations = data.get("visited_locations", [])
	interactable_states = data.get("interactable_states", {})
	enabled_connections = data.get("enabled_connections", {})
	interaction_log = data.get("interaction_log", [])
