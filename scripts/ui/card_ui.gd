class_name CardUI
extends Control

@onready var background: ColorRect = $Background
@onready var frame: Panel = $Frame
@onready var name_label: Label = $NameLabel
@onready var type_label: Label = $TypeLabel
@onready var desc_label: Label = $DescLabel

var card_data: CardData
var player_manager: PlayerManager
var is_hovered: bool = false
var is_selected: bool = false
var original_position: Vector2
var original_scale: Vector2 = Vector2.ONE
var original_rotation: float = 0.0

var is_dragging: bool = false
var drag_start_pos: Vector2
var is_pressed: bool = false
var press_tween: Tween = null
var mouse_inside: bool = true
var is_awaiting_target: bool = false
var tooltip_panel: PanelContainer = null
var drag_exited_hand: bool = false
var is_select_mode: bool = false

signal card_clicked(card: CardData)
signal card_hovered(card: CardData)
signal card_unhovered(card: CardData)
signal drag_started(card: CardData, start_pos: Vector2)
signal drag_updated(card: CardData, current_pos: Vector2)
signal drag_ended(card: CardData, end_pos: Vector2)
signal card_released(card: CardData)
signal card_cancelled(card: CardData)
signal target_mode_started(card: CardData)
signal target_mode_ended(card: CardData)
signal card_play_requested(card: CardData)

const ATTACK_COLOR := Color(0.9, 0.3, 0.3, 1.0)
const SKILL_COLOR := Color(0.3, 0.5, 0.9, 1.0)
const POWER_COLOR := Color(0.7, 0.4, 0.9, 1.0)
const DEFAULT_COLOR := Color(0.8, 0.8, 0.8, 1.0)

func _ready():
	original_position = position
	_setup_signals()

func _setup_signals():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(card: CardData, pm: PlayerManager = null):
	card_data = card
	player_manager = pm
	
	var bg = get_node_or_null("Background")
	var name_lbl = get_node_or_null("NameLabel")
	var type_lbl = get_node_or_null("TypeLabel")
	var desc_lbl = get_node_or_null("DescLabel")
	
	if name_lbl:
		name_lbl.text = card.name
	
	if type_lbl:
		type_lbl.text = _get_type_text(card.type)
	
	if desc_lbl:
		desc_lbl.text = _get_display_text()
	
	if bg:
		match card.type:
			"attack":
				bg.color = ATTACK_COLOR
			"skill":
				bg.color = SKILL_COLOR
			"power":
				bg.color = POWER_COLOR
			_:
				bg.color = DEFAULT_COLOR
	
	size = Vector2(140, 180)
	original_position = position
	original_scale = scale

func _get_display_text() -> String:
	if card_data == null:
		return ""
	
	for effect in card_data.effects:
		var effect_type = effect.get("effect_type", "")
		var value = effect.get("value", 0)
		
		if effect_type == "temp_damage_boost":
			return "本回合伤害+%d" % value
		
		if effect_type == "damage_boost":
			return "伤害永久+%d" % value
		
		var base_stat = effect.get("base_stat", "")
		var multiplier = effect.get("multiplier", 1.0)
		
		if base_stat != "" and player_manager:
			var stat_value = 0
			if base_stat == "strength":
				stat_value = player_manager.get_strength()
			elif base_stat == "dexterity":
				stat_value = player_manager.get_dexterity()
			
			var final_value = int(stat_value * multiplier)
			
			if effect_type == "damage":
				return "造成 %d 点伤害" % final_value
			elif effect_type == "block":
				return "获得 %d 点护甲" % final_value
	
	return card_data.get_description_text()

func _set_background_color(type: String):
	if background == null:
		return
	
	match type:
		"attack":
			background.color = ATTACK_COLOR
		"skill":
			background.color = SKILL_COLOR
		"power":
			background.color = POWER_COLOR
		_:
			background.color = DEFAULT_COLOR

func _get_type_text(type: String) -> String:
	match type:
		"attack": return "攻击"
		"skill": return "技能"
		"power": return "能力"
		_: return ""

