## 地图场景脚本：挂载到 MapScreen.tscn 的根 Control 节点上。
## 纯代码构建整个地图 UI（位置节点、交互物列表、探索日志、状态面板等），不依赖场景模板。
## Godot 特色：
## - 此脚本演示了完全用代码构建复杂 UI 的方式（创建节点→设置属性→添加到父容器）
## - ScrollContainer 是可滚动的容器（类似 HTML 的 overflow: scroll）
## - HFlowContainer 是自动换行的水平布局（类似 CSS 的 flex-wrap）
## - create_tween() 用于节点移动/淡入淡出的动画效果
## - await get_tree().create_timer(x).timeout 实现延迟等待
## - is_instance_valid(node) 检查节点是否仍有效
extends Control

var map_controller: MapController

var location_label: Label
var description_label: Label
var status_button: Button
var relic_button: Button
var settings_button: Button
var interactables_container: HBoxContainer
var log_container: VBoxContainer
var interaction_panel: VBoxContainer
var location_info_panel: VBoxContainer

var node_container: Control
var active_nodes: Dictionary = {}
var is_animating: bool = false

var status_panel: PanelContainer
var status_panel_content: VBoxContainer
var status_panel_open: bool = false
var status_panel_tween: Tween = null
var _scroll_pending: bool = false

const STATUS_PANEL_HEIGHT := 420

const RELIC_LIST_PANEL := preload("res://scenes/RelicListPanel.tscn")

const BTN_W := 100
const BTN_H := 36
const GAP_X := 40
const GAP_Y := 30

signal battle_requested(enemy_id: String)

func _ready():
	map_controller = MapController.new()
	map_controller.location_changed.connect(_on_location_changed)
	map_controller.interactable_selected.connect(_on_interactable_selected)
	map_controller.interactable_deselected.connect(_on_interactable_deselected)
	map_controller.log_message.connect(_on_log_message)
	map_controller.battle_requested.connect(_on_battle_requested)
	
	battle_requested.connect(_on_battle_request_internal)
	
	_setup_ui()

func _process(_delta: float) -> void:
	if _scroll_pending:
		_scroll_pending = false
		var scroll = log_container.get_parent()
		if scroll and scroll is ScrollContainer:
			scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func _setup_ui():
	anchors_preset = 15
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = 2
	grow_vertical = 2
	
	var main_vbox = VBoxContainer.new()
	main_vbox.anchors_preset = 15
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.grow_horizontal = 2
	main_vbox.grow_vertical = 2
	main_vbox.add_theme_constant_override("separation", 2)
	add_child(main_vbox)
	
	var top_section = _create_top_section()
	main_vbox.add_child(top_section)
	
	var map_section = _create_map_section()
	main_vbox.add_child(map_section)
	
	var interactables_section = _create_interactables_section()
	main_vbox.add_child(interactables_section)
	
	var log_section = _create_log_section()
	main_vbox.add_child(log_section)
	
	_create_status_panel()

func _create_top_section() -> Control:
	var top_container = VBoxContainer.new()
	top_container.custom_minimum_size = Vector2(0, 130)
	top_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 32)
	header.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_theme_constant_override("separation", 10)
	top_container.add_child(header)
	
	status_button = Button.new()
	status_button.text = "状态"
	status_button.custom_minimum_size = Vector2(80, 28)
	status_button.pressed.connect(_on_status_pressed)
	header.add_child(status_button)
	
	relic_button = Button.new()
	relic_button.text = "遗物"
	relic_button.custom_minimum_size = Vector2(80, 28)
	relic_button.pressed.connect(_on_relic_pressed)
	header.add_child(relic_button)
	
	var spacer_left = Control.new()
	spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer_left)
	
	location_label = Label.new()
	location_label.text = "地点名称"
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_label.add_theme_font_size_override("font_size", 20)
	location_label.custom_minimum_size = Vector2(200, 28)
	header.add_child(location_label)
	
	var spacer_right = Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer_right)
	
	settings_button = Button.new()
	settings_button.text = "设置"
	settings_button.custom_minimum_size = Vector2(80, 28)
	settings_button.pressed.connect(_on_settings_pressed)
	header.add_child(settings_button)

	var overview_btn = Button.new()
	overview_btn.text = "地图"
	overview_btn.custom_minimum_size = Vector2(80, 28)
	overview_btn.pressed.connect(_on_map_overview_pressed)
	header.add_child(overview_btn)
	
	var info_container = VBoxContainer.new()
	info_container.custom_minimum_size = Vector2(0, 95)
	info_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_container.add_theme_constant_override("separation", 5)
	top_container.add_child(info_container)
	
	location_info_panel = VBoxContainer.new()
	location_info_panel.add_theme_constant_override("separation", 5)
	info_container.add_child(location_info_panel)
	
	description_label = Label.new()
	description_label.text = "地点介绍..."
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	description_label.custom_minimum_size = Vector2(0, 60)
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	location_info_panel.add_child(description_label)
	
	interaction_panel = VBoxContainer.new()
	interaction_panel.visible = false
	info_container.add_child(interaction_panel)
	
	return top_container

func _create_map_section() -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(0, 280)
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var bg = ColorRect.new()
	bg.anchors_preset = 15
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.grow_horizontal = 2
	bg.grow_vertical = 2
	bg.color = Color(0.05, 0.05, 0.1, 1.0)
	container.add_child(bg)
	
	node_container = Control.new()
	node_container.anchors_preset = 15
	node_container.anchor_right = 1.0
	node_container.anchor_bottom = 1.0
	node_container.grow_horizontal = 2
	node_container.grow_vertical = 2
	node_container.clip_contents = true
	container.add_child(node_container)
	
	return container

func _get_direction_offset(dir_name: String) -> Vector2:
	match dir_name:
		"north": return Vector2(0, -(BTN_H + GAP_Y))
		"south": return Vector2(0, BTN_H + GAP_Y)
		"east": return Vector2(BTN_W + GAP_X, 0)
		"west": return Vector2(-(BTN_W + GAP_X), 0)
		"north_east": return Vector2(BTN_W + GAP_X, -(BTN_H + GAP_Y))
		"north_west": return Vector2(-(BTN_W + GAP_X), -(BTN_H + GAP_Y))
		"south_east": return Vector2(BTN_W + GAP_X, BTN_H + GAP_Y)
		"south_west": return Vector2(-(BTN_W + GAP_X), BTN_H + GAP_Y)
		_: return Vector2.ZERO

