extends SceneTree

func _init():
	var root = Control.new()
	root.name = "TestRoot"
	root.size = Vector2(1152, 648)
	root.set_anchors_preset(15)
	root.theme = load("res://ui/theme.tres")
	get_root().add_child(root)
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(440, 200)
	vbox.custom_minimum_size = Vector2(272, 0)
	vbox.add_theme_constant_override("separation", 20)
	root.add_child(vbox)
	for txt in ["开始游戏", "卡组配置", "设置", "退出游戏"]:
		var b = Button.new()
		b.text = txt
		b.custom_minimum_size = Vector2(260, 54)
		vbox.add_child(b)
	create_timer(1.0).timeout.connect(_shot)

func _shot():
	var img = get_root().get_viewport().get_texture().get_image()
	var path = "D:/游戏开发/项目文件/card/test_scene/button_check.png"
	img.save_png(path)
	print("SAVED ", path)
	quit()