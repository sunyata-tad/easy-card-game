extends SceneTree

func _init():
	var root = Control.new()
	root.name = "TestRoot"
	root.size = Vector2(1152, 648)
	root.set_anchors_preset(15)
	root.theme = load("res://ui/theme.tres")
	get_root().add_child(root)
	var panel = PanelContainer.new()
	panel.position = Vector2(420, 160)
	panel.custom_minimum_size = Vector2(312, 0)
	panel.add_theme_constant_override("separation", 0)
	root.add_child(panel)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.add_theme_constant_override("margin_left", 16)
	vbox.add_theme_constant_override("margin_right", 16)
	vbox.add_theme_constant_override("margin_top", 16)
	vbox.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(vbox)
	for txt in ["开始游戏", "卡组配置", "设置", "退出游戏"]:
		var b = Button.new()
		b.text = txt
		b.custom_minimum_size = Vector2(260, 54)
		vbox.add_child(b)
	var pb = ProgressBar.new()
	pb.custom_minimum_size = Vector2(260, 28)
	pb.value = 65
	pb.max_value = 100
	vbox.add_child(pb)
	create_timer(1.0).timeout.connect(_shot)

func _shot():
	var img = get_root().get_viewport().get_texture().get_image()
	var path = "D:/游戏开发/项目文件/card/test_scene/progress_check.png"
	img.save_png(path)
	print("SAVED ", path)
	quit()