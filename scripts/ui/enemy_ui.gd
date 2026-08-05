class_name EnemyUI
extends Control

@onready var name_label: Label = $NameLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var block_label: Label = $BlockLabel

var enemy_unit: EnemyUnit
var player_manager: PlayerManager = null
var original_scale: Vector2 = Vector2.ONE

signal enemy_clicked(enemy: EnemyUnit)
signal enemy_selected(enemy: EnemyUnit)

const NORMAL_COLOR := Color.WHITE
const DEAD_COLOR := Color(0.5, 0.5, 0.5, 0.5)

static var _buff_db: Dictionary = {}

func _ready():
	original_scale = scale
	_setup_signals()

func _setup_signals():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _load_buff_db() -> void:
	if not _buff_db.is_empty():
		return
	var file = FileAccess.open("res://data/buffs.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json and json.has("buffs"):
			_buff_db = json["buffs"]
		file.close()

func _get_buff_data(buff_id: String) -> Dictionary:
	_load_buff_db()
	return _buff_db.get(buff_id, {})

func setup(enemy: EnemyUnit, pm: PlayerManager = null):
	enemy_unit = enemy
	player_manager = pm
	
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
	
	_create_buff_bar()
	_update_intent_display()
	_connect_enemy_signals()

func _connect_enemy_signals():
	if enemy_unit:
		enemy_unit.hp_changed.connect(_on_enemy_hp_changed)
		enemy_unit.block_changed.connect(_on_enemy_block_changed)
		enemy_unit.enemy_died.connect(_on_enemy_died)
		enemy_unit.intent_changed.connect(_on_intent_changed)
		if enemy_unit.buff_manager:
			enemy_unit.buff_manager.buffs_changed.connect(_update_buff_bar)
			enemy_unit.buff_manager.buffs_changed.connect(_update_intent_display)
	if player_manager and player_manager.buff_manager:
		player_manager.buff_manager.buffs_changed.connect(_on_player_buffs_changed)

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

func _on_player_buffs_changed():
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
			var mult = enemy_unit.buff_manager.get_mult("damage")
			var add = int(enemy_unit.buff_manager.get_flat_add("damage"))
			var effective = int((damage + add) * mult)
			if player_manager:
				var damage_taken_mult = player_manager.buff_manager.get_mult("damage_taken")
				effective = int(effective * damage_taken_mult)
			if intent_text != "":
				intent_lbl.text = "⚔ %s %d" % [intent_text, effective]
			else:
				intent_lbl.text = "⚔ 攻击 %d" % effective
			intent_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
		"defend":
			var block = intent.get("block", 0)
			var mult = enemy_unit.buff_manager.get_mult("block")
			var effective = int(block * mult)
			if intent_text != "":
				intent_lbl.text = "🛡 %s %d" % [intent_text, effective]
			else:
				intent_lbl.text = "🛡 防御 %d" % effective
			intent_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1, 1))
		"buff":
			intent_lbl.text = "↑ %s" % (intent_text if intent_text != "" else "强化")
			intent_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4, 1))
		"debuff":
			intent_lbl.text = "↓ %s" % (intent_text if intent_text != "" else "削弱")
			intent_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.9, 1))
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
	var target_scale = Vector2(1.08, 1.08) if hover else original_scale
	var target_modulate = Color(1.1, 1.1, 1.0, 1.0) if hover else NORMAL_COLOR
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", target_scale, 0.1)
	tween.tween_property(self, "modulate", target_modulate, 0.1)

func _animate_damage():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(self, "modulate", NORMAL_COLOR, 0.15)

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

func set_highlight_for_target(valid: bool):
	if valid:
		modulate = Color(1.2, 1.0, 0.8, 1.0)
		z_index = 10
	else:
		modulate = NORMAL_COLOR
		z_index = 0

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
	tween.tween_property(damage_label, "position:y", -20, 1.8)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.3).set_delay(1.5)
	tween.tween_callback(damage_label.queue_free)

var _buff_bar: HBoxContainer = null

func _create_buff_bar() -> void:
	_buff_bar = HBoxContainer.new()
	_buff_bar.name = "BuffBar"
	_buff_bar.add_theme_constant_override("separation", 4)
	_buff_bar.offset_left = 5.0
	_buff_bar.offset_top = 135.0
	_buff_bar.offset_right = 145.0
	_buff_bar.offset_bottom = 155.0
	_buff_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_buff_bar)
	_update_buff_bar()

func _update_buff_bar() -> void:
	if _buff_bar == null or enemy_unit == null:
		return
	
	for child in _buff_bar.get_children():
		child.queue_free()
	
	if not enemy_unit.buff_manager:
		return
	
	for buff in enemy_unit.buff_manager.buffs:
		var buff_info = _extract_buff_info(buff)
		if buff_info.is_empty():
			continue
		var lbl = _create_buff_label(buff_info)
		_buff_bar.add_child(lbl)

