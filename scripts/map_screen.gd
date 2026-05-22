extends Control

var map_controller: MapController

var location_label: Label
var description_label: Label
var status_button: Button
var settings_button: Button
var interactables_container: HBoxContainer
var log_container: VBoxContainer
var interaction_panel: VBoxContainer
var location_info_panel: VBoxContainer

var node_container: Control
var active_nodes: Dictionary = {}
var map_offset: Vector2 = Vector2.ZERO
var is_animating: bool = false

var status_panel: PanelContainer
var status_panel_content: VBoxContainer
var status_panel_open: bool = false
var status_panel_tween: Tween = null
var _scroll_pending: bool = false

const STATUS_PANEL_HEIGHT := 320

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
	if not map_state.is_empty():
		map_controller.deserialize_state(map_state)
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
	SaveManager.save_map_state()

func _on_location_changed(location_data: Dictionary):
	location_label.text = location_data.get("name", "未知地点")
	description_label.text = location_data.get("description", "")
	
	interaction_panel.visible = false
	location_info_panel.visible = true
	
	if not is_animating:
		_update_location_grid()
	_update_interactables()
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
			var enemy_id = result.get("enemy_id", "")
			battle_requested.emit(enemy_id)
		elif result.get("heal_amount", 0) > 0:
			var heal_amount = result.heal_amount
			if GameData:
				GameData.heal(heal_amount)
		
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
	
	var info_grid = GridContainer.new()
	info_grid.columns = 4
	info_grid.add_theme_constant_override("h_separation", 16)
	info_grid.add_theme_constant_override("v_separation", 6)
	
	if GameData:
		_add_stat_cell(info_grid, "生命", "%d/%d" % [GameData.player_current_hp, GameData.player_max_hp])
		_add_stat_cell(info_grid, "力量", "%d" % GameData.player_strength)
		_add_stat_cell(info_grid, "敏捷", "%d" % GameData.player_dexterity)
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
		GameManager.start_battle([enemy])

func get_map_state() -> Dictionary:
	return map_controller.serialize_state()

func load_map_state(state_data: Dictionary) -> void:
	map_controller.deserialize_state(state_data)