func _create_node(location_id: String, location_data: Dictionary, pos: Vector2, is_current: bool) -> Button:
	var btn = Button.new()
	btn.size = Vector2(BTN_W, BTN_H)
	btn.add_theme_font_size_override("font_size", 14)
	btn.position = pos
	btn.modulate.a = 0.0
	
	var name = location_data.get("name", location_id)
	btn.text = name
	
	if is_current:
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
	else:
		btn.disabled = false
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		btn.pressed.connect(_on_node_pressed.bind(location_id))
	
	node_container.add_child(btn)
	return btn

func _on_node_pressed(location_id: String):
	if is_animating:
		return
	
	var grid = map_controller.get_location_grid()
	for i in grid.size():
		if grid[i].get("id", "") == location_id:
			var direction_map := {
				0: MapController.Direction.NORTH_WEST,
				1: MapController.Direction.NORTH,
				2: MapController.Direction.NORTH_EAST,
				3: MapController.Direction.WEST,
				5: MapController.Direction.EAST,
				6: MapController.Direction.SOUTH_WEST,
				7: MapController.Direction.SOUTH,
				8: MapController.Direction.SOUTH_EAST
			}
			if direction_map.has(i):
				_do_move_animation(direction_map[i])
			break

func _get_center_pos() -> Vector2:
	var container_size = node_container.size
	if container_size.x < 1 or container_size.y < 1:
		container_size = Vector2(1152, 280)
	return container_size / 2 - Vector2(BTN_W, BTN_H) / 2

func _get_grid_position(grid_index: int, center_pos: Vector2) -> Vector2:
	if grid_index == 4:
		return center_pos
	var dir_name = ""
	match grid_index:
		0: dir_name = "north_west"
		1: dir_name = "north"
		2: dir_name = "north_east"
		3: dir_name = "west"
		5: dir_name = "east"
		6: dir_name = "south_west"
		7: dir_name = "south"
		8: dir_name = "south_east"
	if dir_name.is_empty():
		return center_pos
	return center_pos + _get_direction_offset(dir_name)

func _refresh_nodes() -> void:
	for node_id in active_nodes:
		var node = active_nodes[node_id]
		if node.btn and is_instance_valid(node.btn):
			node.btn.queue_free()
	active_nodes.clear()
	
	var grid = map_controller.get_location_grid()
	var center_pos = _get_center_pos()
	
	for i in grid.size():
		var cell = grid[i]
		var loc_id = cell.get("id", "")
		if loc_id.is_empty():
			continue
		
		var pos = _get_grid_position(i, center_pos)
		var is_current = cell.get("is_current", false)
		var location_data = {"name": cell.get("name", loc_id)}
		var btn = _create_node(loc_id, location_data, pos, is_current)
		
		var tween = create_tween()
		tween.tween_property(btn, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
		
		active_nodes[loc_id] = {"btn": btn, "base_pos": pos}

func _update_location_grid():
	_refresh_nodes()

func _create_interactables_section() -> Control:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 70)
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var header = Label.new()
	header.text = "这里有："
	header.add_theme_font_size_override("font_size", 14)
	header.custom_minimum_size = Vector2(0, 20)
	container.add_child(header)
	
	interactables_container = HBoxContainer.new()
	interactables_container.add_theme_constant_override("separation", 10)
	interactables_container.custom_minimum_size = Vector2(0, 40)
	container.add_child(interactables_container)
	
	return container

func _create_log_section() -> Control:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 120)
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var bg = ColorRect.new()
	bg.anchors_preset = 12
	bg.anchor_bottom = 1.0
	bg.grow_vertical = 2
	bg.color = Color(0.1, 0.1, 0.12, 1.0)
	container.add_child(bg)
	
	var header = Label.new()
	header.text = "探索日志"
	header.add_theme_font_size_override("font_size", 14)
	header.custom_minimum_size = Vector2(0, 22)
	container.add_child(header)
	
	var log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.custom_minimum_size = Vector2(0, 90)
	
	log_container = VBoxContainer.new()
	log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_container.add_theme_constant_override("separation", 2)
	log_scroll.add_child(log_container)
	container.add_child(log_scroll)
	
	return container

func receive_data(data: Dictionary) -> void:
	var map_id = data.get("map_id", "test_map")
	var map_state = data.get("map_state", {})
	if data.get("test_mode", false):
		map_controller.test_mode = true
	if data.get("endless_mode", false):
		map_controller.endless_mode = true
	if not map_state.is_empty():
		# 处理战斗存活的敌人和胜利后的楼层清除
		var survived = map_state.get("survived_battle", false)
		var alive_list = map_state.get("alive_enemy_ids", [])
		var cleared_layer = map_state.get("endless_layer_cleared", 0)
		map_controller.deserialize_state(map_state)
		if survived:
			map_controller.remove_dead_enemies(alive_list)
		if cleared_layer > 0 and (map_controller.endless_mode or map_controller.test_mode):
			map_controller.mark_layer_cleared(cleared_layer)
		var location_data = map_controller.get_current_location_data()
		if not location_data.is_empty():
			location_label.text = location_data.get("name", "未知地点")
			description_label.text = location_data.get("description", "")
			_update_location_grid()
			_update_interactables()
	else:
		if not map_controller.load_map(map_id):
			push_error("Failed to load map")
	_refresh_logs()
	if not map_controller.test_mode:
		SaveManager.save_map_state()
	# 连接 GameData 信号实现状态栏实时刷新
	_refresh_status_on_signal()

func _on_location_changed(location_data: Dictionary):
	location_label.text = location_data.get("name", "未知地点")
	description_label.text = location_data.get("description", "")
	
	interaction_panel.visible = false
	location_info_panel.visible = true
	
	if not is_animating:
		_update_location_grid()
	_update_interactables()
	if not map_controller.test_mode:
		SaveManager.save_map_state()

func _update_interactables():
	for child in interactables_container.get_children():
		child.queue_free()
	
	var interactables = map_controller.get_interactables()
	
	if interactables.is_empty():
		var label = Label.new()
		label.text = "这里没有可交互的东西"
		interactables_container.add_child(label)
		return
	
	for interactable in interactables:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		
		var btn = Button.new()
		btn.text = interactable.name
		var state = interactable.get("state", "default")
		if state != "default":
			btn.text += " (%s)" % state
		
		var interactable_id = interactable.id
		btn.pressed.connect(_on_interactable_pressed.bind(interactable_id))
		hbox.add_child(btn)
		
		interactables_container.add_child(hbox)

func _on_interactable_pressed(interactable_id: String):
	map_controller.select_interactable(interactable_id)

