extends Control

@onready var character_list: VBoxContainer = $ScrollContainer/CharacterList
@onready var create_button: Button = $ButtonContainer/CreateButton
@onready var select_button: Button = $ButtonContainer/SelectButton
@onready var delete_button: Button = $ButtonContainer/DeleteButton
@onready var back_button: Button = $ButtonContainer/BackButton

var selected_character_id: String = ""

signal character_selected(character: CharacterData)
signal create_new_character()
signal back_to_menu()

func _ready():
	_setup_buttons()
	_connect_signals()
	_refresh_character_list()

func _connect_signals():
	if GameManager:
		if not character_selected.is_connected(_on_character_selected):
			character_selected.connect(_on_character_selected)
		if not create_new_character.is_connected(_on_create_new_character):
			create_new_character.connect(_on_create_new_character)
		if not back_to_menu.is_connected(_on_back_to_menu):
			back_to_menu.connect(_on_back_to_menu)

func _setup_buttons():
	if create_button:
		create_button.pressed.connect(_on_create_pressed)
	if select_button:
		select_button.pressed.connect(_on_select_pressed)
	if delete_button:
		delete_button.pressed.connect(_on_delete_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _refresh_character_list():
	if character_list == null:
		return
	
	for child in character_list.get_children():
		child.queue_free()
	
	selected_character_id = ""
	
	var characters = CharacterManager.get_all_characters()
	
	if characters.is_empty():
		var empty_label = Label.new()
		empty_label.text = "暂无角色，请创建新角色"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		character_list.add_child(empty_label)
	else:
		for char_data in characters:
			var char_row = _create_character_row(char_data)
			character_list.add_child(char_row)
	
	_update_buttons()

func _create_character_row(char_data: CharacterData) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	var select_btn = Button.new()
	select_btn.text = "选择"
	select_btn.toggle_mode = true
	select_btn.button_group = _get_or_create_button_group()
	select_btn.pressed.connect(_on_character_row_selected.bind(char_data.id))
	row.add_child(select_btn)
	
	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	
	var name_label = Label.new()
	name_label.text = char_data.name
	name_label.add_theme_font_size_override("font_size", 18)
	info.add_child(name_label)
	
	var stats_label = Label.new()
	stats_label.text = "HP:%d 力量:%d 敏捷:%d 战斗:%d" % [
		char_data.get_max_hp(),
		char_data.get_strength(),
		char_data.get_dexterity(),
		char_data.battles_won
	]
	info.add_child(stats_label)
	
	return row

var _button_group: ButtonGroup = null

func _get_or_create_button_group() -> ButtonGroup:
	if _button_group == null:
		_button_group = ButtonGroup.new()
	return _button_group

func _on_character_row_selected(character_id: String):
	selected_character_id = character_id
	_update_buttons()

func _update_buttons():
	if select_button:
		select_button.disabled = selected_character_id.is_empty()
	if delete_button:
		delete_button.disabled = selected_character_id.is_empty()

func _on_create_pressed():
	create_new_character.emit()

func _on_select_pressed():
	if selected_character_id.is_empty():
		return
	
	var character = CharacterManager.get_character(selected_character_id)
	if character:
		CharacterManager.select_character(selected_character_id)
		character_selected.emit(character)

func _on_delete_pressed():
	if selected_character_id.is_empty():
		return
	
	var character = CharacterManager.get_character(selected_character_id)
	if character:
		_show_delete_confirmation(character)

func _show_delete_confirmation(character: CharacterData):
	var confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "确定删除角色 \"%s\" 吗？\n此操作不可撤销。" % character.name
	confirmation.title = "删除角色"
	add_child(confirmation)
	
	confirmation.confirmed.connect(_confirm_delete.bind(character.id))
	confirmation.popup_centered()

func _confirm_delete(character_id: String):
	CharacterManager.delete_character(character_id)
	_refresh_character_list()

func _on_back_pressed():
	back_to_menu.emit()

func _on_character_selected(character: CharacterData):
	var card_db = CardDatabase.new()
	var deck: Array = []
	for card_id in character.deck_card_ids:
		var card = card_db.get_card(card_id)
		if card:
			deck.append(card.duplicate())
	
	GameData.player_deck = deck
	GameData.player_max_hp = character.get_max_hp()
	GameData.player_current_hp = GameData.player_max_hp
	
	var character_stats = {
		"max_hp": character.get_max_hp(),
		"strength": character.get_strength(),
		"dexterity": character.get_dexterity()
	}
	
	var enemy = GameData.get_random_enemy_for_battle()
	if enemy:
		GameManager.start_battle([enemy], character_stats)

func _on_create_new_character():
	GameManager.go_to_character_creation()

func _on_back_to_menu():
	GameManager.go_to_main_menu()

func receive_data(data: Dictionary) -> void:
	call_deferred("_refresh_character_list")
