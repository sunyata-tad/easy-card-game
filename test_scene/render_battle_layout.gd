extends SceneTree

var _frame_count = 0

func _init():
	get_root().size = Vector2i(1152, 648)
	get_root().gui_embed_subwindows = true
	var scene = load("res://scenes/BattleScene.tscn").instantiate()
	get_root().add_child(scene)
	process_frame.connect(_on_frame)

func _on_frame():
	_frame_count += 1
	if _frame_count == 30:
		_shot()

func _shot():
	var img = get_root().get_texture().get_image()
	var path = "D:/游戏开发/项目文件/card/test_scene/battle_layout_check.png"
	img.save_png(path)
	print("SAVED ", path)
	quit()