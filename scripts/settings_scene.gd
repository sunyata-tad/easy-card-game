## SettingsScene —— 主界面设置场景
## 包装 SettingsContent(SCENE)，"返回"按钮通过 TransitionManager 切回主菜单。
extends Control

const SettingsContent = preload("res://scripts/ui/settings_content.gd")

func _ready() -> void:
	var content = SettingsContent.new()
	content.setup(SettingsContent.Mode.SCENE)
	content.back_requested.connect(func(): TransitionManager.transition(GameManager.go_to_main_menu))
	add_child(content)
	if TransitionManager == null or not TransitionManager.is_transitioning():
		call_deferred("play_entry_animation")

func play_entry_animation() -> void:
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)