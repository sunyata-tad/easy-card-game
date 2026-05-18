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

var is_dragging: bool = false
var drag_start_pos: Vector2
var is_pressed: bool = false
var press_tween: Tween = null
var mouse_inside: bool = true
var is_awaiting_target: bool = false

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
		var base_stat = effect.get("base_stat", "")
		var multiplier = effect.get("multiplier", 1.0)
		
		if base_stat != "" and player_manager:
			var stat_value = 0
			if base_stat == "strength":
				stat_value = player_manager.strength
			elif base_stat == "dexterity":
				stat_value = player_manager.dexterity
			
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
	if is_pressed or is_awaiting_target:
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
					drag_start_pos = get_global_mouse_position()
					
					if is_awaiting_target:
						cancel_target_mode()
					else:
						_animate_press_down()
				accept_event()
			elif event.is_released():
				if is_pressed:
					is_pressed = false
					
					if _needs_target():
						if is_dragging:
							end_drag()
						elif mouse_inside:
							start_target_mode()
						else:
							_cancel_press()
					else:
						if mouse_inside:
							_animate_press_up()
							card_released.emit(card_data)
						else:
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
		if is_pressed and _needs_target() and not is_dragging:
			var current_pos = get_global_mouse_position()
			var distance = current_pos.distance_to(drag_start_pos)
			if distance > 10.0:
				start_drag()
		
		if is_dragging or is_awaiting_target:
			var global_mouse_pos = get_global_mouse_position()
			drag_updated.emit(card_data, global_mouse_pos)

func _on_mouse_entered():
	is_hovered = true
	mouse_inside = true
	_animate_hover(true)
	card_hovered.emit(card_data)

func _on_mouse_exited():
	is_hovered = false
	mouse_inside = false
	_animate_hover(false)
	card_unhovered.emit(card_data)

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
	drag_start_pos = get_global_mouse_position()
	drag_started.emit(card_data, drag_start_pos)
	
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)
	press_tween.tween_property(self, "rotation_degrees", 0.0, 0.08)
	
func end_drag():
	is_dragging = false
	var end_pos = get_global_mouse_position()
	drag_ended.emit(card_data, end_pos)
	
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	press_tween = create_tween()
	press_tween.tween_property(self, "scale", original_scale, 0.1)

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
