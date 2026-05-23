extends Control

enum CreationStep { NAME, STATS, DECK, TRAITS, ITEMS, CONFIRM }

const MIN_DECK_SIZE: int = 10
const MAX_DECK_SIZE: int = 30
const TOTAL_STAT_POINTS: int = 15

var current_step: int = CreationStep.NAME
var creation_data: Dictionary = {
	"name": "",
	"base_stats": {
		"max_hp": 80,
		"strength": 0,
		"dexterity": 0,
		"initial_block": 0
	},
	"deck_card_ids": [],
	"traits": [],
	"items": []
}

var remaining_stat_points: int = TOTAL_STAT_POINTS

@onready var step_indicator: HBoxContainer = $StepIndicator
@onready var content_area: Control = $ContentArea
@onready var prev_button: Button = $ButtonContainer/PrevButton
@onready var next_button: Button = $ButtonContainer/NextButton
@onready var cancel_button: Button = $ButtonContainer/CancelButton

signal creation_completed(character: CharacterData)
signal creation_cancelled()

func _ready():
	_setup_buttons()
	_setup_initial_stats()
	_show_step(current_step)

func _setup_buttons():
	if prev_button:
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

func _setup_initial_stats():
	creation_data.base_stats = {
		"max_hp": 80,
		"strength": 0,
		"dexterity": 0,
		"initial_block": 0
	}
	remaining_stat_points = TOTAL_STAT_POINTS
	
	creation_data.deck_card_ids = []
	for i in range(3):
		creation_data.deck_card_ids.append("斩击")
	for i in range(3):
		creation_data.deck_card_ids.append("格挡")
	for i in range(2):
		creation_data.deck_card_ids.append("蓄力")
	for i in range(2):
		creation_data.deck_card_ids.append("蓄势")

func _randomize_stats():
	creation_data.base_stats = {
		"max_hp": 80,
		"strength": 0,
		"dexterity": 0,
		"initial_block": 0
	}
	remaining_stat_points = TOTAL_STAT_POINTS
	
	var stat_keys = ["max_hp", "strength", "dexterity", "initial_block"]
	
	for i in range(TOTAL_STAT_POINTS):
		var stat_key = stat_keys[randi() % stat_keys.size()]
		creation_data.base_stats[stat_key] += 1
	
	remaining_stat_points = 0

func _show_step(step: int):
	current_step = step
	_clear_content_area()
	_update_step_indicator()
	_update_buttons()
	
	match step:
		CreationStep.NAME:
			_show_name_step()
		CreationStep.STATS:
			_show_stats_step()
		CreationStep.DECK:
			_show_deck_step()
		CreationStep.TRAITS:
			_show_traits_step()
		CreationStep.ITEMS:
			_show_items_step()
		CreationStep.CONFIRM:
			_show_confirm_step()

func _clear_content_area():
	if content_area:
		for child in content_area.get_children():
			child.queue_free()

func _update_step_indicator():
	if step_indicator == null:
		return
	
	for child in step_indicator.get_children():
		child.queue_free()
	
	var step_names = ["名称", "属性", "卡组", "特性", "物品", "确认"]
	for i in range(step_names.size()):
		var label = Label.new()
		label.text = step_names[i]
		if i == current_step:
			label.add_theme_color_override("font_color", Color.YELLOW)
		elif i < current_step:
			label.add_theme_color_override("font_color", Color.GREEN)
		else:
			label.add_theme_color_override("font_color", Color.GRAY)
		step_indicator.add_child(label)
		
		if i < step_names.size() - 1:
			var arrow = Label.new()
			arrow.text = " → "
			step_indicator.add_child(arrow)

func _update_buttons():
	if prev_button:
		prev_button.visible = current_step > CreationStep.NAME
	
	if next_button:
		if current_step == CreationStep.CONFIRM:
			next_button.text = "创建角色"
		else:
			next_button.text = "下一步"

func _show_name_step():
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)
	
	var title = Label.new()
	title.text = "角色名称"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "输入角色名称"
	name_edit.custom_minimum_size = Vector2(300, 40)
	name_edit.text = creation_data.name
	name_edit.text_changed.connect(_on_name_changed)
	vbox.add_child(name_edit)

func _on_name_changed(new_name: String):
	creation_data.name = new_name

func _show_stats_step():
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)
	
	var title = Label.new()
	title.text = "属性点分配（剩余: %d）" % remaining_stat_points
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 10)
	vbox.add_child(stats_container)
	
	var stat_configs = [
		{"key": "max_hp", "name": "最大HP", "min": 50, "max": 150, "step": 10},
		{"key": "strength", "name": "力量", "min": 0, "max": 10, "step": 1},
		{"key": "dexterity", "name": "敏捷", "min": 0, "max": 10, "step": 1},
		{"key": "initial_block", "name": "初始护甲", "min": 0, "max": 10, "step": 1}
	]
	
	for config in stat_configs:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		stats_container.add_child(row)
		
		var label = Label.new()
		label.text = config.name
		label.custom_minimum_size = Vector2(100, 0)
		row.add_child(label)
		
		var value_label = Label.new()
		value_label.text = str(creation_data.base_stats.get(config.key, 0))
		value_label.custom_minimum_size = Vector2(50, 0)
		row.add_child(value_label)
		
		var minus_btn = Button.new()
		minus_btn.text = "-"
		minus_btn.pressed.connect(_on_stat_decrease.bind(config.key, config.step, config.min))
		row.add_child(minus_btn)
		
		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.pressed.connect(_on_stat_increase.bind(config.key, config.step, config.max))
		row.add_child(plus_btn)
	
	var random_btn = Button.new()
	random_btn.text = "随机分配"
	random_btn.pressed.connect(_on_randomize_stats)
	vbox.add_child(random_btn)