func _extract_buff_info(buff) -> Dictionary:
	var stacks: int = 1
	var duration: int = 0
	var buff_id: String = ""
	var buff_name: String = ""
	var buff_type: String = "buff"
	if buff is BuffData:
		stacks = buff.stacks
		duration = buff.duration
		buff_id = buff.id
		buff_name = buff.name
		buff_type = buff.buff_type
	elif buff is Dictionary:
		stacks = buff.get("stacks", 1)
		duration = buff.get("duration", 0)
		buff_id = buff.get("id", buff.get("buff_id", ""))
		buff_name = buff.get("name", "")
		buff_type = buff.get("buff_type", "buff")
	else:
		return {}
	return {"id": buff_id, "name": buff_name, "stacks": stacks, "duration": duration, "buff_type": buff_type}

var _buff_tooltip_panel: PanelContainer = null

const NO_STACK_BUFFS: Array = ["skip_attack", "ignore_block", "counter_stance"]

func _create_buff_label(info: Dictionary) -> Control:
	var buff_id: String = info.get("id", "")
	var stacks: int = info.get("stacks", 1)
	var duration: int = info.get("duration", 0)
	
	var symbol = _get_buff_symbol(buff_id)
	var color = _get_buff_color(buff_id)
	var show_stacks = not NO_STACK_BUFFS.has(buff_id)
	
	var btn = Button.new()
	if show_stacks:
		btn.text = "%s%d" % [symbol, stacks]
	else:
		btn.text = symbol
	if duration > 0:
		btn.text += "(%d)" % duration
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color)
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 16)
	btn.focus_mode = Control.FOCUS_NONE
	
	var tooltip_text = _get_buff_tooltip(buff_id, stacks, duration)
	if not tooltip_text.is_empty():
		btn.mouse_entered.connect(_on_buff_label_hovered.bind(tooltip_text, btn))
		btn.mouse_exited.connect(_on_buff_label_unhovered)
	
	return btn

func _on_buff_label_hovered(text: String, source: Control) -> void:
	_hide_buff_tooltip()
	
	_buff_tooltip_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	style.border_color = Color(0.5, 0.5, 0.6, 1.0)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	_buff_tooltip_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	
	var lines = text.split("\n")
	for line in lines:
		var lbl = Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 13)
		if line == lines[0]:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		else:
			lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		vbox.add_child(lbl)
	
	_buff_tooltip_panel.add_child(vbox)
	
	var canvas = get_tree().root
	canvas.add_child(_buff_tooltip_panel)
	
	var gp = source.global_position
	var ts = _buff_tooltip_panel.get_combined_minimum_size()
	var vp_size = source.get_viewport_rect().size
	var px = gp.x + source.size.x + 6
	if px + ts.x > vp_size.x:
		px = gp.x - ts.x - 6
	var py = gp.y - 5
	if py + ts.y > vp_size.y:
		py = vp_size.y - ts.y - 5
	_buff_tooltip_panel.position = Vector2(px, py)
	_buff_tooltip_panel.z_index = 100

func _on_buff_label_unhovered() -> void:
	_hide_buff_tooltip()

func _hide_buff_tooltip() -> void:
	if _buff_tooltip_panel and is_instance_valid(_buff_tooltip_panel):
		_buff_tooltip_panel.queue_free()
	_buff_tooltip_panel = null

func _get_buff_tooltip(buff_id: String, stacks: int, duration: int) -> String:
	var desc = _get_buff_description(buff_id, stacks)
	if desc.is_empty():
		return ""
	var result = desc
	if duration > 0:
		result += "\n剩余 %d 回合" % duration
	elif duration == -1:
		result += "\n永久"
	return result

func _get_buff_description(buff_id: String, stacks: int) -> String:
	var data = _get_buff_data(buff_id)
	if data.is_empty():
		return ""
	var name = data.get("name", buff_id)
	var desc_template = data.get("description", "")
	var desc = desc_template.replace("{stacks}", str(stacks))
	var buff_type = data.get("buff_type", "buff")
	var type_label = "[增益]" if buff_type == "buff" else "[减益]" if buff_type == "debuff" else ""
	return "%s %s\n%s" % [type_label, name, desc] if type_label != "" else "%s\n%s" % [name, desc]

func _get_buff_symbol(buff_id: String) -> String:
	var data = _get_buff_data(buff_id)
	return data.get("symbol", "●")

func _get_buff_color(buff_id: String) -> Color:
	var data = _get_buff_data(buff_id)
	var hex = data.get("color", "#B3B3B3")
	return Color(hex)