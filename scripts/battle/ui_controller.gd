class_name UIController

var root_node: Control
var card_scene: PackedScene
var player_manager: PlayerManager = null

var hand_container: Node
var enemy_container: Node
var player_area: Node
var end_turn_button: Button
var deck_info_node: Node
var state_display_label: Label = null
var target_button: Button = null
var target_marker: Control = null

var drag_arrow: DragArrow = null
var is_dragging: bool = false
var dragging_card: CardData = null
var drag_card_node: Control = null
var last_hand: Array = []
var is_selecting_target: bool = false

var current_hand_cards: Dictionary = {}
var current_enemy_nodes: Dictionary = {}
var selected_target = null
var current_target_index: int = 0

signal card_clicked(card: CardData, card_node: Control)
signal card_released(card: CardData, card_node: Control)
signal card_cancelled(card: CardData)
signal card_dropped(card: CardData, target)
signal enemy_selected(enemy: EnemyUnit)
signal end_turn_clicked()
signal attack_target_selected(enemy: EnemyUnit)

func _init(root: Control):
	root_node = root
	_find_ui_nodes()
	_setup_signals()
	_load_card_scene()
	_setup_state_display()
	_setup_drag_arrow()
	_setup_target_button()
	_setup_target_marker()

func _setup_state_display() -> void:
	state_display_label = Label.new()
	state_display_label.name = "StateDisplay"
	state_display_label.add_theme_font_size_override("font_size", 32)
	state_display_label.add_theme_color_override("font_color", Color.WHITE)
	state_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_display_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_display_label.set_anchors_preset(Control.PRESET_CENTER)
	state_display_label.position = Vector2(-100, -150)
	state_display_label.visible = false
	root_node.add_child(state_display_label)

func _setup_drag_arrow() -> void:
	drag_arrow = DragArrow.new()
	drag_arrow.name = "DragArrow"
	root_node.add_child(drag_arrow)

func _setup_target_button() -> void:
	if end_turn_button == null:
		return
	
	target_button = Button.new()
	target_button.name = "TargetButton"
	target_button.text = "攻击目标"
	target_button.custom_minimum_size = Vector2(120, 40)
	
	var button_pos = end_turn_button.position
	target_button.position = Vector2(button_pos.x, button_pos.y - 50)
	
	target_button.pressed.connect(_on_target_button_pressed)
	root_node.add_child(target_button)

func _setup_target_marker() -> void:
	target_marker = Control.new()
	target_marker.name = "TargetMarker"
	target_marker.set_script(load("res://scripts/ui/target_marker.gd"))
	root_node.add_child(target_marker)

func _on_target_button_pressed() -> void:
	if is_selecting_target:
		cancel_target_selection()
	else:
		start_target_selection()

func start_target_selection() -> void:
	is_selecting_target = true
	highlight_all_enemies()
	drag_arrow.show_arrow()
	
	if target_button:
		target_button.text = "取消选择"
	
	show_state_message("请选择攻击目标", 1.0)

func cancel_target_selection() -> void:
	is_selecting_target = false
	clear_target_highlights()
	drag_arrow.hide_arrow()
	
	if target_button:
		target_button.text = "攻击目标"
	
	show_state_message("已取消", 0.5)

func highlight_all_enemies() -> void:
	for enemy in current_enemy_nodes:
		var enemy_node = current_enemy_nodes[enemy]
		if enemy_node.has_method("set_highlight_for_target"):
			enemy_node.set_highlight_for_target(true)

func select_attack_target(enemy: EnemyUnit) -> void:
	if not is_selecting_target:
		return
	
	var index = 0
	var enemies = current_enemy_nodes.keys()
	for i in range(enemies.size()):
		if enemies[i] == enemy:
			index = i
			break
	
	current_target_index = index
	if player_manager:
		player_manager.set_selected_target(index)
	
	is_selecting_target = false
	clear_target_highlights()
	drag_arrow.hide_arrow()
	
	if target_button:
		target_button.text = "攻击目标"
	
	update_target_marker(enemy)
	attack_target_selected.emit(enemy)
	show_state_message("已选择目标", 0.5)