func _on_interactable_selected(interactable_data: Dictionary):
	location_info_panel.visible = false
	interaction_panel.visible = true
	
	for child in interaction_panel.get_children():
		child.queue_free()
	
	var name_label = Label.new()
	name_label.text = "【%s】" % interactable_data.name
	name_label.add_theme_font_size_override("font_size", 18)
	interaction_panel.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = interactable_data.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	interaction_panel.add_child(desc_label)
	
	var interactions = interactable_data.get("interactions", [])
	if not interactions.is_empty():
		var btn_container = HBoxContainer.new()
		btn_container.add_theme_constant_override("separation", 10)
		
		for action in interactions:
			var btn = Button.new()
			btn.text = action
			btn.pressed.connect(_on_interaction_action_pressed.bind(interactable_data.id, action))
			btn_container.add_child(btn)
		
		var cancel_btn = Button.new()
		cancel_btn.text = "取消"
		cancel_btn.pressed.connect(_on_cancel_interaction_pressed)
		btn_container.add_child(cancel_btn)
		
		interaction_panel.add_child(btn_container)

func _on_interactable_deselected():
	interaction_panel.visible = false
	location_info_panel.visible = true

func _on_interaction_action_pressed(interactable_id: String, action: String):
	var result = map_controller.execute_interaction(interactable_id, action)
	
	if result.get("success", false):
		if result.get("trigger_battle", false):
			var enemy_ids = result.get("enemy_ids", [])
			if enemy_ids.is_empty():
				# 兼容旧的单敌人格式
				var single_id = result.get("enemy_id", "")
				if single_id != "":
					enemy_ids = [single_id]
			var layer = result.get("layer", 0)
			_start_group_battle(enemy_ids, layer)
		elif result.get("open_chest", false):
			_open_chest_reward(result.get("layer", 0))
		elif result.get("heal_amount", 0) > 0:
			var heal_amount = result.heal_amount
			if GameData:
				GameData.heal(heal_amount)
		elif result.get("show_deck", false):
			_show_deck_workbench()
		
		if result.get("state_changed", false):
			_update_interactables()
			map_controller.select_interactable(interactable_id)

func _on_cancel_interaction_pressed():
	map_controller.deselect_interactable()

func _update_node_appearance(btn: Button, is_current: bool, location_id: String) -> void:
	if is_current:
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
	else:
		btn.disabled = false
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		if btn.pressed.get_connections().size() == 0:
			btn.pressed.connect(_on_node_pressed.bind(location_id))

func _do_move_animation(direction: int) -> void:
	if is_animating:
		return
	if not map_controller.can_move_to(direction):
		if map_controller.endless_mode and direction == MapController.Direction.NORTH:
			map_controller.map_state.add_log("move", "敌人阻拦了你，无法前进！")
		return
	is_animating = true
	
	var center_pos = _get_center_pos()
	var move_duration := 0.5
	var fade_duration := 0.4
	
	var old_grid = map_controller.get_location_grid()
	var old_id_to_grid_idx: Dictionary = {}
	for i in old_grid.size():
		var loc_id = old_grid[i].get("id", "")
		if not loc_id.is_empty():
			old_id_to_grid_idx[loc_id] = i
	
	map_controller.move_to_direction(direction)
	
	var new_grid = map_controller.get_location_grid()
	var new_id_to_grid_idx: Dictionary = {}
	for i in new_grid.size():
		var loc_id = new_grid[i].get("id", "")
		if not loc_id.is_empty():
			new_id_to_grid_idx[loc_id] = i
	
	var keep_ids: Array = []
	var remove_ids: Array = []
	var add_ids: Array = []
	
	for old_id in old_id_to_grid_idx:
		if new_id_to_grid_idx.has(old_id):
			keep_ids.append(old_id)
		else:
			remove_ids.append(old_id)
	
	for new_id in new_id_to_grid_idx:
		if not old_id_to_grid_idx.has(new_id):
			add_ids.append(new_id)
	
	var has_movement := false
	for keep_id in keep_ids:
		var old_idx = old_id_to_grid_idx[keep_id]
		var new_idx = new_id_to_grid_idx[keep_id]
		if old_idx != new_idx:
			has_movement = true
			break
	if remove_ids.size() > 0 or add_ids.size() > 0:
		has_movement = true
	
	for keep_id in keep_ids:
		var node_data = active_nodes.get(keep_id)
		if not node_data or not node_data.btn or not is_instance_valid(node_data.btn):
			continue
		var btn = node_data.btn
		var new_grid_idx = new_id_to_grid_idx[keep_id]
		var new_pos = _get_grid_position(new_grid_idx, center_pos)
		var is_current = new_grid[new_grid_idx].get("is_current", false)
		
		_update_node_appearance(btn, is_current, keep_id)
		active_nodes[keep_id].base_pos = new_pos
		
		if btn.position != new_pos:
			var tween = create_tween()
			tween.tween_property(btn, "position", new_pos, move_duration).set_ease(Tween.EASE_IN_OUT)
	
	for old_id in remove_ids:
		var node_data = active_nodes.get(old_id)
		if node_data and node_data.btn and is_instance_valid(node_data.btn):
			var btn = node_data.btn
			var old_grid_idx = old_id_to_grid_idx[old_id]
			var old_pos = _get_grid_position(old_grid_idx, center_pos)
			
			var move_target: Vector2 = old_pos
			var best_dist := 999999.0
			for nid in keep_ids:
				var n_new_idx = new_id_to_grid_idx[nid]
				var n_new_pos = _get_grid_position(n_new_idx, center_pos)
				var n_old_idx = old_id_to_grid_idx[nid]
				var n_old_pos = _get_grid_position(n_old_idx, center_pos)
				var delta = n_new_pos - n_old_pos
				var projected = old_pos + delta
				var dist = absf(delta.length())
				if dist > 0.01 and dist < best_dist:
					best_dist = dist
					move_target = projected
			
			var tween = create_tween()
			tween.set_parallel(true)
			if move_target.distance_to(old_pos) > 0.01:
				tween.tween_property(btn, "position", move_target, move_duration).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(btn, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_IN)
	
	for new_id in add_ids:
		var new_grid_idx = new_id_to_grid_idx[new_id]
		var new_pos = _get_grid_position(new_grid_idx, center_pos)
		var is_current = new_grid[new_grid_idx].get("is_current", false)
		var location_data = {"name": new_grid[new_grid_idx].get("name", new_id)}
		
		var start_pos: Vector2 = new_pos
		var best_dist := 999999.0
		for kid in keep_ids:
			var k_new_idx = new_id_to_grid_idx[kid]
			var k_new_pos = _get_grid_position(k_new_idx, center_pos)
			var k_old_idx = old_id_to_grid_idx[kid]
			var k_old_pos = _get_grid_position(k_old_idx, center_pos)
			var delta = k_old_pos - k_new_pos
			var dist = absf(delta.length())
			var projected = new_pos + delta
			if dist > 0.01 and dist < best_dist:
				best_dist = dist
				start_pos = projected
		
		var btn = _create_node(new_id, location_data, start_pos, is_current)
		active_nodes[new_id] = {"btn": btn, "base_pos": new_pos}
		
		var tween = create_tween()
		tween.set_parallel(true)
		if start_pos.distance_to(new_pos) > 0.01:
			tween.tween_property(btn, "position", new_pos, move_duration).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(btn, "modulate:a", 1.0, fade_duration).set_ease(Tween.EASE_OUT)
	
	if has_movement:
		await get_tree().create_timer(maxi(move_duration, fade_duration)).timeout
	
	for old_id in remove_ids:
		var node_data = active_nodes.get(old_id)
		if node_data and node_data.btn and is_instance_valid(node_data.btn):
			node_data.btn.queue_free()
		active_nodes.erase(old_id)
	
	is_animating = false