func _on_stat_increase(stat_key: String, step: int, max_val: int):
	if remaining_stat_points <= 0:
		return
	var current = creation_data.base_stats.get(stat_key, 0)
	if current + step <= max_val:
		creation_data.base_stats[stat_key] = current + step
		remaining_stat_points -= 1
		_show_step(current_step)

func _on_stat_decrease(stat_key: String, step: int, min_val: int):
	var current = creation_data.base_stats.get(stat_key, 0)
	if current - step >= min_val:
		creation_data.base_stats[stat_key] = current - step
		remaining_stat_points += 1
		_show_step(current_step)

func _on_randomize_stats():
	_randomize_stats()
	_show_step(current_step)

func _show_deck_step():
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)
	
	var title = Label.new()
	title.text = "卡组构筑（%d/%d张）" % [creation_data.deck_card_ids.size(), MAX_DECK_SIZE]
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var hint = Label.new()
	hint.text = "需要 %d - %d 张卡牌" % [MIN_DECK_SIZE, MAX_DECK_SIZE]
	vbox.add_child(hint)
	
	var card_db = CardDatabase.new()
	var all_card_ids = card_db.get_all_card_ids()
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 300)
	vbox.add_child(scroll)
	
	var cards_container = VBoxContainer.new()
	scroll.add_child(cards_container)
	
	for card_id in all_card_ids:
		var card = card_db.get_card(card_id)
		if card:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			cards_container.add_child(row)
			
			var label = Label.new()
			label.text = card.name
			label.custom_minimum_size = Vector2(150, 0)
			row.add_child(label)
			
			var count = creation_data.deck_card_ids.count(card_id)
			var count_label = Label.new()
			count_label.text = "×%d" % count
			count_label.custom_minimum_size = Vector2(50, 0)
			row.add_child(count_label)
			
			var add_btn = Button.new()
			add_btn.text = "+"
			add_btn.disabled = creation_data.deck_card_ids.size() >= MAX_DECK_SIZE
			add_btn.pressed.connect(_on_add_card_to_deck.bind(card_id))
			row.add_child(add_btn)
			
			var remove_btn = Button.new()
			remove_btn.text = "-"
			remove_btn.disabled = count <= 0
			remove_btn.pressed.connect(_on_remove_card_from_deck.bind(card_id))
			row.add_child(remove_btn)

func _on_add_card_to_deck(card_id: String):
	if creation_data.deck_card_ids.size() < MAX_DECK_SIZE:
		creation_data.deck_card_ids.append(card_id)
		_show_step(current_step)

func _on_remove_card_from_deck(card_id: String):
	if creation_data.deck_card_ids.has(card_id):
		creation_data.deck_card_ids.erase(card_id)
		_show_step(current_step)

func _show_traits_step():
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)
	
	var title = Label.new()
	title.text = "初始特性选择（可选）"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var hint = Label.new()
	hint.text = "特性系统暂未实现，此为框架界面"
	vbox.add_child(hint)
	
	creation_data.traits = []

func _show_items_step():
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)
	
	var title = Label.new()
	title.text = "初始物品选择（可选）"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var hint = Label.new()
	hint.text = "物品系统暂未实现，此为框架界面"
	vbox.add_child(hint)
	
	creation_data.items = []

func _show_confirm_step():
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)
	
	var title = Label.new()
	title.text = "确认创建"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	vbox.add_child(info)
	
	var name_label = Label.new()
	name_label.text = "名称: %s" % creation_data.name
	info.add_child(name_label)
	
	var hp_label = Label.new()
	hp_label.text = "最大HP: %d" % creation_data.base_stats.max_hp
	info.add_child(hp_label)
	
	var str_label = Label.new()
	str_label.text = "力量: %d" % creation_data.base_stats.strength
	info.add_child(str_label)
	
	var dex_label = Label.new()
	dex_label.text = "敏捷: %d" % creation_data.base_stats.dexterity
	info.add_child(dex_label)
	
	var deck_label = Label.new()
	deck_label.text = "卡组: %d张" % creation_data.deck_card_ids.size()
	info.add_child(deck_label)

func _on_prev_pressed():
	if current_step > CreationStep.NAME:
		_show_step(current_step - 1)

func _on_next_pressed():
	if current_step == CreationStep.CONFIRM:
		_create_character()
	else:
		if _validate_current_step():
			_show_step(current_step + 1)

func _validate_current_step() -> bool:
	match current_step:
		CreationStep.NAME:
			if creation_data.name.is_empty():
				return false
		CreationStep.DECK:
			var deck_size = creation_data.deck_card_ids.size()
			if deck_size < MIN_DECK_SIZE or deck_size > MAX_DECK_SIZE:
				return false
	return true

func _create_character():
	var character = CharacterManager.create_character(
		creation_data.name,
		creation_data.base_stats,
		creation_data.deck_card_ids,
		creation_data.traits,
		creation_data.items
	)
	CharacterManager.select_character(character.id)
	creation_completed.emit(character)
	GameManager.go_to_character_select()

func _on_cancel_pressed():
	creation_cancelled.emit()
	GameManager.go_to_character_select()
