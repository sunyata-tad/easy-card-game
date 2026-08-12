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
var test_mode: bool = false
var current_layer: int = 0
var max_layer_reached: int = 0
var _endless_nodes: Dictionary = {}
var _endless_interactables: Dictionary = {}
var _endless_seed: int = 0  ## 无尽模式楼层生成的随机种子（决定每局楼层类型，随存档持久化）

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
	if map_id == "test":
		return _init_test_map()
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

## 初始化测试地图：营地(测试台+休息处) / 普通战斗层 / 精英战斗层
func _init_test_map() -> bool:
	test_mode = true
	endless_mode = true
	_endless_nodes.clear()
	_endless_interactables.clear()
	max_layer_reached = 5
	current_layer = 0
	
	## 必须先初始化 map_state（initialize 内部会 reset 清空状态），
	## 之后再设置 interactable_states，否则会被 reset 清零导致 _sync_rebuilt_layers 误删所有交互物。
	map_state.initialize("test", "layer_0")
	map_state.current_map_id = "test"
	
	var enemy_db = EnemyDatabase.new()
	
	# Layer 0: 营地
	_endless_nodes["layer_0"] = {
		"id": "layer_0",
		"name": "测试营地",
		"description": "测试地图。这里有测试台，交互可获得100经验值。",
		"connections": {"north": "layer_1"},
		"interactables": ["test_exp_table", "test_rest"]
	}
	_endless_interactables["test_exp_table"] = {
		"id": "test_exp_table",
		"name": "测试台",
		"description": "点击获得100经验值，用于测试升级和加点。",
		"type": "test_exp",
		"states": {
			"default": {"interactions": ["获取经验"], "description": "点击获得100经验值。"}
		}
	}
	_endless_interactables["test_rest"] = {
		"id": "test_rest",
		"name": "休息处",
		"description": "回复生命值。",
		"type": "heal",
		"heal_amount": 0,
		"states": {
			"default": {"interactions": ["休息"], "description": "在这里休息可以恢复生命值。"},
			"used": {"interactions": [], "description": "你刚刚休息过了。"}
		}
	}
	
	# Layer 1: 普通战斗层（石甲卫兵，测试新卡）
	var n_id = "石甲卫兵"
	var n_data = enemy_db.get_enemy(n_id)
	var n_name = n_data.name if n_data else n_id
	_endless_nodes["layer_1"] = {
		"id": "layer_1",
		"name": "普通战斗测试",
		"description": "第1层。%s挡在了前方！" % n_name,
		"connections": {"south": "layer_0", "north": "layer_2"},
		"interactables": ["test_battle_1"],
		"enemy_ids": [n_id]
	}
	_endless_interactables["test_battle_1"] = _create_battle_interactable("test_battle_1", n_name, n_id, 1, false, "%s挡在了前方！" % n_name)
	map_state.interactable_states["layer_1:test_battle_1"] = "default"
	
	# Layer 2: 精英战斗层（每个敌人独立交互物）
	var e_ids = _select_elite_enemies(2, enemy_db)
	var e_list: Array = []
	_endless_nodes["layer_2"] = {
		"id": "layer_2",
		"name": "精英战斗测试",
		"description": "第2层。前方出现了危险的气息……",
		"connections": {"south": "layer_1", "north": "layer_3"},
		"interactables": e_list,
		"enemy_ids": e_ids.duplicate()
	}
	for i in e_ids.size():
		var eid = e_ids[i]
		var ed = enemy_db.get_enemy(eid)
		var enemy_name = ed.name if ed else eid
		var iid = "test_battle_2_%d" % i
		e_list.append(iid)
		_endless_interactables[iid] = _create_battle_interactable(iid, enemy_name, eid, 2, false, "精英敌人：%s" % enemy_name)
		map_state.interactable_states["layer_2:%s" % iid] = "default"
	
	# Layer 3: Boss 层（胜利后触发遗物三选一）
	var boss_ids: Array = ["石甲卫兵", "腐化法师"]
	var boss_list: Array = []
	_endless_nodes["layer_3"] = {
		"id": "layer_3",
		"name": "Boss战",
		"description": "第3层。强大的压迫感扑面而来——击败 Boss 可获得遗物！",
		"connections": {"south": "layer_2", "north": "layer_4"},
		"interactables": boss_list,
		"enemy_ids": boss_ids.duplicate(),
		"boss": true
	}
	for i in boss_ids.size():
		var bid = boss_ids[i]
		var bd = enemy_db.get_enemy(bid)
		var bname = bd.name if bd else bid
		var iid = "test_battle_3_%d" % i
		boss_list.append(iid)
		_endless_interactables[iid] = _create_battle_interactable(iid, bname, bid, 3, false, "Boss：%s" % bname)
		map_state.interactable_states["layer_3:%s" % iid] = "default"
	
	# Layer 4: 战后试用层（用于测试获取到的遗物）
	var p_id = "暗影刺客"
	var p_data = enemy_db.get_enemy(p_id)
	var p_name = p_data.name if p_data else p_id
	_endless_nodes["layer_4"] = {
		"id": "layer_4",
		"name": "遗物试用战",
		"description": "第4层。试试刚获得的遗物！%s挡在了前方！" % p_name,
		"connections": {"south": "layer_3"},
		"interactables": ["test_battle_4"],
		"enemy_ids": [p_id]
	}
	_endless_interactables["test_battle_4"] = _create_battle_interactable("test_battle_4", p_name, p_id, 4, false, "%s挡在了前方！" % p_name)
	map_state.interactable_states["layer_4:test_battle_4"] = "default"
	
	_notify_location_changed()
	return true