func _on_log_message(text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	log_container.add_child(label)
	
	while log_container.get_child_count() > 50:
		var oldest = log_container.get_child(0)
		log_container.remove_child(oldest)
		oldest.queue_free()
	
	_scroll_pending = true

func _rebuild_logs():
	var children = log_container.get_children()
	for child in children:
		log_container.remove_child(child)
		child.queue_free()
	
	var logs = map_controller.get_log_history(50)
	for entry in logs:
		var label = Label.new()
		label.text = entry.get("text", "")
		label.add_theme_font_size_override("font_size", 12)
		log_container.add_child(label)
	
	_scroll_pending = true

func _refresh_logs():
	_rebuild_logs()

func _on_status_pressed():
	if status_panel_open:
		_close_status_panel()
	else:
		_open_status_panel()

func _on_settings_pressed():
	_show_settings_dialog()

## 查看持有遗物：弹出可滚动的遗物列表（悬浮查看效果）
func _on_relic_pressed():
	if GameData == null:
		return
	var popup := PopupPanel.new()
	popup.name = "RelicPopup"
	var panel: Control = RELIC_LIST_PANEL.instantiate()
	popup.add_child(panel)
	add_child(popup)
	panel.setup(GameData.get_relics())
	popup.popup_hide.connect(popup.queue_free)
	popup.popup_centered()

## 连接 GameData 信号，状态栏打开时实时刷新（静默重建，无动画）
func _refresh_status_on_signal() -> void:
	if not GameData:
		return
	# 断开旧连接防止重复
	if GameData.hp_changed.is_connected(_on_game_data_changed):
		GameData.hp_changed.disconnect(_on_game_data_changed)
	if GameData.stats_changed.is_connected(_on_game_data_changed):
		GameData.stats_changed.disconnect(_on_game_data_changed)
	if GameData.exp_changed.is_connected(_on_game_data_changed):
		GameData.exp_changed.disconnect(_on_game_data_changed)
	if GameData.level_changed.is_connected(_on_game_data_changed):
		GameData.level_changed.disconnect(_on_game_data_changed)
	if GameData.attribute_points_changed.is_connected(_on_game_data_changed):
		GameData.attribute_points_changed.disconnect(_on_game_data_changed)
	if GameData.gold_changed.is_connected(_on_game_data_changed):
		GameData.gold_changed.disconnect(_on_game_data_changed)
	
	# 监听所有相关信号
	GameData.hp_changed.connect(_on_game_data_changed)
	GameData.stats_changed.connect(_on_game_data_changed)
	GameData.exp_changed.connect(_on_game_data_changed)
	GameData.level_changed.connect(_on_game_data_changed)
	GameData.attribute_points_changed.connect(_on_game_data_changed)
	GameData.gold_changed.connect(_on_game_data_changed)

## 状态数据变化时静默刷新（无动画重建）
func _on_game_data_changed(_a = null, _b = null) -> void:
	if not status_panel_open:
		return
	for child in status_panel_content.get_children():
		child.queue_free()
	_build_status_panel_content()

func _create_status_panel() -> void:
	status_panel = PanelContainer.new()
	status_panel.anchor_left = 0.0
	status_panel.anchor_right = 1.0
	status_panel.anchor_top = 1.0
	status_panel.anchor_bottom = 1.0
	status_panel.offset_top = 0
	status_panel.offset_bottom = 0
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.12, 0.97)
	style.border_color = Color(0.3, 0.3, 0.4, 0.8)
	style.border_width_top = 2
	style.set_corner_radius_all(0)
	status_panel.add_theme_stylebox_override("panel", style)
	
	add_child(status_panel)
	
	status_panel_content = VBoxContainer.new()
	status_panel_content.anchors_preset = Control.PRESET_FULL_RECT
	status_panel_content.add_theme_constant_override("separation", 8)
	status_panel_content.offset_left = 20
	status_panel_content.offset_right = -20
	status_panel_content.offset_top = 12
	status_panel_content.offset_bottom = -12
	status_panel.add_child(status_panel_content)

func _open_status_panel() -> void:
	for child in status_panel_content.get_children():
		child.queue_free()
	
	_build_status_panel_content()
	
	status_panel_open = true
	status_panel.offset_top = 0
	status_panel.offset_bottom = STATUS_PANEL_HEIGHT
	
	if status_panel_tween and status_panel_tween.is_running():
		status_panel_tween.kill()
	status_panel_tween = create_tween()
	status_panel_tween.tween_property(status_panel, "offset_top", -STATUS_PANEL_HEIGHT, 0.3).set_ease(Tween.EASE_OUT)

func _close_status_panel() -> void:
	if not status_panel_open:
		return
	
	if status_panel_tween and status_panel_tween.is_running():
		status_panel_tween.kill()
	status_panel_tween = create_tween()
	status_panel_tween.tween_property(status_panel, "offset_top", 0, 0.25).set_ease(Tween.EASE_IN)
	status_panel_tween.tween_callback(func(): status_panel_open = false)

