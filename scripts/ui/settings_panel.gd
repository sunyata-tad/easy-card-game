## SettingsPanel —— 设置面板（PopupPanel，游戏内弹窗模式）
## 包装 SettingsContent(POPUP)，点菜单以外区域关闭。
## 退出动作通过信号交调用方处理（保存逻辑等由调用方决定）。
extends PopupPanel

const SettingsContent = preload("res://scripts/ui/settings_content.gd")

signal return_main_requested
signal quit_game_requested

func _ready() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.16, 1.0)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var content = SettingsContent.new()
	content.setup(SettingsContent.Mode.POPUP)
	content.return_main_requested.connect(func(): hide(); queue_free(); return_main_requested.emit())
	content.quit_game_requested.connect(func(): hide(); queue_free(); quit_game_requested.emit())
	add_child(content)