func _init_endless() -> bool:
	endless_mode = true
	current_layer = 0
	max_layer_reached = 0
	_endless_nodes.clear()
	_endless_interactables.clear()
	_endless_seed = randi()  ## 新开无尽局：随机种子（决定楼层类型分布）
	
	_endless_nodes["layer_0"] = {
		"id": "layer_0",
		"name": "营地",
		"description": "旅程的起点。从这里向北出发，迎接无尽的挑战。",
		"connections": {"north": "layer_1"},
		"interactables": ["endless_camp_table"]
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
	
	map_state.initialize("endless", "layer_0")
	map_state.current_map_id = "endless"
	_notify_location_changed()
	return true

## 无尽模式楼层类型
enum EndlessLayerType {
	BOSS,
	NORMAL,
	CHEST,
	ELITE,
	EVENT
}

func _determine_layer_type(layer: int) -> EndlessLayerType:
	if layer % 10 == 0:
		return EndlessLayerType.BOSS
	var roll = _seeded_roll(layer)
	if roll < 50:
		return EndlessLayerType.NORMAL
	elif roll < 70:
		return EndlessLayerType.CHEST
	elif roll < 80:
		return EndlessLayerType.ELITE
	else:
		return EndlessLayerType.EVENT

## 基于局种子 + 层数的确定性伪随机：同局内同一层类型稳定，战斗前后重建楼层时不会漂移
func _seeded_roll(layer: int) -> int:
	var h = (_endless_seed + layer * 7919) % 1000003
	h = (h * 48271) % 2147483647
	return h % 100

func _select_normal_enemy(layer: int, enemy_db: EnemyDatabase) -> String:
	var all = enemy_db.get_all_enemy_ids()
	if all.is_empty():
		return "test_dummy"
	return all[(layer * 3 + 5) % all.size()]

func _select_elite_enemies(layer: int, enemy_db: EnemyDatabase) -> Array:
	var all = enemy_db.get_all_enemy_ids()
	if all.is_empty():
		return ["test_dummy"]
	var result: Array = []
	var count = mini(2 + ((layer * 7) % 2), all.size())
	for i in count:
		result.append(all[(layer * 11 + i * 13) % all.size()])
	return result

func _select_boss_enemies(layer: int, enemy_db: EnemyDatabase) -> Array:
	var all = enemy_db.get_all_enemy_ids()
	if all.is_empty():
		return ["test_dummy"]
	var result: Array = []
	var count = mini(2, all.size())
	for i in count:
		result.append(all[(layer * 7 + i * 13) % all.size()])
	return result

func _create_battle_interactable(id: String, label: String, enemy_id: String, layer: int, already_cleared: bool, desc: String) -> Dictionary:
	return {
		"id": id,
		"name": label,
		"description": desc,
		"type": "battle_trigger",
		"enemy_id": enemy_id,
		"layer": layer,
		"states": {
			"default": {"interactions": ["战斗"] if not already_cleared else [], "description": desc},
			"cleared": {"interactions": [], "description": "敌人已被击败。"}
		}
	}

func _generate_layer_node(layer: int) -> void:
	var layer_id = "layer_" + str(layer)
	if _endless_nodes.has(layer_id):
		return
	
	var south_id = "layer_" + str(layer - 1)
	var layer_type = _determine_layer_type(layer)
	var already_cleared = layer < max_layer_reached
	
	var node_data := {
		"id": layer_id,
		"name": "第%d层" % layer,
		"connections": {"south": south_id},
		"interactables": []
	}
	if layer < max_layer_reached:
		node_data["connections"]["north"] = "layer_" + str(layer + 1)
	
	match layer_type:
		EndlessLayerType.BOSS:
			var enemy_db = EnemyDatabase.new()
			var enemy_ids: Array = _select_boss_enemies(layer, enemy_db)
			var list: Array = []
			node_data["description"] = "前方传来一阵强大的压迫感——Boss正在等待着你！"
			node_data["enemy_ids"] = enemy_ids.duplicate()
			for i in enemy_ids.size():
				var eid = enemy_ids[i]
				var ed = enemy_db.get_enemy(eid)
				var ename = ed.name if ed else eid
				var iid = "endless_battle_%d_%d" % [layer, i]
				list.append(iid)
				_endless_interactables[iid] = _create_battle_interactable(iid, ename, eid, layer, already_cleared, "Boss：%s" % ename)
				map_state.interactable_states["%s:%s" % [layer_id, iid]] = "cleared" if already_cleared else "default"
			node_data["interactables"] = list
		
		EndlessLayerType.NORMAL:
			var enemy_db = EnemyDatabase.new()
			var enemy_id: String = _select_normal_enemy(layer, enemy_db)
			var enemy_data = enemy_db.get_enemy(enemy_id)
			var ename = enemy_data.name if enemy_data else enemy_id
			node_data["description"] = "无尽的试炼之塔，第%d层。%s挡在了前方！" % [layer, ename]
			node_data["enemy_ids"] = [enemy_id]
			var iid = "endless_battle_" + str(layer)
			node_data["interactables"] = [iid]
			_endless_interactables[iid] = _create_battle_interactable(iid, ename, enemy_id, layer, already_cleared, "%s挡在了前方！" % ename)
			map_state.interactable_states["%s:%s" % [layer_id, iid]] = "cleared" if already_cleared else "default"
		
		EndlessLayerType.CHEST:
			node_data["description"] = "无尽的试炼之塔，第%d层。前方发现了一个宝箱。" % layer
			var iid = "endless_chest_" + str(layer)
			node_data["interactables"] = [iid]
			_endless_interactables[iid] = {
				"id": iid, "name": "宝箱", "description": "一个华丽的宝箱！",
				"type": "container", "layer": layer,
				"states": {
					"closed": {"interactions": ["打开"] if not already_cleared else [], "description": "一个华丽的宝箱。"},
					"opened": {"interactions": [], "description": "已经打开过的宝箱。"}
				}
			}
			if already_cleared:
				_endless_interactables[iid]["states"]["closed"] = {"interactions": [], "description": "已经打开过的宝箱。"}
				_endless_interactables[iid]["states"]["opened"] = {"interactions": [], "description": "已经打开过的宝箱。"}
			map_state.interactable_states["%s:%s" % [layer_id, iid]] = "opened" if already_cleared else "closed"
		
		EndlessLayerType.ELITE:
			var enemy_db = EnemyDatabase.new()
			var enemy_ids: Array = _select_elite_enemies(layer, enemy_db)
			var list: Array = []
			node_data["description"] = "空气中弥漫着危险的气息……一群精英敌人出现了！"
			node_data["enemy_ids"] = enemy_ids.duplicate()
			for i in enemy_ids.size():
				var eid = enemy_ids[i]
				var ed = enemy_db.get_enemy(eid)
				var ename = ed.name if ed else eid
				var iid = "endless_battle_%d_%d" % [layer, i]
				list.append(iid)
				_endless_interactables[iid] = _create_battle_interactable(iid, ename, eid, layer, already_cleared, "精英敌人：%s" % ename)
				map_state.interactable_states["%s:%s" % [layer_id, iid]] = "cleared" if already_cleared else "default"
			node_data["interactables"] = list
		
		EndlessLayerType.EVENT:
			node_data["description"] = "这里似乎隐藏着什么东西……（事件尚未实装）"
			var iid = "endless_empty_" + str(layer)
			node_data["interactables"] = [iid]
			_endless_interactables[iid] = {
				"id": iid, "name": "空楼层", "description": "事件尚未实装，这里暂时什么都没有。",
				"type": "info",
				"states": {
					"default": {"interactions": ["观察"], "description": "事件尚未实装，这里暂时什么都没有。"},
					"cleared": {"interactions": [], "description": "已经探索过的空楼层。"}
				}
			}
			map_state.interactable_states["%s:%s" % [layer_id, iid]] = "cleared" if already_cleared else "default"
	
	_endless_nodes[layer_id] = node_data

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
	## 用 current_layer 字段作为层数计数（不依赖楼层 id 命名，支持后续非顺序命名）
	var current_layer_num = current_layer
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
			# 测试模式下禁止动态生成楼层，只能探索预设楼层
			if test_mode:
				map_state.add_log("move", "已到达测试地图最顶层，无法继续前进。")
				return false
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
			## 检查当前楼层是否还有存活的战斗交互物
			var loc_id = map_state.current_location_id
			var node_data = _endless_nodes.get(loc_id, {})
			var list: Array = node_data.get("interactables", [])
			for iid in list:
				var idata = _endless_interactables.get(iid, {})
				if idata.get("type", "") == "battle_trigger":
					return false  ## 还有存活的敌人
			return true
		if direction == Direction.SOUTH:
			return current_layer > 0
		return false
	var loc = get_current_location_data()
	if loc.is_empty():
		return false
	return loc.get("connections", {}).has(DIRECTION_NAMES.get(direction, ""))

func get_current_location_data() -> Dictionary:
	if endless_mode:
		return _endless_nodes.get(map_state.current_location_id, {})
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
	## 用 current_layer 字段作为层数计数（不依赖楼层 id 命名）
	var current_layer_num = current_layer
	var north_id = "layer_" + str(current_layer_num + 1)
	var n_data = _endless_nodes.get(north_id, {})
	grid[1] = {"id": north_id, "name": n_data.get("name", "第%d层" % (current_layer_num + 1)), "reachable": true, "has_connection": true, "is_current": false}
	grid[4] = {"id": current_id, "name": _endless_nodes.get(current_id, {}).get("name", "营地"), "reachable": true, "has_connection": true, "is_current": true}
	if current_layer_num > 0:
		var south_id = "layer_" + str(current_layer_num - 1)
		var s_data = _endless_nodes.get(south_id, {})
		grid[7] = {"id": south_id, "name": s_data.get("name", "营地"), "reachable": true, "has_connection": true, "is_current": false}
	return grid

func _normal_get_grid() -> Array:
	var grid := []
	for i in 9:
		grid.append({"id": "", "name": "", "reachable": false, "has_connection": false})
	var loc = get_current_location_data()
	if loc.is_empty():
		return grid
	grid[4] = {"id": loc.get("id", ""), "name": loc.get("name", ""), "reachable": true, "has_connection": true, "is_current": true}
	var conns = loc.get("connections", {})
	var d2g := {"north": 1, "north_east": 2, "east": 5, "south_east": 8, "south": 7, "south_west": 6, "west": 3, "north_west": 0}
	for dname in conns:
		var lid = conns[dname]
		var gi = d2g.get(dname, -1)
		if gi >= 0:
			var ld = map_database.get_location(map_state.current_map_id, lid)
			grid[gi] = {"id": lid, "name": ld.get("name", lid), "reachable": true, "has_connection": true, "is_current": false}
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
	for iid in current_data.get("interactables", []):
		var idata = _endless_interactables.get(iid, {})
		if idata.is_empty():
			continue
		var state_key = "%s:%s" % [current_id, iid]
		var state = map_state.interactable_states.get(state_key, "default")
		var sd = idata.get("states", {}).get(state, {})
		var dd = {
			"id": iid,
			"name": idata.get("name", iid),
			"description": sd.get("description", idata.get("description", "")),
			"type": idata.get("type", "info"),
			"interactions": sd.get("interactions", []),
			"state": state
		}
		if idata.has("enemy_id"):
			dd["enemy_id"] = idata.enemy_id
		if idata.has("heal_amount"):
			dd["heal_amount"] = idata.heal_amount
		if idata.has("layer"):
			dd["layer"] = idata.layer
		result.append(dd)
	return result

func _normal_get_interactables() -> Array:
	var result := []
	var loc = get_current_location_data()
	if loc.is_empty():
		return result
	for iid in loc.get("interactables", []):
		var idata = map_database.get_interactable(map_state.current_map_id, iid)
		if idata.is_empty():
			continue
		var state = map_state.get_interactable_state(map_state.current_location_id, iid)
		var sd = idata.get("states", {}).get(state, {})
		var dd = {
			"id": iid,
			"name": idata.get("name", iid),
			"description": sd.get("description", idata.get("description", "")),
			"type": idata.get("type", "info"),
			"interactions": sd.get("interactions", []),
			"state": state
		}
		if idata.has("enemy_id"):
			dd["enemy_id"] = idata.enemy_id
		if idata.has("heal_amount"):
			dd["heal_amount"] = idata.heal_amount
		result.append(dd)
	return result

func select_interactable(interactable_id: String) -> void:
	selected_interactable_id = interactable_id
	for interactable in get_interactables():
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
	for interactable in get_interactables():
		if interactable.id == selected_interactable_id:
			return interactable
	return {}

## 判断某层是否为 Boss 层（测试地图：layer_3；无尽：每10层）
func is_boss_layer(layer: int) -> bool:
	if test_mode:
		return layer == 3
	return layer > 0 and layer % 10 == 0

func mark_layer_cleared(layer: int) -> void:
	if layer <= 0:
		return
	var loc_id = "layer_" + str(layer)
	var node_data = _endless_nodes.get(loc_id, {})
	var list: Array = node_data.get("interactables", [])
	var removed: Array = []
	for iid in list:
		var idata = _endless_interactables.get(iid, {})
		if idata.get("type", "") == "battle_trigger":
			removed.append(iid)
	for iid in removed:
		list.erase(iid)
		_endless_interactables.erase(iid)
		map_state.interactable_states.erase("%s:%s" % [loc_id, iid])
	if removed.size() > 0:
		node_data["interactables"] = list
		node_data["enemy_ids"] = []

func remove_dead_enemies(alive_ids: Array) -> void:
	var loc_id = map_state.current_location_id
	var node_data = _endless_nodes.get(loc_id, {})
	var list: Array = node_data.get("interactables", [])
	var enemy_ids: Array = node_data.get("enemy_ids", [])
	var removed_ids: Array = []
	var removed_enemies: Array = []
	for iid in list:
		var idata = _endless_interactables.get(iid, {})
		if idata.get("type", "") != "battle_trigger":
			continue
		var eid = idata.get("enemy_id", "")
		if eid == "" or eid in alive_ids:
			continue
		removed_ids.append(iid)
		removed_enemies.append(eid)
	for iid in removed_ids:
		list.erase(iid)
		_endless_interactables.erase(iid)
		map_state.interactable_states.erase("%s:%s" % [loc_id, iid])
	for eid in removed_enemies:
		enemy_ids.erase(eid)
	if removed_ids.size() > 0:
		node_data["interactables"] = list
		node_data["enemy_ids"] = enemy_ids

func get_current_layer() -> int:
	return current_layer

func execute_interaction(interactable_id: String, action: String) -> Dictionary:
	if endless_mode:
		return _endless_execute_interaction(interactable_id, action)
	return _normal_execute_interaction(interactable_id, action)

func _endless_execute_interaction(interactable_id: String, action: String) -> Dictionary:
	var idata = _endless_interactables.get(interactable_id, {})
	if idata.is_empty():
		return {"success": false, "message": "找不到交互对象"}
	var itype = idata.get("type", "info")
	var iname = idata.get("name", interactable_id)
	var result = {"success": true, "message": "", "type": itype}
	
	match itype:
		"battle_trigger":
			if action == "战斗":
				var layer = idata.get("layer", 0)
				# 从节点数据获取该层所有存活敌人ID（群体战斗）
				var node_data = _endless_nodes.get(map_state.current_location_id, {})
				var all_ids: Array = node_data.get("enemy_ids", [])
				if all_ids.is_empty():
					var single = idata.get("enemy_id", "")
					if single != "":
						all_ids = [single]
				result.trigger_battle = true
				result.enemy_ids = all_ids
				result.layer = layer
				map_state.add_log("battle", "你与第%d层的敌人展开战斗！" % layer)
		"test_exp":
			if action == "获取经验":
				if GameData:
					GameData.gain_exp(100)
				result.message = "获得了100经验值！当前等级%d" % GameData.player_level
				map_state.add_log("exp", result.message)
		"heal":
			if action == "休息":
				var max_hp = GameData.player_max_hp if GameData else 100
				var amt = int(max_hp * 0.5)
				result.heal_amount = amt
				result.state_changed = true
				map_state.interactable_states["%s:%s" % [map_state.current_location_id, interactable_id]] = "used"
				_endless_interactables[interactable_id]["states"]["used"] = {"interactions": [], "description": "你刚刚休息过了。"}
				_endless_interactables[interactable_id]["states"]["default"] = {"interactions": [], "description": "你刚刚休息过了。"}
				map_state.add_log("heal", "你在营地休息，恢复了%d点生命值。" % amt)
		"deck_view":
			if action == "查看卡组":
				result.show_deck = true
				map_state.add_log("interact", "你查看了当前卡组。")
		"container":
			if action == "打开":
				var layer = idata.get("layer", 0)
				map_state.interactable_states["%s:%s" % [map_state.current_location_id, interactable_id]] = "opened"
				_endless_interactables[interactable_id]["states"]["closed"] = {"interactions": [], "description": "已经打开过的宝箱。"}
				_endless_interactables[interactable_id]["states"]["opened"] = {"interactions": [], "description": "已经打开过的宝箱。"}
				result.state_changed = true
				result.open_chest = true
				result.layer = layer
	return result

func _normal_execute_interaction(interactable_id: String, action: String) -> Dictionary:
	var idata = map_database.get_interactable(map_state.current_map_id, interactable_id)
	if idata.is_empty():
		return {"success": false, "message": "找不到交互对象"}
	var state = map_state.get_interactable_state(map_state.current_location_id, interactable_id)
	var sd = idata.get("states", {}).get(state, {})
	var interactions = sd.get("interactions", [])
	if action not in interactions:
		return {"success": false, "message": "无效的操作"}
	var itype = idata.get("type", "info")
	var iname = idata.get("name", interactable_id)
	var result = {"success": true, "message": "", "type": itype}
	match itype:
		"battle_trigger":
			if action == "战斗":
				result.trigger_battle = true
				result.enemy_id = idata.get("enemy_id", "")
				map_state.add_log("battle", "你与%s展开战斗！" % iname)
		"heal":
			if action == "治愈":
				result.heal_amount = idata.get("heal_amount", 10)
				map_state.add_log("heal", "你恢复了%d点生命值！" % result.heal_amount)
		"container":
			if action == "打开":
				map_state.set_interactable_state(map_state.current_location_id, interactable_id, "opened")
				result.state_changed = true
				map_state.add_log("interact", "你打开了%s。" % iname)
		"info", "portal":
			result.message = idata.get("description", "")
			map_state.add_log("interact", "你%s：%s" % [action, result.message])
		"deck_view":
			if action == "查看卡组":
				result.show_deck = true
				map_state.add_log("interact", "你查看了当前卡组。")
		_:
			map_state.add_log("interact", "你与%s进行了交互。" % iname)
	return result

func _notify_location_changed() -> void:
	location_changed.emit(get_current_location_data())

func get_log_history(count: int = 5) -> Array:
	return map_state.get_recent_logs(count)

func serialize_state() -> Dictionary:
	var state = map_state.serialize()
	if test_mode:
		state["test_mode"] = true
		state["current_layer"] = current_layer
		state["max_layer_reached"] = max_layer_reached
	elif endless_mode:
		state["endless_mode"] = true
		state["current_layer"] = current_layer
		state["max_layer_reached"] = max_layer_reached
		state["endless_seed"] = _endless_seed
	return state

func deserialize_state(data: Dictionary) -> void:
	if data.get("test_mode", false):
		test_mode = true
		endless_mode = true
		_init_test_map()
		current_layer = data.get("current_layer", 0)
		max_layer_reached = data.get("max_layer_reached", 0)
		map_state.deserialize(data)
		_sync_rebuilt_layers()
		_notify_location_changed()
	elif data.get("endless_mode", false):
		endless_mode = true
		_init_endless()
		_endless_seed = data.get("endless_seed", _endless_seed)  ## 用存档种子恢复，保证楼层类型与原局一致
		current_layer = data.get("current_layer", 0)
		max_layer_reached = data.get("max_layer_reached", 0)
		for layer in range(1, max_layer_reached + 1):
			_generate_layer_node(layer)
		map_state.deserialize(data)
		_sync_rebuilt_layers()
		_notify_location_changed()
	else:
		map_state.deserialize(data)
		if not map_state.current_map_id.is_empty():
			current_map_data = map_database.get_map(map_state.current_map_id)
			_notify_location_changed()

## _init 重建后同步：清除所有已被删除（不在 states 中）的战斗交互物
func _sync_rebuilt_layers() -> void:
	for loc_id in _endless_nodes:
		var node_data = _endless_nodes[loc_id]
		var list: Array = node_data.get("interactables", []).duplicate()
		var enemy_ids: Array = node_data.get("enemy_ids", []).duplicate()
		var removed_any = false
		for iid in list:
			var key = "%s:%s" % [loc_id, iid]
			if not map_state.interactable_states.has(key):
				# 该交互物已被删除——先从 enemy_ids 中删除对应ID，再清除交互物
				var idata = _endless_interactables.get(iid, {})
				var eid = idata.get("enemy_id", "")
				if eid != "" and eid in enemy_ids:
					enemy_ids.erase(eid)
				node_data["interactables"].erase(iid)
				_endless_interactables.erase(iid)
				removed_any = true
		if removed_any:
			node_data["enemy_ids"] = enemy_ids
