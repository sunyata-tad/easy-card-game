## 角色选择场景脚本：挂载到 CharacterSelectScreen.tscn 的根 Control 节点上。
## 显示所有已创建的角色列表，支持选择、删除、创建新角色。
## Godot 特色：
## - @onready var x = $Path 自动查找场景中的子节点
## - ButtonGroup 确保多个按钮中只有一个被选中（类似 HTML 的 radio button group）
## - call_deferred("method") 延迟到下一帧调用（等待节点树完全就绪）
extends Control

@onready var character_list: VBoxContainer = $ScrollContainer/CharacterList  ## 角色列表容器
@onready var create_button: Button = $ButtonContainer/CreateButton           ## 创建按钮
@onready var select_button: Button = $ButtonContainer/SelectButton           ## 选择按钮
@onready var delete_button: Button = $ButtonContainer/DeleteButton           ## 删除按钮
@onready var back_button: Button = $ButtonContainer/BackButton               ## 返回按钮

var selected_character_id: String = ""  ## 当前选中的角色 id

signal character_selected(character: CharacterData)  ## 角色被选中（确认进入游戏）
signal create_new_character()                        ## 请求创建新角色
signal back_to_menu()                                ## 返回主菜单

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

## 刷新角色列表（从 CharacterManager 加载）
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

## 创建单个角色的 UI 行（选择按钮 + 基本信息）
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

## 获取或创建按钮组（确保同一时间只有一个角色被选中）
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

## 确认选择角色：初始化 GameData 并进入地图
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

## 角色选中后的回调：用角色数据初始化 GameData，然后进入地图
func _on_character_selected(character: CharacterData):
	GameData.initialize_run_from_character(character)
	print("选择角色: HP=%d, 力量=%d, 敏捷=%d" % [character.get_max_hp(), character.get_strength(), character.get_dexterity()])
	GameManager.go_to_map("test_map")

func _on_create_new_character():
	GameManager.go_to_character_creation()

func _on_back_to_menu():
	GameManager.go_to_main_menu()

## 接收场景切换数据并刷新角色列表
func receive_data(data: Dictionary) -> void:
	call_deferred("_refresh_character_list")