func _build_status_panel_content() -> void:
	var header = HBoxContainer.new()
	var title = Label.new()
	title.text = "角色状态"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "收起"
	close_btn.custom_minimum_size = Vector2(60, 28)
	close_btn.pressed.connect(_close_status_panel)
	header.add_child(close_btn)
	status_panel_content.add_child(header)
	
	_add_panel_separator()
	
	if GameData:
		# 等级和经验条
		var level_row = HBoxContainer.new()
		level_row.add_theme_constant_override("separation", 10)
		
		var level_label = Label.new()
		level_label.text = "等级 %d" % GameData.player_level
		level_label.add_theme_font_size_override("font_size", 16)
		level_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		level_row.add_child(level_label)
		
		var exp_text = Label.new()
		var exp_needed = GameData.get_exp_for_next_level()
		exp_text.text = "经验 %d/%d" % [GameData.player_exp, exp_needed]
		exp_text.add_theme_font_size_override("font_size", 13)
		level_row.add_child(exp_text)
		
		status_panel_content.add_child(level_row)
		
		# 经验条
		var exp_bar_bg = ColorRect.new()
		exp_bar_bg.color = Color(0.15, 0.15, 0.2)
		exp_bar_bg.custom_minimum_size = Vector2(0, 10)
		status_panel_content.add_child(exp_bar_bg)
		
		var exp_bar_fill = ColorRect.new()
		exp_bar_fill.color = Color(0.3, 0.6, 1.0)
		exp_bar_fill.custom_minimum_size = Vector2(0, 10)
		exp_bar_fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var ratio = float(GameData.player_exp) / float(exp_needed) if exp_needed > 0 else 0.0
		exp_bar_bg.add_child(exp_bar_fill)
		exp_bar_fill.anchor_right = ratio
		exp_bar_fill.anchor_bottom = 1.0
		exp_bar_fill.grow_horizontal = Control.GROW_DIRECTION_BOTH
		exp_bar_fill.grow_vertical = Control.GROW_DIRECTION_BOTH
		
		# 属性点显示
		var points_row = HBoxContainer.new()
		points_row.add_theme_constant_override("separation", 8)
		var points_label = Label.new()
		points_label.text = "可用属性点：%d" % GameData.player_attribute_points
		points_label.add_theme_font_size_override("font_size", 14)
		if GameData.player_attribute_points > 0:
			points_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		points_row.add_child(points_label)
		status_panel_content.add_child(points_row)
	
	_add_panel_separator()
	
	var info_grid = GridContainer.new()
	info_grid.columns = 6
	info_grid.add_theme_constant_override("h_separation", 8)
	info_grid.add_theme_constant_override("v_separation", 6)
	
	if GameData:
		# 生命 + 加点按钮（静默刷新，无动画）
		_add_stat_label(info_grid, "生命")
		_add_stat_value_with_btn(info_grid, "%d/%d" % [GameData.player_current_hp, GameData.player_max_hp], func():
			if GameData.use_attribute_point_hp():
				for child in status_panel_content.get_children():
					child.queue_free()
				_build_status_panel_content()
		)
		
		# 力量 + 加点按钮
		_add_stat_label(info_grid, "力量")
		_add_stat_value_with_btn(info_grid, "%d" % GameData.player_strength, func():
			if GameData.use_attribute_point_strength():
				for child in status_panel_content.get_children():
					child.queue_free()
				_build_status_panel_content()
		)
		
		# 敏捷 + 加点按钮
		_add_stat_label(info_grid, "敏捷")
		_add_stat_value_with_btn(info_grid, "%d" % GameData.player_dexterity, func():
			if GameData.use_attribute_point_dexterity():
				for child in status_panel_content.get_children():
					child.queue_free()
				_build_status_panel_content()
		)
		
		# 其他只读属性
		_add_stat_cell(info_grid, "金币", "%d" % GameData.gold)
		_add_stat_cell(info_grid, "胜场", "%d" % GameData.battles_won)
		_add_stat_cell(info_grid, "卡组", "%d张" % GameData.player_deck.size())
	status_panel_content.add_child(info_grid)
	
	_add_panel_separator()
	
	if GameData:
		var deck_label = Label.new()
		deck_label.text = "卡组"
		deck_label.add_theme_font_size_override("font_size", 15)
		status_panel_content.add_child(deck_label)
		
		var deck_scroll = ScrollContainer.new()
		deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		deck_scroll.custom_minimum_size = Vector2(0, 100)
		
		var deck_flow = HFlowContainer.new()
		deck_flow.add_theme_constant_override("h_separation", 8)
		deck_flow.add_theme_constant_override("v_separation", 6)
		deck_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		for card in GameData.player_deck:
			var card_bg = PanelContainer.new()
			var card_style = StyleBoxFlat.new()
			card_style.bg_color = Color(0.12, 0.12, 0.2, 0.8)
			card_style.set_corner_radius_all(4)
			card_style.set_content_margin_all(6)
			card_bg.add_theme_stylebox_override("panel", card_style)
			card_bg.custom_minimum_size = Vector2(80, 32)
			
			var card_label = Label.new()
			card_label.text = card.name
			card_label.add_theme_font_size_override("font_size", 12)
			if card.is_upgraded:
				card_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			card_bg.add_child(card_label)
			
			deck_flow.add_child(card_bg)
		
		deck_scroll.add_child(deck_flow)
		status_panel_content.add_child(deck_scroll)

func _add_stat_cell(grid: GridContainer, stat_name: String, value: String) -> void:
	var name_label = Label.new()
	name_label.text = stat_name
	name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	name_label.add_theme_font_size_override("font_size", 13)
	grid.add_child(name_label)
	
	var value_label = Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 15)
	grid.add_child(value_label)

