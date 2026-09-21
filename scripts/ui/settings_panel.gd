## SettingsPanel —— 设置面板（PopupPanel）
## 上方设置区：界面设置分组（全屏开关[仅PC]）+ 音量设置入口[占位]
## 下方退出区：回到主界面、退出游戏
## 全屏切换自处理（调 SettingsManager.set_setting，自动应用）
## 退出动作通过信号交调用方处理（保存逻辑等由调用方决定）
extends PopupPanel

signal return_main_requested
signal quit_game_requested

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.16, 1.0)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title = Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# ===== 设置区 =====
	var section_lbl = Label.new()
	section_lbl.text = "界面设置"
	section_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(section_lbl)

	# 全屏开关（仅 PC 显示）
	if OS.has_feature("pc"):
		var fullscreen_check = CheckBox.new()
		fullscreen_check.text = "全屏模式"
		fullscreen_check.button_pressed = SettingsManager.get_setting("fullscreen", false)
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
		vbox.add_child(fullscreen_check)

	# 音量设置入口（占位，以后扩展）
	var volume_btn = Button.new()
	volume_btn.text = "音量设置"
	volume_btn.custom_minimum_size = Vector2(220, 36)
	volume_btn.pressed.connect(_on_volume_pressed)
	vbox.add_child(volume_btn)
	UIStyle.attach_button_anim(volume_btn)

	vbox.add_child(HSeparator.new())

	# ===== 退出区 =====
	var return_btn = Button.new()
	return_btn.text = "回到主界面"
	return_btn.custom_minimum_size = Vector2(220, 36)
	return_btn.pressed.connect(func(): hide(); queue_free(); return_main_requested.emit())
	vbox.add_child(return_btn)
	UIStyle.attach_button_anim(return_btn)

	var quit_btn = Button.new()
	quit_btn.text = "退出游戏"
	quit_btn.custom_minimum_size = Vector2(220, 36)
	quit_btn.pressed.connect(func(): hide(); queue_free(); quit_game_requested.emit())
	vbox.add_child(quit_btn)
	UIStyle.attach_button_anim(quit_btn)

	vbox.add_child(HSeparator.new())

	var cancel_btn = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(220, 36)
	cancel_btn.pressed.connect(func(): hide(); queue_free())
	vbox.add_child(cancel_btn)
	UIStyle.attach_button_anim(cancel_btn)

	add_child(vbox)

func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.set_setting("fullscreen", pressed)

func _on_volume_pressed() -> void:
	# 占位：音量设置面板以后扩展
	pass