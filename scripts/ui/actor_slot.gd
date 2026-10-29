## 统一角色槽位 UI：玩家与敌人共用同一组件。
## 简略显示：立绘 + 血条 + 能量圆点 + buff 栏。点击立绘弹出详细信息框。
class_name ActorSlot
extends Control

signal actor_clicked(actor)

var sprite: TextureRect = null
var hp_bar: ProgressBar = null
var energy_dots: HBoxContainer = null
var buff_bar: HBoxContainer = null

var actor = null
var is_player: bool = false
var original_scale: Vector2 = Vector2.ONE

const NORMAL_COLOR := Color.WHITE
const DEAD_COLOR := Color(0.5, 0.5, 0.5, 0.5)
const NO_STACK_BUFFS: Array = ["skip_attack", "ignore_block", "counter_stance", "no_discard"]

static var _buff_db: Dictionary = {}
var _buff_tooltip_panel: PanelContainer = null

func _ready():
	original_scale = scale
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _resolve_nodes() -> void:
	sprite = get_node_or_null("Sprite")
	hp_bar = get_node_or_null("HPBar")
	energy_dots = get_node_or_null("EnergyDots")
	buff_bar = get_node_or_null("BuffBar")

func setup(p_actor, p_is_player: bool = false) -> void:
	_resolve_nodes()
	actor = p_actor
	is_player = p_is_player
	if hp_bar:
		hp_bar.max_value = actor.max_hp
		hp_bar.value = actor.current_hp
	_load_sprite()
	_connect_actor_signals()
	_update_energy_display()
	_update_buff_bar()

func _load_sprite() -> void:
	if sprite == null:
		return
	if is_player:
		var tex_path = "res://art_assets/pixel/player_fighter.png"
		if ResourceLoader.exists(tex_path):
			sprite.texture = load(tex_path)
	else:
		if actor and actor.data and actor.data.art != "":
			var tex = load(actor.data.art)
			if tex:
				sprite.texture = tex
				sprite.visible = true
				return
		sprite.visible = false

func _connect_actor_signals() -> void:
	if actor == null:
		return
	if actor.has_signal("hp_changed"):
		actor.hp_changed.connect(_on_hp_changed)
	if actor.has_signal("block_changed"):
		actor.block_changed.connect(_on_block_changed)
	if actor.has_signal("energy_changed"):
		actor.energy_changed.connect(_on_energy_changed)
	if not is_player and actor.has_signal("enemy_died"):
		actor.enemy_died.connect(_animate_death)
	if actor.buff_manager:
		actor.buff_manager.buffs_changed.connect(_update_buff_bar)

func _on_hp_changed(_current: int, _maximum: int) -> void:
	_update_hp_display()
	_animate_damage()

func _on_block_changed(_amount: int) -> void:
	_update_hp_display()

func _on_energy_changed(_current: int, _maximum: int) -> void:
	_update_energy_display()

func _update_hp_display() -> void:
	if actor == null or hp_bar == null:
		return
	hp_bar.max_value = actor.max_hp
	hp_bar.value = actor.current_hp

## 外部调用：更新能量圆点（亮=可用, 灰=已用, 暗=未满）
func update_energy(available: int, maximum: int, used: int = 0) -> void:
	if energy_dots == null:
		return
	for child in energy_dots.get_children():
		child.queue_free()
	var unavailable = maxi(maximum - available - used, 0)
	for i in available:
		energy_dots.add_child(_create_energy_dot("lit"))
	for i in used:
		energy_dots.add_child(_create_energy_dot("used"))
	for i in unavailable:
		energy_dots.add_child(_create_energy_dot("dark"))

func _update_energy_display() -> void:
	if actor == null:
		return
	update_energy(actor.energy, actor.max_energy, 0)

func _create_energy_dot(state: String) -> Control:
	var dot = Panel.new()
	var style = StyleBoxFlat.new()
	match state:
		"lit":
			style.bg_color = Color(0.95, 0.8, 0.3, 1.0)
			style.border_color = Color(1.0, 0.9, 0.5, 0.8)
		"used":
			style.bg_color = Color(0.4, 0.4, 0.45, 1.0)
		"dark":
			style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	style.set_corner_radius_all(3)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	dot.add_theme_stylebox_override("panel", style)
	dot.custom_minimum_size = Vector2(7, 7)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot

func _update_buff_bar() -> void:
	if buff_bar == null or actor == null:
		return
	for child in buff_bar.get_children():
		child.queue_free()
	if not actor.buff_manager:
		return
	for buff in actor.buff_manager.buffs:
		var info = _extract_buff_info(buff)
		if info.is_empty():
			continue
		buff_bar.add_child(_create_buff_label(info))

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
	btn.add_theme_font_size_override("font_size", 9)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color)
	btn.flat = true
	if UIStyle:
		UIStyle.strip_button_box(btn)
	btn.custom_minimum_size = Vector2(0, 10)
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

func _get_buff_description(buff_id: String, stacks: int) -> String:
	var data = _get_buff_data(buff_id)
	if data.is_empty():
		return ""
	var bname = data.get("name", buff_id)
	var desc_template = data.get("description", "")
	var desc = desc_template.replace("{stacks}", str(stacks))
	var buff_type = data.get("buff_type", "buff")
	var type_label = "[增益]" if buff_type == "buff" else "[减益]" if buff_type == "debuff" else ""
	return "%s %s\n%s" % [type_label, bname, desc] if type_label != "" else "%s\n%s" % [bname, desc]

func _get_buff_symbol(buff_id: String) -> String:
	var data = _get_buff_data(buff_id)
	return data.get("symbol", "●")

func _get_buff_color(buff_id: String) -> Color:
	var data = _get_buff_data(buff_id)
	var hex = data.get("color", "#B3B3B3")
	return Color(hex)

func _on_mouse_entered():
	if actor and _is_alive():
		_animate_hover(true)

func _on_mouse_exited():
	if actor and _is_alive():
		_animate_hover(false)

func _is_alive() -> bool:
	if is_player:
		return not actor.is_dead
	return actor.is_alive()

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
		if actor and _is_alive():
			actor_clicked.emit(actor)
		accept_event()

func set_highlight_for_target(valid: bool):
	if valid:
		modulate = Color(1.2, 1.0, 0.8, 1.0)
		z_index = 10
	else:
		modulate = NORMAL_COLOR
		z_index = 0

## 飘字：伤害(红)/治疗(绿)/护甲(蓝)
func show_damage_number(amount: int, kind: String = "damage"):
	if amount <= 0:
		return
	var text: String
	var color: Color
	match kind:
		"heal":
			text = "+%d" % amount
			color = Color(0.35, 0.9, 0.45)
		"block":
			text = "+%d" % amount
			color = Color(0.45, 0.75, 1.0)
		_:
			text = "-%d" % amount
			color = Color.RED
	var damage_label = Label.new()
	damage_label.text = text
	damage_label.add_theme_color_override("font_color", color)
	damage_label.add_theme_font_size_override("font_size", 24)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.position = Vector2(32, 0)
	add_child(damage_label)
	ImpactConfig.apply_text_effect(damage_label, amount, self)
	var tween = create_tween()
	tween.tween_property(damage_label, "position:y", -20, 1.8)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.3).set_delay(1.5)
	tween.tween_callback(damage_label.queue_free)