## 添加属性标签（只读）
func _add_stat_label(grid: GridContainer, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	label.add_theme_font_size_override("font_size", 13)
	grid.add_child(label)

## 添加属性值 + 加点按钮（在 GridContainer 中占一列）
func _add_stat_value_with_btn(grid: GridContainer, value_text: String, on_pressed: Callable) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	
	var value_label = Label.new()
	value_label.text = value_text
	value_label.add_theme_font_size_override("font_size", 15)
	hbox.add_child(value_label)
	
	if GameData and GameData.player_attribute_points > 0:
		var add_btn = Button.new()
		add_btn.text = "+"
		add_btn.custom_minimum_size = Vector2(24, 24)
		add_btn.add_theme_font_size_override("font_size", 14)
		add_btn.pressed.connect(on_pressed)
		hbox.add_child(add_btn)
	
	grid.add_child(hbox)

func _show_deck_workbench() -> void:
	var popup = PopupPanel.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.16, 1.0)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	popup.add_theme_stylebox_override("panel", style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	
	var title = Label.new()
	title.text = "卡组工作台"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	main_vbox.add_child(HSeparator.new())
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	
	var deck_vbox = VBoxContainer.new()
	deck_vbox.add_theme_constant_override("separation", 4)
	var deck_title = Label.new()
	deck_title.text = "当前卡组"
	deck_title.add_theme_font_size_override("font_size", 14)
	deck_vbox.add_child(deck_title)
	
	var deck_scroll = ScrollContainer.new()
	deck_scroll.custom_minimum_size = Vector2(200, 280)
	deck_vbox.add_child(deck_scroll)
	
	var deck_list = VBoxContainer.new()
	deck_list.add_theme_constant_override("separation", 2)
	deck_scroll.add_child(deck_list)
	
	var card_db = CardDatabase.new()
	var deck = GameData.player_deck
	var deck_counts: Dictionary = {}
	for card in deck:
		if not card.id.is_empty():
			deck_counts[card.id] = deck_counts.get(card.id, 0) + 1
	
	for card_id in deck_counts:
		var card_data = card_db.get_card(card_id)
		var card_name = card_data.name if card_data else card_id
		var count = deck_counts[card_id]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lbl = Label.new()
		lbl.text = "%s ×%d" % [card_name, count]
		lbl.custom_minimum_size = Vector2(120, 0)
		row.add_child(lbl)
		var remove_btn = Button.new()
		remove_btn.text = "-"
		remove_btn.custom_minimum_size = Vector2(28, 24)
		remove_btn.pressed.connect(_on_deck_remove_card.bind(card_id, popup))
		row.add_child(remove_btn)
		deck_list.add_child(row)
	
	var deck_size_label = Label.new()
	deck_size_label.text = "共 %d 张" % deck.size()
	deck_vbox.add_child(deck_size_label)
	hbox.add_child(deck_vbox)
	
	var lib_vbox = VBoxContainer.new()
	lib_vbox.add_theme_constant_override("separation", 4)
	var lib_title = Label.new()
	lib_title.text = "卡池（永久）"
	lib_title.add_theme_font_size_override("font_size", 14)
	lib_vbox.add_child(lib_title)
	
	var lib_scroll = ScrollContainer.new()
	lib_scroll.custom_minimum_size = Vector2(200, 280)
	lib_vbox.add_child(lib_scroll)
	
	var lib_list = VBoxContainer.new()
	lib_list.add_theme_constant_override("separation", 2)
	lib_scroll.add_child(lib_list)
	
	var all_ids = CardPoolManager.get_all_card_ids()
	for cid in all_ids:
		var card_data = card_db.get_card(cid)
		if not card_data:
			continue
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lbl = Label.new()
		lbl.text = card_data.name
		lbl.custom_minimum_size = Vector2(120, 0)
		row.add_child(lbl)
		var add_btn = Button.new()
		add_btn.text = "+"
		add_btn.custom_minimum_size = Vector2(28, 24)
		add_btn.pressed.connect(_on_deck_add_card.bind(cid, popup))
		row.add_child(add_btn)
		lib_list.add_child(row)
	
	hbox.add_child(lib_vbox)
	main_vbox.add_child(hbox)
	main_vbox.add_child(HSeparator.new())
	
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(200, 36)
	close_btn.pressed.connect(func(): popup.hide())
	main_vbox.add_child(close_btn)
	
	popup.add_child(main_vbox)
	add_child(popup)
	popup.popup_centered()

func _on_deck_add_card(card_id: String, popup: PopupPanel) -> void:
	var card_db = CardDatabase.new()
	var card = card_db.get_card(card_id)
	if card and GameData:
		var count = 0
		for c in GameData.player_deck:
			if c.id == card_id:
				count += 1
		if count >= 3:
			return
		GameData.add_card_to_deck(card.duplicate())
		popup.hide()
		_show_deck_workbench()

func _count_card_in_deck(card_id: String) -> int:
	if not GameData:
		return 0
	var count = 0
	for c in GameData.player_deck:
		if c.id == card_id:
			count += 1
	return count

func _open_chest_reward(layer: int) -> void:
	if not GameData:
		return
	# 宝箱只给金币奖励，卡牌需通过战斗胜利等途径获取
	var gold = randi() % 20 + 5 + layer * 2  ## 基础5-24金币，随层数递增
	GameData.add_gold(gold)
	map_controller.map_state.add_log("chest", "宝箱中获得了%d金币。" % gold)

func _on_deck_remove_card(card_id: String, popup: PopupPanel) -> void:
	if not GameData:
		return
	var deck = GameData.player_deck
	for card in deck:
		if card.id == card_id:
			GameData.remove_card_from_deck(card)
			break
	popup.hide()
	_show_deck_workbench()

func _add_panel_separator() -> void:
	var sep = HSeparator.new()
	status_panel_content.add_child(sep)

func _show_settings_dialog() -> void:
	var popup = PopupPanel.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.16, 1.0)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var title = Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	var save_menu_btn = Button.new()
	save_menu_btn.text = "保存并返回主菜单"
	save_menu_btn.custom_minimum_size = Vector2(220, 36)
	save_menu_btn.pressed.connect(func(): popup.hide(); SaveManager.save_map_state(); GameManager.go_to_main_menu())
	vbox.add_child(save_menu_btn)
	
	var save_exit_btn = Button.new()
	save_exit_btn.text = "保存并退出游戏"
	save_exit_btn.custom_minimum_size = Vector2(220, 36)
	save_exit_btn.pressed.connect(func(): popup.hide(); SaveManager.save_map_state(); get_tree().quit())
	vbox.add_child(save_exit_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(220, 36)
	cancel_btn.pressed.connect(func(): popup.hide())
	vbox.add_child(cancel_btn)
	
	popup.add_child(vbox)
	add_child(popup)
	popup.popup_centered()

func _on_battle_requested(enemy_id: String):
	battle_requested.emit(enemy_id)

func _on_battle_request_internal(enemy_id: String):
	if enemy_id.is_empty():
		return
	
	var enemy_db = EnemyDatabase.new()
	var enemy = enemy_db.get_enemy(enemy_id)
	if enemy:
		SaveManager.save_before_battle(enemy_id, map_controller.map_state.current_map_id)
		GameManager.start_battle([enemy], map_controller.test_mode)

## 启动群体战斗（支持多个敌人ID）
func _start_group_battle(enemy_ids: Array, layer: int) -> void:
	if enemy_ids.is_empty():
		return
	
	var enemy_db = EnemyDatabase.new()
	var enemies: Array = []
	for eid in enemy_ids:
		var enemy = enemy_db.get_enemy(eid)
		if enemy:
			enemies.append(enemy)
	
	if enemies.is_empty():
		return
	
	# 保存战斗前存档（使用第一个敌人ID作为标识）
	var primary_id = enemy_ids[0] if enemy_ids.size() > 0 else ""
	var save_map_id = "test" if map_controller.test_mode else "endless"
	if map_controller.endless_mode:
		SaveManager.save_before_battle(primary_id, save_map_id, layer, map_controller.test_mode, map_controller.is_boss_layer(layer))
	else:
		SaveManager.save_before_battle(primary_id, map_controller.map_state.current_map_id, 0)
	
	GameManager.start_battle(enemies, map_controller.test_mode)

func get_map_state() -> Dictionary:
	return map_controller.serialize_state()

func load_map_state(state_data: Dictionary) -> void:
	map_controller.deserialize_state(state_data)


func _on_map_overview_pressed():
	var layout = _compute_overview_layout()
	var regions = _get_regions()

	if regions.is_empty():
		return

	var popup = PopupPanel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.14, 0.98)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)
	popup.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	popup.add_child(vbox)

	var title_bar = HBoxContainer.new()
	var back_btn = Button.new()
	back_btn.text = "<- 返回"
	back_btn.custom_minimum_size = Vector2(60, 28)
	back_btn.visible = false
	title_bar.add_child(back_btn)

	var title_lbl = Label.new()
	title_lbl.text = "世界地图"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(func(): popup.hide())
	title_bar.add_child(close_btn)
	vbox.add_child(title_bar)
	vbox.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vbox.add_child(scroll)

	var canvas: Control = null
	var region_layout: Dictionary = {}
	var scale_factor = 1.0
	var panning = false
	var pan_start_mouse = Vector2.ZERO
	var pan_start_canvas_pos = Vector2.ZERO
	var in_region = false



	var show_region = func(region_id: String):
		var region_name = region_id
		var region_ids: Array = []
		for r in regions:
			if r.id == region_id:
				region_name = r.name
				region_ids = r.locations.duplicate()
				break

		var new_layout = _compute_overview_layout(region_ids)
		region_layout.clear()
		region_layout.merge(new_layout)

		for c in scroll.get_children():
			scroll.remove_child(c)
			c.queue_free()
		canvas = null

		back_btn.visible = true
		title_lbl.text = region_name
		in_region = true

		if region_layout.positions.is_empty():
			var empty_lbl = Label.new()
			empty_lbl.text = "该区域没有可显示的地点"
			scroll.add_child(empty_lbl)
			return

		var base_zoom = _compute_fit_zoom(region_layout, 660, 460)
		canvas = _build_overview_map(region_layout, base_zoom)
		canvas.position = Vector2.ZERO
		canvas.scale = Vector2(1, 1)
		scale_factor = 1.0
		canvas.mouse_filter = Control.MOUSE_FILTER_STOP
		canvas.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				var pressed = event.is_pressed()
				if event.button_index == MOUSE_BUTTON_WHEEL_UP and pressed:
					var old_scale = scale_factor
					scale_factor = clampf(scale_factor * 1.08, 0.2, 4.0)
					var vp_size = scroll.size
					var center = vp_size / 2.0
					var map_local = (center - canvas.position) / old_scale
					canvas.scale = Vector2(scale_factor, scale_factor)
					canvas.position = center - map_local * scale_factor
					canvas.accept_event()
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and pressed:
					var old_scale = scale_factor
					scale_factor = clampf(scale_factor / 1.08, 0.2, 4.0)
					var vp_size = scroll.size
					var center = vp_size / 2.0
					var map_local = (center - canvas.position) / old_scale
					canvas.scale = Vector2(scale_factor, scale_factor)
					canvas.position = center - map_local * scale_factor
					canvas.accept_event()
				elif event.button_index == MOUSE_BUTTON_LEFT:
					if pressed:
						panning = true
						pan_start_mouse = Vector2(event.position.x, event.position.y)
						pan_start_canvas_pos = canvas.position
					else:
						panning = false
					canvas.accept_event()
			if event is InputEventMouseMotion and panning:
				var delta = Vector2(event.position.x, event.position.y) - pan_start_mouse
				canvas.position = pan_start_canvas_pos + delta * scale_factor
		)
		scroll.add_child(canvas)

	var show_world = func():
		for c in scroll.get_children():
			scroll.remove_child(c)
			c.queue_free()
		canvas = null

		back_btn.visible = false
		title_lbl.text = "世界地图"
		in_region = false

		var world_vbox = VBoxContainer.new()
		world_vbox.add_theme_constant_override("separation", 10)
		world_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		for r in regions:
			var entry = PanelContainer.new()
			var entry_style = StyleBoxFlat.new()
			entry_style.bg_color = Color(0.12, 0.12, 0.2, 0.8)
			entry_style.set_corner_radius_all(4)
			entry_style.set_content_margin_all(12)
			entry.add_theme_stylebox_override("panel", entry_style)
			entry.custom_minimum_size = Vector2(0, 50)
			entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var entry_hbox = HBoxContainer.new()
			var name_lbl = Label.new()
			name_lbl.text = r.name
			name_lbl.add_theme_font_size_override("font_size", 16)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			entry_hbox.add_child(name_lbl)

			var enter_btn = Button.new()
			enter_btn.text = "进入"
			enter_btn.pressed.connect(show_region.bind(r.id))
			entry_hbox.add_child(enter_btn)

			entry.add_child(entry_hbox)
			world_vbox.add_child(entry)

		scroll.add_child(world_vbox)

	back_btn.pressed.connect(show_world)
	show_world.call()

	add_child(popup)
	popup.popup_centered(Vector2i(700, 520))

