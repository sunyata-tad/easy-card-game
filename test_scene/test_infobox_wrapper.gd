## 测试包装场景：加载主菜单 + 运行信息框集成测试
extends Control

var _test_controller = null

func _ready() -> void:
	call_deferred("_setup")

func _setup() -> void:
	var main_menu = load("res://scenes/start.tscn").instantiate()
	get_tree().root.add_child(main_menu)
	GameManager.current_scene = main_menu
	GameManager.current_scene_type = GameManager.GameScene.MAIN_MENU
	_test_controller = load("res://test_scene/test_infobox_integration.gd").new()
	add_child(_test_controller)