class_name EnemyUI
extends Control

@onready var enemy_sprite: TextureRect = $EnemySprite
@onready var name_label: Label = $NameLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var block_label: Label = $BlockLabel

var enemy_unit: EnemyUnit
var is_selected: bool = false
var original_scale: Vector2 = Vector2.ONE

signal enemy_clicked(enemy: EnemyUnit)
signal enemy_selected(enemy: EnemyUnit)

const SELECTED_COLOR := Color(1.5, 1.5, 1.0, 1.0)
const NORMAL_COLOR := Color.WHITE
const DEAD_COLOR := Color(0.5, 0.5, 0.5, 0.5)

func _ready():
	original_scale = scale
	_setup_signals()

func _setup_signals():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(enemy: EnemyUnit):
	enemy_unit = enemy
	
	var name_lbl = get_node_or_null("NameLabel")
	var hp_lbl = get_node_or_null("HPLabel")
	var hp_br = get_node_or_null("HPBar")
	var blk_lbl = get_node_or_null("BlockLabel")
	
	if name_lbl:
		name_lbl.text = enemy.get_name()
	
	if hp_lbl:
		hp_lbl.text = "%d/%d" % [enemy.current_hp, enemy.max_hp]
	
	if hp_br:
		hp_br.max_value = enemy.max_hp
		hp_br.value = enemy.current_hp
	
	if blk_lbl:
		blk_lbl.visible = false
	
	_update_intent_display()
	_connect_enemy_signals()

func _connect_enemy_signals():
	if enemy_unit:
		enemy_unit.hp_changed.connect(_on_enemy_hp_changed)
		enemy_unit.block_changed.connect(_on_enemy_block_changed)
		enemy_unit.enemy_died.connect(_on_enemy_died)
		enemy_unit.intent_changed.connect(_on_intent_changed)

func _update_hp_display():
	if enemy_unit == null:
		return
	
	if hp_label:
		hp_label.text = "%d/%d" % [enemy_unit.current_hp, enemy_unit.max_hp]
	
	if hp_bar:
		hp_bar.max_value = enemy_unit.max_hp
		hp_bar.value = enemy_unit.current_hp
	
	if block_label:
		if enemy_unit.block > 0:
			block_label.text = "护甲: %d" % enemy_unit.block
			block_label.visible = true
		else:
			block_label.visible = false

func _on_enemy_hp_changed(current: int, maximum: int):
	_update_hp_display()
	_animate_damage()

func _on_enemy_block_changed(amount: int):
	_update_hp_display()

func _on_enemy_died():
	_animate_death()

func _on_intent_changed(_intent: Dictionary):
	_update_intent_display()

func _update_intent_display():
	if enemy_unit == null:
		return
	
	var intent_lbl = get_node_or_null("IntentLabel")
	if intent_lbl == null:
		return
	
	var intent = enemy_unit.current_intent
	if intent.is_empty():
		intent_lbl.visible = false
		return
	
	intent_lbl.visible = true
	var intent_type = intent.get("type", "")
	var intent_text = intent.get("intent_text", "")
	
	match intent_type:
		"attack":
			var damage = intent.get("damage", 0)
			if intent_text != "":
				intent_lbl.text = "%s %d" % [intent_text, damage]
			else:
				intent_lbl.text = "攻击 %d" % damage
			intent_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		"defend":
			var block = intent.get("block", 0)
			if intent_text != "":
				intent_lbl.text = "%s %d" % [intent_text, block]
			else:
				intent_lbl.text = "防御 %d" % block
			intent_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1, 1))
		_:
			intent_lbl.text = intent_text if intent_text != "" else ""
			intent_lbl.visible = intent_text != ""

func _on_mouse_entered():
	if enemy_unit and enemy_unit.is_alive():
		_animate_hover(true)

func _on_mouse_exited():
	if enemy_unit and enemy_unit.is_alive():
		_animate_hover(false)

func _animate_hover(hover: bool):
	var target_scale = Vector2(1.1, 1.1) if hover else original_scale
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.15)

func _animate_damage():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", NORMAL_COLOR, 0.2)

func _animate_death():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", DEAD_COLOR, 0.5)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.5)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if enemy_unit and enemy_unit.is_alive():
			enemy_clicked.emit(enemy_unit)
			enemy_selected.emit(enemy_unit)
		accept_event()

func set_selected(selected: bool):
	is_selected = selected
	if selected:
		modulate = SELECTED_COLOR
	else:
		modulate = NORMAL_COLOR

func show_damage_number(amount: int):
	if amount <= 0:
		return
	
	var damage_label = Label.new()
	damage_label.text = "-%d" % amount
	damage_label.add_theme_color_override("font_color", Color.RED)
	damage_label.add_theme_font_size_override("font_size", 28)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.position = Vector2(60, 0)
	add_child(damage_label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", -40, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(damage_label.queue_free)

func show_block_number(amount: int):
	if amount <= 0:
		return
	
	var block_label_temp = Label.new()
	block_label_temp.text = "+%d 护甲" % amount
	block_label_temp.add_theme_color_override("font_color", Color.CYAN)
	block_label_temp.add_theme_font_size_override("font_size", 20)
	block_label_temp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_label_temp.position = Vector2(40, 80)
	add_child(block_label_temp)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(block_label_temp, "position:y", 40, 0.5)
	tween.tween_property(block_label_temp, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(block_label_temp.queue_free)