func _get_regions() -> Array:
	var map_data = map_controller.current_map_data
	return map_data.get("regions", [])


func _build_overview_map(layout: Dictionary, zoom: float) -> Control:
	var positions = layout.positions
	var connections = layout.connections
	var locations = layout.locations
	var map_state_data = map_controller.map_state

	if positions.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "地图数据不可用"
		return empty_lbl

	var min_x = 0
	var max_x = 0
	var min_y = 0
	var max_y = 0
	for grid_pos in positions.values():
		min_x = mini(min_x, grid_pos.x)
		max_x = maxi(max_x, grid_pos.x)
		min_y = mini(min_y, grid_pos.y)
		max_y = maxi(max_y, grid_pos.y)

	var ov_btn_w := int(120 * zoom)
	var ov_btn_h := int(40 * zoom)
	var ov_gap_x := int(80 * zoom)
	var ov_gap_y := int(60 * zoom)
	var font_size := maxi(int(13 * zoom), 8)

	var grid_w = max_x - min_x + 1
	var grid_h = max_y - min_y + 1
	var canvas_w = grid_w * (ov_btn_w + ov_gap_x) + ov_gap_x
	var canvas_h = grid_h * (ov_btn_h + ov_gap_y) + ov_gap_y

	var canvas = Control.new()
	canvas.custom_minimum_size = Vector2(canvas_w, canvas_h)

	var grid_offset = Vector2(
		-min_x * (ov_btn_w + ov_gap_x) + ov_gap_x / 2,
		-min_y * (ov_btn_h + ov_gap_y) + ov_gap_y / 2
	)

	var current_id = map_state_data.current_location_id
	var visited_ids = map_state_data.visited_locations

	var drawn_pairs := []
	for conn in connections:
		var from_grid = positions.get(conn.from)
		var to_grid = positions.get(conn.to)
		if from_grid == null or to_grid == null:
			continue
		var pkey = conn.from + ":" + conn.to
		var rkey = conn.to + ":" + conn.from
		if drawn_pairs.has(pkey) or drawn_pairs.has(rkey):
			continue
		drawn_pairs.append(pkey)

		var from_pixel = Vector2(from_grid) * Vector2(ov_btn_w + ov_gap_x, ov_btn_h + ov_gap_y) + grid_offset + Vector2(ov_btn_w / 2, ov_btn_h / 2)
		var to_pixel = Vector2(to_grid) * Vector2(ov_btn_w + ov_gap_x, ov_btn_h + ov_gap_y) + grid_offset + Vector2(ov_btn_w / 2, ov_btn_h / 2)

		var line = Line2D.new()
		line.points = [from_pixel, to_pixel]
		line.width = maxf(1.0, 2.0 * zoom)
		line.default_color = Color(0.35, 0.35, 0.45, 0.5)
		canvas.add_child(line)

	for loc_id in positions:
		var grid_pos = positions[loc_id]
		var pixel_pos = Vector2(grid_pos) * Vector2(ov_btn_w + ov_gap_x, ov_btn_h + ov_gap_y) + grid_offset

		var loc_data = locations.get(loc_id, {})
		var is_visited = visited_ids.has(loc_id)
		var is_current = loc_id == current_id

		var bg = ColorRect.new()
		bg.size = Vector2(ov_btn_w, ov_btn_h)
		bg.position = pixel_pos
		if is_current:
			bg.color = Color(0.3, 0.25, 0.1, 0.9)
		elif is_visited:
			bg.color = Color(0.12, 0.12, 0.2, 0.85)
		else:
			bg.color = Color(0.08, 0.08, 0.12, 0.6)
		canvas.add_child(bg)

		var border = ColorRect.new()
		border.size = Vector2(ov_btn_w, ov_btn_h)
		border.position = pixel_pos
		border.color = Color.TRANSPARENT
		if is_current:
			border.color = Color(1, 0.8, 0.2, 0.8)
		elif is_visited:
			border.color = Color(0.4, 0.4, 0.5, 0.3)
		else:
			border.color = Color(0.2, 0.2, 0.25, 0.2)
		canvas.add_child(border)

		var lbl = Label.new()
		if is_visited:
			lbl.text = loc_data.get("name", loc_id)
		else:
			lbl.text = "???"
		lbl.position = pixel_pos + Vector2(6, (ov_btn_h - font_size) / 2)
		lbl.add_theme_font_size_override("font_size", font_size)
		if is_current:
			lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		elif is_visited:
			lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		else:
			lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		canvas.add_child(lbl)

	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in canvas.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return canvas


