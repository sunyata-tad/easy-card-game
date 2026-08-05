## 玩家 UI 节点：显示玩家头像、血条、护甲和 buff 图标。
## 与 EnemyUI 结构对称，但玩家不需要意图显示，而是有力量/敏捷等属性面板。
class_name PlayerUI
extends Control

@onready var player_sprite: TextureRect = $PlayerSprite     ## 玩家图片
@onready var hp_bar: ProgressBar = $HPBar                   ## 血条
@onready var hp_label: Label = $HPLabel                     ## 血量文字
@onready var block_label: Label = $BlockLabel               ## 护甲文字
@onready var buff_container: HBoxContainer = $BuffContainer ## buff 图标容器

var player_manager: PlayerManager  ## 玩家状态引用

static var _buff_db: Dictionary = {}          ## buff 数据库缓存
var _buff_tooltip_panel: PanelContainer = null  ## buff 提示面板

const NO_STACK_BUFFS: Array = ["skip_attack", "ignore_block", "counter_stance"]  ## 不显示层数的 buff

func _ready():
	_load_buff_db()

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
	return _buff_db.get(buff_id, {})

func setup(player: PlayerManager):
	player_manager = player
	_update_display()
	_connect_signals()
	_update_buff_bar()

func _connect_signals():
	if player_manager:
		player_manager.hp_changed.connect(_on_hp_changed)
		player_manager.block_changed.connect(_on_block_changed)
		if player_manager.buff_manager:
			player_manager.buff_manager.buffs_changed.connect(_update_buff_bar)

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

func _update_buff_bar() -> void:
	if buff_container == null or player_manager == null:
		return
	
	for child in buff_container.get_children():
		child.queue_free()
	
	if not player_manager.buff_manager:
		return
	
	for buff in player_manager.buff_manager.buffs:
		var info = _extract_buff_info(buff)
		if info.is_empty():
			continue
		var lbl = _create_buff_label(info)
		buff_container.add_child(lbl)

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

func _get_buff_symbol(buff_id: String) -> String:
	var data = _get_buff_data(buff_id)
	return data.get("symbol", "●")

func _get_buff_color(buff_id: String) -> Color:
	var data = _get_buff_data(buff_id)
	var hex = data.get("color", "#B3B3B3")
	return Color(hex)

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