func _animate_hover(hover: bool):
	if is_pressed or is_awaiting_target or is_select_mode:
		return
	
	var target_scale = Vector2(1.12, 1.12) if hover else original_scale
	var target_y = original_position.y - 15 if hover else original_position.y
	var target_modulate = Color(1.15, 1.15, 1.0, 1.0) if hover else Color.WHITE
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", target_scale, 0.1)
	tween.tween_property(self, "position:y", target_y, 0.1)
	tween.tween_property(self, "modulate", target_modulate, 0.1)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if card_data:
					is_pressed = true
					mouse_inside = true
					drag_exited_hand = false
					drag_start_pos = get_global_mouse_position()
					
					if is_awaiting_target:
						cancel_target_mode()
					elif is_select_mode:
						pass
					else:
						_animate_press_down()
				accept_event()
			elif event.is_released():
				if is_pressed:
					is_pressed = false
					
					if is_awaiting_target:
						pass
					elif is_select_mode:
						if mouse_inside:
							card_clicked.emit(card_data)
						is_pressed = false
					elif is_dragging:
						if _needs_target():
							end_drag()
						elif drag_exited_hand:
							card_play_requested.emit(card_data)
							end_drag()
						else:
							_cancel_press()
					elif _needs_target():
						if mouse_inside:
							start_target_mode()
						else:
							_cancel_press()
					else:
						if mouse_inside and not is_dragging:
							card_clicked.emit(card_data)
						_cancel_press()
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_pressed or is_awaiting_target:
				cancel_target_mode()
				is_pressed = false
				is_dragging = false
				card_cancelled.emit(card_data)
			accept_event()

func _input(event: InputEvent):
	if not (is_pressed or is_awaiting_target):
		return
	
	if event is InputEventMouseMotion:
		if is_pressed and not is_dragging and not is_awaiting_target and not is_select_mode:
			var current_pos = get_global_mouse_position()
			var distance = current_pos.distance_to(drag_start_pos)
			if distance > 10.0:
				start_drag()
		
		if is_dragging:
			var global_mouse_pos = get_global_mouse_position()
			if _needs_target():
				pass
			else:
				global_position = global_mouse_pos - size / 2
			drag_updated.emit(card_data, global_mouse_pos)
			if not _needs_target():
				drag_exited_hand = not _is_in_hand_area(global_mouse_pos)
		elif is_awaiting_target:
			var global_mouse_pos = get_global_mouse_position()
			drag_updated.emit(card_data, global_mouse_pos)

func _on_mouse_entered():
	is_hovered = true
	mouse_inside = true
	_animate_hover(true)
	card_hovered.emit(card_data)
	_show_tooltip()

func _on_mouse_exited():
	is_hovered = false
	mouse_inside = false
	_animate_hover(false)
	card_unhovered.emit(card_data)
	_hide_tooltip()

func _needs_target() -> bool:
	if card_data == null:
		return false
	var target_type = card_data.target_type
	return target_type == "single_enemy" or target_type == "single_ally"

func _animate_press_down():
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.08)
	press_tween.tween_property(self, "modulate", Color(1.3, 1.3, 1.0, 1.0), 0.08)
	
	if not _needs_target():
		press_tween.tween_property(self, "position:y", original_position.y - 20, 0.08)

func _animate_press_up():
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "scale", original_scale, 0.1)
	press_tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	if not _needs_target():
		press_tween.tween_property(self, "position:y", original_position.y, 0.1)

func _cancel_press():
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	is_pressed = false
	is_dragging = false
	is_awaiting_target = false
	
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "scale", original_scale, 0.12)
	press_tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	press_tween.tween_property(self, "position", original_position, 0.12)
	press_tween.tween_property(self, "rotation_degrees", 0.0, 0.12)

func start_drag():
	is_dragging = true
	drag_exited_hand = false
	drag_start_pos = get_global_mouse_position()
	drag_started.emit(card_data, drag_start_pos)
	
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)
	press_tween.tween_property(self, "rotation_degrees", 0.0, 0.08)
	
	if _needs_target():
		var vp_size = get_viewport_rect().size
		var center = Vector2(vp_size.x / 2 - size.x / 2, vp_size.y / 2 - size.y / 2 - 50)
		press_tween.tween_property(self, "global_position", center, 0.15)
		press_tween.tween_property(self, "modulate", Color(1.1, 1.1, 1.0, 0.8), 0.15)
	else:
		press_tween.tween_property(self, "modulate", Color(1.1, 1.1, 1.0, 0.85), 0.08)

