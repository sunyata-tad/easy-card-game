extends SceneTree

var _frame_count = 0

func _init():
	get_root().size = Vector2i(1152, 648)
	get_root().gui_embed_subwindows = true
	var root = Control.new()
	root.name = "TestRoot"
	root.set_anchors_preset(15)
	root.size = Vector2(1152, 648)
	root.theme = load("res://ui/theme.tres")
	get_root().add_child(root)
	var panel = PanelContainer.new()
	panel.position = Vector2(380, 120)
	panel.custom_minimum_size = Vector2(380, 0)
	panel.add_theme_constant_override("separation", 0)
	root.add_child(panel)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.add_theme_constant_override("margin_left", 16)
	vbox.add_theme_constant_override("margin_right", 16)
	vbox.add_theme_constant_override("margin_top", 16)
	vbox.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(vbox)
	for txt in ["开始游戏", "卡组配置", "设置", "退出游戏"]:
		var b = Button.new()
		b.text = txt
		b.custom_minimum_size = Vector2(300, 50)
		vbox.add_child(b)
	var pb = ProgressBar.new()
	pb.custom_minimum_size = Vector2(300, 24)
	pb.value = 65
	pb.max_value = 100
	vbox.add_child(pb)
	var le = LineEdit.new()
	le.text = "输入玩家名字"
	le.custom_minimum_size = Vector2(300, 40)
	vbox.add_child(le)
	var sc = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(300, 90)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(sc)
	var inner = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	for i in range(12):
		var l = Label.new()
		l.text = "卷轴第 %d 行 像素风格测试" % (i + 1)
		inner.add_child(l)
	process_frame.connect(_on_frame)

func _on_frame():
	_frame_count += 1
	if _frame_count == 30:
		_shot()

func _shot():
	var img = get_root().get_texture().get_image()
	var path = "D:/游戏开发/项目文件/card/test_scene/progress_check.png"
	img.save_png(path)
	print("SAVED ", path)
	quit()