func update_target_marker(enemy: EnemyUnit) -> void:
	if target_marker == null:
		return
	
	var enemy_node = current_enemy_nodes.get(enemy)
	if enemy_node:
		if target_marker.has_method("set_target"):
			target_marker.call("set_target", enemy_node)

func clear_target_marker() -> void:
	if target_marker and target_marker.has_method("clear"):
		target_marker.call("clear")

func show_state_message(message: String, duration: float = 1.0) -> void:
	if state_display_label == null:
		return
	
	state_display_label.text = message
	state_display_label.visible = true
	state_display_label.modulate = Color.WHITE
	
	var tween = root_node.create_tween()
	tween.tween_interval(duration)
	tween.tween_property(state_display_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): state_display_label.visible = false)

func _find_ui_nodes() -> void:
	hand_container = root_node.get_node_or_null("Background/HandArea")
	enemy_container = root_node.get_node_or_null("Background/EnemyArea")
	player_area = root_node.get_node_or_null("Background/PlayerArea")
	end_turn_button = root_node.get_node_or_null("EndTurnButton")
	deck_info_node = root_node.get_node_or_null("DeckInfo")
	
	if player_area:
		player_area.gui_input.connect(_on_player_area_input)

func _setup_signals() -> void:
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)

func _load_card_scene() -> void:
	card_scene = load("res://scenes/Card.tscn")

func update_hand_display(hand: Array) -> void:
	last_hand = hand.duplicate()
	var hand_size = hand.size()
	if hand_size == 0:
		_clear_hand()
		return
	
	var container_width: float = 800.0
	if hand_container and hand_container.get_parent():
		container_width = hand_container.get_parent().size.x - hand_container.position.x - 50
	
	var new_positions = {}
	var new_rotations = {}
	
	for i in range(hand_size):
		var card = hand[i]
		var card_data = HandLayoutPresets.get_card_position(i, hand_size, container_width)
		new_positions[card] = card_data.position
		new_rotations[card] = card_data.rotation
	
	for card in current_hand_cards.keys():
		if not hand.has(card):
			var node = current_hand_cards[card]
			node.queue_free()
			current_hand_cards.erase(card)
	
	for i in range(hand_size):
		var card = hand[i]
		var card_node: Control
		
		if current_hand_cards.has(card):
			card_node = current_hand_cards[card]
		else:
			card_node = _create_card_node(card)
			if card_node:
				hand_container.add_child(card_node)
				current_hand_cards[card] = card_node
				_setup_card_interaction(card_node, card)
		
		if card_node and new_positions.has(card):
			var target_pos = new_positions[card]
			var target_rotation = new_rotations[card]
			
			var should_animate = true
			if card_node.has_method("is_in_target_mode") and card_node.is_in_target_mode():
				should_animate = false
			if card_node.has_method("is_dragging_card") and card_node.is_dragging_card():
				should_animate = false
			
			if should_animate:
				_animate_card_to_position(card_node, target_pos, target_rotation)
			
			if card_node.has_method("set_original_position"):
				card_node.call("set_original_position", target_pos)

func _animate_card_to_position(card_node: Control, target_pos: Vector2, target_rotation: float) -> void:
	var current_pos = card_node.position
	var current_rotation = card_node.rotation_degrees
	
	if current_pos.distance_to(target_pos) < 1.0 and abs(current_rotation - target_rotation) < 0.5:
		card_node.position = target_pos
		card_node.rotation_degrees = target_rotation
		return
	
	var tween = root_node.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card_node, "position", target_pos, 0.25)
	tween.tween_property(card_node, "rotation_degrees", target_rotation, 0.25)

func _clear_hand() -> void:
	for card_node in current_hand_cards.values():
		card_node.queue_free()
	current_hand_cards.clear()

func _create_card_node(card: CardData) -> Control:
	if card_scene == null:
		return null
	
	var card_node = card_scene.instantiate() as Control
	
	if card_node.has_method("setup"):
		card_node.setup(card, player_manager)
		card_node.card_clicked.connect(_on_card_ui_clicked)
	else:
		var name_label = card_node.get_node_or_null("NameLabel")
		var desc_label = card_node.get_node_or_null("DescLabel")
		var type_label = card_node.get_node_or_null("TypeLabel")
		
		if name_label:
			name_label.text = card.name
		if desc_label:
			desc_label.text = card.get_description_text()
		if type_label:
			type_label.text = _get_type_text(card.type)
	
	return card_node

