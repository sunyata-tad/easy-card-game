extends SceneTree

func _init():
	var root = Control.new()
	root.name = "TestRoot"
	root.size = Vector2(1152, 648)
	root.set_anchors_preset(15)
	get_root().add_child(root)
	var card = load("res://scenes/Card.tscn").instantiate()
	card.position = Vector2((1152 - 160) / 2.0, (648 - 210) / 2.0)
	root.add_child(card)
	create_timer(1.0).timeout.connect(_shot)

func _shot():
	var img = get_root().get_viewport().get_texture().get_image()
	var path = "D:/游戏开发/项目文件/card/test_scene/card_frame_check.png"
	img.save_png(path)
	print("SAVED ", path)
	quit()