## 选卡界面截图测试：从主菜单进入选卡界面，截图验证UI
extends Control

var _log_path := "user://test_pre_battle_select_log.txt"
var _phase := 0
var _elapsed := 0.0
var _faf

func _ready() -> void:
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 选卡界面截图测试 ===")
	call_deferred("_setup")

func _log(msg: String) -> void:
	if _faf: _faf.store_line(msg)

func _setup() -> void:
	# 初始化游戏数据
	GameData.initialize_new_run()
	CardPoolManager.unlock_all_cards()
	_log("解锁卡池: %d张" % CardPoolManager.get_card_count())
	# 直接加载选卡场景
	var scene = load("res://scenes/PreBattleCardSelect.tscn").instantiate()
	get_tree().root.add_child(scene)
	GameManager.current_scene = scene
	GameManager.current_scene_type = GameManager.GameScene.PRE_BATTLE_SELECT
	scene.receive_data({"enemies": [], "test_mode": false})
	_log("选卡场景加载完成")

func _process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		0:
			if _elapsed > 1.5:
				_take_screenshot("pre_battle_select")
				_log("截图完成")
				_phase = 1
				_elapsed = 0.0
		1:
			if _elapsed > 1.0:
				_log("=== 测试结束 ===")
				if _faf: _faf.close()
				get_tree().quit()

func _take_screenshot(name: String) -> void:
	var img = get_viewport().get_texture().get_image()
	var path = "user://%s.png" % name
	img.save_png(path)
	_log("截图: %s (%dx%d)" % [path, img.get_width(), img.get_height()])