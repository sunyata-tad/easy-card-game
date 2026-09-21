## SettingsContent —— 设置 UI 内容（菜单/子页面导航）
## 两种模式：
##   POPUP：游戏内弹窗，主页面退出区=回到主界面+退出游戏
##   SCENE：主界面设置场景，主页面退出区=返回（回主菜单）
## 由 SettingsPanel（弹窗）和 SettingsScene（场景）包装使用
## extends VBoxContainer：让 minimum_size 自动由子节点决定，PopupPanel 可正确自适应大小
extends VBoxContainer

enum Mode { POPUP, SCENE }

signal return_main_requested
signal quit_game_requested
signal back_requested

var _mode: int = Mode.POPUP

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	if _mode == Mode.SCENE:
		set_anchors_preset(PRESET_FULL_RECT)
	_show_main_page()

func setup(mode: int) -> void:
	_mode = mode

func _clear_content() -> void:
	for c in get_children():
		c.queue_free()

func _show_main_page() -> void:
	_clear_content()

	var title = Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	add_child(HSeparator.new())

	var interface_btn = Button.new()
	interface_btn.text = "界面设置"
	interface_btn.custom_minimum_size = Vector2(220, 36)
	interface_btn.pressed.connect(_show_interface_page)
	add_child(interface_btn)
	UIStyle.attach_button_anim(interface_btn)

	var volume_btn = Button.new()
	volume_btn.text = "音量设置"
	volume_btn.custom_minimum_size = Vector2(220, 36)
	volume_btn.pressed.connect(_show_volume_page)
	add_child(volume_btn)
	UIStyle.attach_button_anim(volume_btn)

	add_child(HSeparator.new())

	if _mode == Mode.POPUP:
		var return_btn = Button.new()
		return_btn.text = "回到主界面"
		return_btn.custom_minimum_size = Vector2(220, 36)
		return_btn.pressed.connect(func(): return_main_requested.emit())
		add_child(return_btn)
		UIStyle.attach_button_anim(return_btn)

		var quit_btn = Button.new()
		quit_btn.text = "退出游戏"
		quit_btn.custom_minimum_size = Vector2(220, 36)
		quit_btn.pressed.connect(func(): quit_game_requested.emit())
		add_child(quit_btn)
		UIStyle.attach_button_anim(quit_btn)
	else:
		var back_btn = Button.new()
		back_btn.text = "返回"
		back_btn.custom_minimum_size = Vector2(220, 36)
		back_btn.pressed.connect(func(): back_requested.emit())
		add_child(back_btn)
		UIStyle.attach_button_anim(back_btn)

func _show_interface_page() -> void:
	_clear_content()

	var title = Label.new()
	title.text = "界面设置"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	add_child(HSeparator.new())

	if OS.has_feature("pc"):
		var fullscreen_check = CheckBox.new()
		fullscreen_check.text = "全屏模式"
		fullscreen_check.button_pressed = SettingsManager.get_setting("fullscreen", false)
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
		add_child(fullscreen_check)
	else:
		var hint = Label.new()
		hint.text = "（移动端无界面设置项）"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(hint)

	add_child(HSeparator.new())

	_add_back_to_main_btn()

func _show_volume_page() -> void:
	_clear_content()

	var title = Label.new()
	title.text = "音量设置"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	add_child(HSeparator.new())

	var hint = Label.new()
	hint.text = "功能开发中"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	add_child(HSeparator.new())

	_add_back_to_main_btn()

func _add_back_to_main_btn() -> void:
	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(220, 36)
	back_btn.pressed.connect(_show_main_page)
	add_child(back_btn)
	UIStyle.attach_button_anim(back_btn)

func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.set_setting("fullscreen", pressed)