func _compute_fit_zoom(layout: Dictionary, avail_w: int, avail_h: int) -> float:
	var positions = layout.positions
	if positions.is_empty():
		return 1.0
	var min_x = 0
	var max_x = 0
	var min_y = 0
	var max_y = 0
	for grid_pos in positions.values():
		if grid_pos.x < 900:
			min_x = mini(min_x, grid_pos.x)
			max_x = maxi(max_x, grid_pos.x)
			min_y = mini(min_y, grid_pos.y)
			max_y = maxi(max_y, grid_pos.y)
	var grid_w = max_x - min_x + 1
	var grid_h = max_y - min_y + 1
	if grid_w <= 0 or grid_h <= 0:
		return 1.0
	var zoom_w = float(avail_w - 40) / float(grid_w * 200)
	var zoom_h = float(avail_h - 40) / float(grid_h * 100)
	return clampf(min(zoom_w, zoom_h), 0.25, 2.0)


func _compute_overview_layout(valid_ids: Array = []) -> Dictionary:
	var map_data = map_controller.current_map_data
	var all_locations = map_data.get("locations", {})
	var current_id = map_controller.map_state.current_location_id
	var use_filter = not valid_ids.is_empty()

	if use_filter and not valid_ids.has(current_id):
		if valid_ids.is_empty():
			return {"positions": {}, "connections": [], "locations": {}}
		current_id = valid_ids[0]

	var positions := {}
	var connections := []
	var enqueued := []
	var queue := []

	if all_locations.has(current_id):
		queue.push_back([current_id, Vector2i(0, 0)])
		enqueued.append(current_id)

	var dir_grid := {
		"north": Vector2i(0, -1),
		"south": Vector2i(0, 1),
		"east": Vector2i(1, 0),
		"west": Vector2i(-1, 0),
		"north_east": Vector2i(1, -1),
		"north_west": Vector2i(-1, -1),
		"south_east": Vector2i(1, 1),
		"south_west": Vector2i(-1, 1)
	}

	while queue.size() > 0:
		var entry = queue.pop_front()
		var lid = entry[0]
		var gpos = entry[1]

		if positions.has(lid):
			continue
		positions[lid] = gpos

		var loc_data = all_locations.get(lid, {})
		var conns = loc_data.get("connections", {})

		for dname in conns:
			var tid = conns[dname]
			if use_filter and not valid_ids.has(tid):
				continue
			var goff = dir_grid.get(dname, Vector2i(0, 0))
			var tpos = gpos + goff

			connections.append({"from": lid, "to": tid})
			if not enqueued.has(tid):
				enqueued.append(tid)
				queue.push_back([tid, tpos])

	var all_location_ids = valid_ids if use_filter else all_locations.keys()
	for lid in all_location_ids:
		if not positions.has(lid):
			positions[lid] = Vector2i(999, 999)

	return {"positions": positions, "connections": connections, "locations": all_locations}
