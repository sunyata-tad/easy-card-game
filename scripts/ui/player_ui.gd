class_name PlayerUI
extends Control

@onready var player_sprite: TextureRect = $PlayerSprite
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var block_label: Label = $BlockLabel
@onready var buff_container: HBoxContainer = $BuffContainer

var player_manager: PlayerManager

const HP_BAR_WIDTH := 150.0
const HP_BAR_HEIGHT := 20.0

func setup(player: PlayerManager):
	player_manager = player
	_update_display()
	_connect_signals()

func _connect_signals():
	if player_manager:
		player_manager.hp_changed.connect(_on_hp_changed)
		player_manager.block_changed.connect(_on_block_changed)

func _update_display():
	if player_manager == null:
		return
	
	if hp_label:
		hp_label.text = "%d / %d" % [player_manager.current_hp, player_manager.max_hp]
	
	if hp_bar:
		hp_bar.max_value = player_manager.max_hp
		hp_bar.value = player_manager.current_hp
	
	if block_label:
		if player_manager.block > 0:
			block_label.text = "护甲: %d" % player_manager.block
			block_label.visible = true
		else:
			block_label.visible = false

func _on_hp_changed(current: int, maximum: int):
	_update_display()
	_animate_damage()

func _on_block_changed(amount: int):
	_update_display()
	if amount > 0:
		_animate_block_gained(amount)

func _animate_damage():
	if player_sprite:
		var tween = create_tween()
		tween.tween_property(player_sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.2)

func _animate_block_gained(amount: int):
	var block_popup = Label.new()
	block_popup.text = "+%d 护甲" % amount
	block_popup.add_theme_color_override("font_color", Color.CYAN)
	block_popup.add_theme_font_size_override("font_size", 20)
	block_popup.position = Vector2(50, 100)
	add_child(block_popup)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(block_popup, "position:y", 70, 0.5)
	tween.tween_property(block_popup, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(block_popup.queue_free)

func show_heal_number(amount: int):
	if amount <= 0:
		return
	
	var heal_label = Label.new()
	heal_label.text = "+%d" % amount
	heal_label.add_theme_color_override("font_color", Color.GREEN)
	heal_label.add_theme_font_size_override("font_size", 24)
	heal_label.position = Vector2(60, 50)
	add_child(heal_label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(heal_label, "position:y", 20, 0.6)
	tween.tween_property(heal_label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(heal_label.queue_free)

func update_buff_display():
	if buff_container == null or player_manager == null:
		return
	
	for child in buff_container.get_children():
		child.queue_free()
	
	for buff in player_manager.buff_manager.get_all_buffs():
		var buff_label = Label.new()
		buff_label.text = "%s(%d)" % [buff.name, buff.stacks]
		buff_label.add_theme_font_size_override("font_size", 12)
		buff_container.add_child(buff_label)
