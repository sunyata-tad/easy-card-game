## 地图状态模型：存储当前地图探索的进度（位置、已访问节点、交互物状态等）。
## Godot 特色：
## - "%s:%s" % [a, b] 格式化字符串
## - Array.slice(start_idx) 从指定索引截取子数组
class_name MapState

var current_map_id: String = ""         ## 当前地图 id
var current_location_id: String = ""    ## 当前所在位置 id
var visited_locations: Array = []       ## 已访问的位置 id 列表
var interactable_states: Dictionary = {}  ## 交互物状态 { "location:interact": "state" }
var enabled_connections: Dictionary = {}  ## 已启用的连接 { location_id: [方向列表] }
var interaction_log: Array = []          ## 交互日志

signal location_changed(location_id: String)                              ## 位置变化
signal interactable_state_changed(location_id: String, interactable_id: String)  ## 交互物状态变化
signal log_added(entry: Dictionary)                                        ## 新日志条目

## 重置所有状态
func reset() -> void:
	current_map_id = ""
	current_location_id = ""
	visited_locations.clear()
	interactable_states.clear()
	enabled_connections.clear()
	interaction_log.clear()

## 初始化地图（设置起始位置并标记为已访问）
func initialize(map_id: String, start_location: String) -> void:
	reset()
	current_map_id = map_id
	current_location_id = start_location
	visited_locations.append(start_location)

## 移动到新位置（自动添加到已访问列表）
func move_to(location_id: String) -> void:
	if location_id.is_empty():
		return

	current_location_id = location_id
	if not visited_locations.has(location_id):
		visited_locations.append(location_id)

	location_changed.emit(location_id)

## 获取交互物的当前状态
func get_interactable_state(location_id: String, interactable_id: String) -> String:
	var key = "%s:%s" % [location_id, interactable_id]
	return interactable_states.get(key, "default")

## 设置交互物的状态
func set_interactable_state(location_id: String, interactable_id: String, state: String) -> void:
	var key = "%s:%s" % [location_id, interactable_id]
	interactable_states[key] = state
	interactable_state_changed.emit(location_id, interactable_id)

## 检查某个位置的某个方向连接是否已启用
func is_connection_enabled(location_id: String, direction: String) -> bool:
	var location_enabled = enabled_connections.get(location_id, [])
	return direction in location_enabled

## 启用某个位置的某个方向连接
func enable_connection(location_id: String, direction: String) -> void:
	if not enabled_connections.has(location_id):
		enabled_connections[location_id] = []
	if direction not in enabled_connections[location_id]:
		enabled_connections[location_id].append(direction)

## 添加交互日志
func add_log(log_type: String, text: String, speaker: String = "") -> void:
	var entry = {
		"type": log_type,
		"text": text,
		"speaker": speaker,
		"time": Time.get_ticks_msec()
	}
	interaction_log.append(entry)
	log_added.emit(entry)

## 获取最近 N 条日志
func get_recent_logs(count: int = 5) -> Array:
	var start_idx = maxi(interaction_log.size() - count, 0)
	return interaction_log.slice(start_idx)

## 序列化为字典（用于存档）
func serialize() -> Dictionary:
	return {
		"current_map_id": current_map_id,
		"current_location_id": current_location_id,
		"visited_locations": visited_locations.duplicate(),
		"interactable_states": interactable_states.duplicate(),
		"enabled_connections": enabled_connections.duplicate(),
		"interaction_log": interaction_log.duplicate()
	}

## 从字典恢复状态
func deserialize(data: Dictionary) -> void:
	current_map_id = data.get("current_map_id", "")
	current_location_id = data.get("current_location_id", "")
	visited_locations = data.get("visited_locations", [])
	interactable_states = data.get("interactable_states", {})
	enabled_connections = data.get("enabled_connections", {})
	interaction_log = data.get("interaction_log", [])