func _get_type_text(type: String) -> String:
	match type:
		"attack": return "攻击"
		"skill": return "技能"
		"power": return "能力"
		_: return ""

func _setup_card_interaction(card_node: Control, card: CardData) -> void:
	if card_node.has_signal("drag_started"):
		card_node.drag_started.connect(_on_card_drag_started.bind(card_node))
		card_node.drag_updated.connect(_on_card_drag_updated)
		card_node.drag_ended.connect(_on_card_drag_ended)
	if card_node.has_signal("card_released"):
		card_node.card_released.connect(_on_card_released.bind(card_node))
	if card_node.has_signal("card_cancelled"):
		card_node.card_cancelled.connect(_on_card_cancelled)
	if card_node.has_signal("target_mode_started"):
		card_node.target_mode_started.connect(_on_target_mode_started)
	if card_node.has_signal("target_mode_ended"):
		card_node.target_mode_ended.connect(_on_target_mode_ended)
	if not card_node.has_method("setup"):
		card_node.gui_input.connect(_on_card_gui_input.bind(card, card_node))

func _on_card_gui_input(event: InputEvent, card: CardData, card_node: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(card, card_node)

func _on_card_ui_clicked(card: CardData) -> void:
	card_clicked.emit(card, null)

func update_enemy_display(enemies: Array) -> void:
	_clear_enemies()
	
	for child in enemy_container.get_children():
		child.queue_free()
	
	for enemy in enemies:
		var enemy_node = _create_enemy_node(enemy)
		if enemy_node:
			enemy_container.add_child(enemy_node)
			current_enemy_nodes[enemy] = enemy_node
	
	if current_target_index >= enemies.size():
		current_target_index = 0
	
	if enemies.size() > 0 and current_target_index < enemies.size():
		var target_enemy = enemies[current_target_index]
		update_target_marker(target_enemy)

func _clear_enemies() -> void:
	for enemy_node in current_enemy_nodes.values():
		enemy_node.queue_free()
	current_enemy_nodes.clear()

func _create_enemy_node(enemy: EnemyUnit) -> Control:
	var enemy_scene_path = "res://scenes/EnemyUI.tscn"
	var enemy_node: Control = null
	
	if ResourceLoader.exists(enemy_scene_path):
		var enemy_scene = load(enemy_scene_path)
		enemy_node = enemy_scene.instantiate() as Control
		
		if enemy_node.has_method("setup"):
			enemy_node.setup(enemy)
			enemy_node.enemy_selected.connect(_on_enemy_ui_selected)
	else:
		enemy_node = Control.new()
		enemy_node.custom_minimum_size = Vector2(150, 200)
		
		var name_label = Label.new()
		name_label.text = enemy.get_name()
		name_label.position = Vector2(0, 0)
		enemy_node.add_child(name_label)
		
		var hp_label = Label.new()
		hp_label.name = "HPLabel"
		hp_label.text = "%d/%d" % [enemy.current_hp, enemy.max_hp]
		hp_label.position = Vector2(0, 30)
		enemy_node.add_child(hp_label)
		
		var hp_bar = ProgressBar.new()
		hp_bar.name = "HPBar"
		hp_bar.max_value = enemy.max_hp
		hp_bar.value = enemy.current_hp
		hp_bar.position = Vector2(0, 60)
		hp_bar.custom_minimum_size = Vector2(100, 20)
		enemy_node.add_child(hp_bar)
		
		enemy_node.gui_input.connect(_on_enemy_gui_input.bind(enemy))
	
	return enemy_node

func _on_enemy_ui_selected(enemy: EnemyUnit) -> void:
	selected_target = enemy
	enemy_selected.emit(enemy)
	
	if is_selecting_target:
		select_attack_target(enemy)
		return
	
	if is_dragging and dragging_card:
		card_dropped.emit(dragging_card, enemy)
		is_dragging = false
		drag_arrow.hide_arrow()
		clear_target_highlights()
		dragging_card = null
		drag_card_node = null

func _on_enemy_gui_input(event: InputEvent, enemy: EnemyUnit) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_target = enemy
		enemy_selected.emit(enemy)

func update_single_enemy(enemy: EnemyUnit) -> void:
	if current_enemy_nodes.has(enemy):
		var node = current_enemy_nodes[enemy]
		var hp_label = node.get_node_or_null("HPLabel")
		var hp_bar = node.get_node_or_null("HPBar")
		
		if hp_label:
			hp_label.text = "%d/%d" % [enemy.current_hp, enemy.max_hp]
		if hp_bar:
			hp_bar.value = enemy.current_hp

func update_player_display(hp: int, max_hp: int, block: int) -> void:
	if player_area == null:
		return
	
	var hp_label = player_area.get_node_or_null("HPLabel")
	var hp_bar = player_area.get_node_or_null("HPBar")
	var block_label = player_area.get_node_or_null("BlockLabel")
	
	if hp_label:
		hp_label.text = "%d/%d" % [hp, max_hp]
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	if block_label:
		block_label.text = "护甲: %d" % block

func update_deck_info(draw_count: int, discard_count: int) -> void:
	if deck_info_node == null:
		return
	
	var draw_label = deck_info_node.get_node_or_null("DrawPile")
	var discard_label = deck_info_node.get_node_or_null("DiscardPile")
	
	if draw_label:
		draw_label.text = "抽牌堆: %d" % draw_count
	if discard_label:
		discard_label.text = "弃牌堆: %d" % discard_count

func show_damage_number(target, amount: int) -> void:
	if amount <= 0:
		return
	
	var target_node = null
	if target is EnemyUnit and current_enemy_nodes.has(target):
		target_node = current_enemy_nodes[target]
		if target_node.has_method("show_damage_number"):
			target_node.show_damage_number(amount)
			return
	elif target is PlayerManager and player_area:
		target_node = player_area
	
	var damage_label = Label.new()
	damage_label.text = "-%d" % amount
	damage_label.add_theme_color_override("font_color", Color.RED)
	damage_label.add_theme_font_size_override("font_size", 24)
	
	if target_node:
		target_node.add_child(damage_label)
		damage_label.position = Vector2(50, 0)
		
		var tween = root_node.create_tween()
		tween.tween_property(damage_label, "position:y", -30, 0.5)
		tween.tween_callback(damage_label.queue_free)

func show_block_number(target, amount: int) -> void:
	if amount <= 0:
		return

func remove_card_from_hand(card: CardData) -> void:
	if current_hand_cards.has(card):
		var node = current_hand_cards[card]
		node.queue_free()
		current_hand_cards.erase(card)

func highlight_playable_cards(playable: Array) -> void:
	for card in current_hand_cards:
		var node = current_hand_cards[card]
		if node:
			node.modulate = Color.WHITE if card in playable else Color(0.5, 0.5, 0.5)

func set_interactive(enabled: bool) -> void:
	for card_node in current_hand_cards.values():
		card_node.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func _on_end_turn_pressed() -> void:
	end_turn_clicked.emit()

func _on_player_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_player_stats_popup()

func _show_player_stats_popup() -> void:
	if player_manager == null:
		return
	
	var popup = AcceptDialog.new()
	popup.title = "角色属性"
	
	var stats_text = "生命值: %d / %d\n" % [player_manager.current_hp, player_manager.max_hp]
	stats_text += "护甲: %d\n" % player_manager.block
	stats_text += "力量: %d\n" % player_manager.strength
	stats_text += "敏捷: %d" % player_manager.dexterity
	
	popup.dialog_text = stats_text
	root_node.add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(popup.queue_free)
	popup.close_requested.connect(popup.queue_free)

func highlight_valid_targets(card: CardData) -> void:
	clear_target_highlights()
	
	if card == null:
		return
	
	var target_type = card.target_type
	
	if target_type == "single_enemy":
		for enemy_node in current_enemy_nodes.values():
			if enemy_node.has_method("set_highlight_for_target"):
				enemy_node.set_highlight_for_target(true)
	elif target_type == "all_enemies":
		for enemy_node in current_enemy_nodes.values():
			if enemy_node.has_method("set_highlight_for_target"):
				enemy_node.set_highlight_for_target(true)

func clear_target_highlights() -> void:
	for enemy_node in current_enemy_nodes.values():
		if enemy_node.has_method("set_highlight_for_target"):
			enemy_node.set_highlight_for_target(false)
	
	if player_area and player_area.has_method("set_highlight_for_target"):
		player_area.set_highlight_for_target(false)

func play_card_animation(card: CardData, card_node: Control, target = null) -> void:
	if card_node == null:
		return
	
	var target_pos = Vector2(400, 300)
	
	if target and current_enemy_nodes.has(target):
		var enemy_node = current_enemy_nodes[target]
		target_pos = enemy_node.position + enemy_node.size / 2
	
	if card_node.has_method("play_play_animation"):
		card_node.play_play_animation(target_pos)

func _on_card_drag_started(card: CardData, start_pos: Vector2, card_node: Control) -> void:
	is_dragging = true
	dragging_card = card
	drag_card_node = card_node
	
	highlight_valid_targets(card)
	drag_arrow.show_arrow()

func _on_card_drag_updated(card: CardData, current_pos: Vector2) -> void:
	if not is_dragging or drag_card_node == null:
		return
	
	var card_center = drag_card_node.global_position + drag_card_node.size / 2
	drag_arrow.set_points(card_center, current_pos)
	
	var hover_target = _get_target_at_position(current_pos)
	_update_hover_highlight(hover_target)

func _on_card_drag_ended(card: CardData, end_pos: Vector2) -> void:
	if not is_dragging:
		return
	
	var card_node = current_hand_cards.get(card)
	
	var target = _get_target_at_position(end_pos)
	
	if target:
		card_dropped.emit(card, target)
		is_dragging = false
		drag_arrow.hide_arrow()
		clear_target_highlights()
		dragging_card = null
		drag_card_node = null
	else:
		if card_node and card_node.has_method("is_in_target_mode") and card_node.is_in_target_mode():
			pass
		else:
			if card_node and card_node.has_method("reset_position"):
				card_node.reset_position()
			is_dragging = false
			drag_arrow.hide_arrow()
			clear_target_highlights()
			dragging_card = null
			drag_card_node = null
			ensure_cards_layout_state()
			show_state_message("请选择有效目标", 0.5)

func _get_target_at_position(pos: Vector2):
	for enemy in current_enemy_nodes:
		var enemy_node = current_enemy_nodes[enemy]
		var rect = Rect2(enemy_node.global_position, enemy_node.size)
		if rect.has_point(pos):
			return enemy
	
	if player_area:
		var player_rect = Rect2(player_area.global_position, player_area.size)
		if player_rect.has_point(pos):
			return player_manager
	
	return null

func _update_hover_highlight(hover_target) -> void:
	for enemy in current_enemy_nodes:
		var enemy_node = current_enemy_nodes[enemy]
		if enemy_node.has_method("set_highlight_for_target"):
			enemy_node.set_highlight_for_target(enemy == hover_target)
	
	if player_area and player_area.has_method("set_highlight_for_target"):
		player_area.set_highlight_for_target(hover_target == player_manager)

func _on_card_released(card: CardData, card_node: Control) -> void:
	card_released.emit(card, card_node)

func _on_card_cancelled(card: CardData) -> void:
	if is_dragging:
		is_dragging = false
		drag_arrow.hide_arrow()
		clear_target_highlights()
		dragging_card = null
		drag_card_node = null
	
	card_cancelled.emit(card)
	ensure_cards_layout_state()

func _on_target_mode_started(card: CardData) -> void:
	is_dragging = true
	dragging_card = card
	drag_card_node = current_hand_cards.get(card)
	
	highlight_valid_targets(card)
	drag_arrow.show_arrow()

func _on_target_mode_ended(_card: CardData) -> void:
	is_dragging = false
	drag_arrow.hide_arrow()
	clear_target_highlights()
	dragging_card = null
	drag_card_node = null
	
	ensure_cards_layout_state()

func ensure_cards_layout_state() -> void:
	for card in current_hand_cards:
		var card_node = current_hand_cards[card]
		if card_node and card_node.has_method("restore_to_layout_state"):
			card_node.restore_to_layout_state()
	
	if last_hand.size() > 0:
		update_hand_display(last_hand)