func _is_in_hand_area(pos: Vector2) -> bool:
	var parent = get_parent()
	if parent == null:
		return false
	var hand_rect = parent.get_global_rect()
	return hand_rect.has_point(pos)
	
func end_drag():
	is_dragging = false
	drag_exited_hand = false
	var end_pos = get_global_mouse_position()
	drag_ended.emit(card_data, end_pos)
	drag_updated.emit(card_data, end_pos)

func _animate_click():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(self, "scale", original_scale, 0.1)

func set_highlight(enabled: bool):
	modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 1.0)

func set_selected(selected: bool):
	is_selected = selected
	if selected:
		modulate = Color(1.2, 1.2, 1.0, 1.0)
	else:
		modulate = Color.WHITE

func play_discard_animation(target_pos: Vector2):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

func play_play_animation(target_pos: Vector2, callback: Callable = Callable()):
	var start_pos = position
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, 0.15)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain()
	if callback.is_valid():
		tween.tween_callback(callback)
	tween.tween_callback(queue_free)

func play_draw_animation(start_pos: Vector2):
	position = start_pos
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_property(self, "scale", original_scale, 0.12)

func reset_position():
	_hide_tooltip()
	position = original_position
	scale = original_scale
	rotation_degrees = 0.0
	is_dragging = false
	is_pressed = false
	is_awaiting_target = false
	
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	modulate = Color.WHITE

func restore_to_layout_state():
	is_dragging = false
	is_pressed = false
	is_awaiting_target = false
	
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	modulate = Color.WHITE
	scale = original_scale

func is_dragging_card() -> bool:
	return is_dragging

func is_in_target_mode() -> bool:
	return is_awaiting_target

func start_target_mode():
	is_awaiting_target = true
	drag_start_pos = get_global_mouse_position()
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)
	tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.0, 1.0), 0.08)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.08)
	
	target_mode_started.emit(card_data)
	drag_started.emit(card_data, drag_start_pos)

func cancel_target_mode():
	is_awaiting_target = false
	target_mode_ended.emit(card_data)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", original_scale, 0.12)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)

func set_original_position(pos: Vector2):
	original_position = pos

func _show_tooltip() -> void:
	if card_data == null or is_dragging or is_awaiting_target:
		return
	_hide_tooltip()
	
	tooltip_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	style.border_color = Color(0.5, 0.5, 0.6, 1.0)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	tooltip_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	
	var name_lbl = Label.new()
	name_lbl.text = card_data.name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(name_lbl)
	
	var type_lbl = Label.new()
	type_lbl.text = "[%s]" % _get_type_text(card_data.type)
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(type_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = card_data.get_description_text()
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(160, 0)
	vbox.add_child(desc_lbl)
	
	if card_data.rarity != "basic" and not card_data.rarity.is_empty():
		var rarity_lbl = Label.new()
		rarity_lbl.text = card_data.rarity
		rarity_lbl.add_theme_font_size_override("font_size", 11)
		rarity_lbl.add_theme_color_override("font_color", _get_rarity_color(card_data.rarity))
		vbox.add_child(rarity_lbl)
	
	tooltip_panel.add_child(vbox)
	
	var canvas = get_tree().root
	canvas.add_child(tooltip_panel)
	
	var gp = global_position
	var ts = tooltip_panel.get_combined_minimum_size()
	var vp_size = get_viewport_rect().size
	var px = gp.x + size.x + 8
	if px + ts.x > vp_size.x:
		px = gp.x - ts.x - 8
	var py = gp.y - 10
	if py + ts.y > vp_size.y:
		py = vp_size.y - ts.y - 5
	tooltip_panel.position = Vector2(px, py)
	tooltip_panel.z_index = 100

func _hide_tooltip() -> void:
	if tooltip_panel and is_instance_valid(tooltip_panel):
		tooltip_panel.queue_free()
	tooltip_panel = null

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.8, 0.8, 0.8)
		"uncommon": return Color(0.2, 0.8, 0.4)
		"rare": return Color(0.3, 0.5, 0.9)
		"epic": return Color(0.7, 0.3, 0.9)
		_: return Color(0.7, 0.7, 0.7)
