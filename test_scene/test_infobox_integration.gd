## 集成测试：从主菜单进入卡组配置，点击卡牌验证 info box 显示
extends Control

var _log_path := "user://test_infobox_log.txt"
var _shot_path := "user://test_infobox_shot.png"
var _phase := 0
var _elapsed := 0.0
var _faf

func _ready() -> void:
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 信息框集成测试开始 ===")
	_log("phase 0: 等待主菜单加载")

func _log(msg: String) -> void:
	if _faf:
		_faf.store_line(msg)

func _process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		0:
			if _elapsed > 2.0:
				_click_deck_config()
				_phase = 1
				_elapsed = 0.0
		1:
			if _elapsed > 3.0:
				_click_library_card()
				_phase = 2
				_elapsed = 0.0
		2:
			if _elapsed > 1.5:
				_verify_and_screenshot()
				_phase = 3
		3:
			if _elapsed > 1.0:
				_log("=== 测试结束 ===")
				if _faf:
					_faf.close()
				get_tree().quit()

func _click_deck_config() -> void:
	var root = GameManager.current_scene
	_log("当前场景: " + (root.name if root else "null"))
	if root == null:
		_log("FAIL: current_scene 为空")
		return
	var btn = root.get_node_or_null("MenuCenter/MenuBox/Button_deck_config")
	if btn == null:
		_log("FAIL: 未找到卡组配置按钮")
		return
	_log("找到卡组配置按钮: " + str(btn.global_position) + " size=" + str(btn.size))
	GameManager.go_to_deck_config()
	_log("已调用 GameManager.go_to_deck_config()")

func _click_library_card() -> void:
	var root = GameManager.current_scene
	_log("phase 1 当前场景: " + (root.name if root else "null"))
	if root == null:
		_log("FAIL: current_scene 为空")
		return
	var lib_grid = root.get_node_or_null("MainArea/RightPanel/RightVBox/LibScroll/LibraryGrid")
	if lib_grid == null:
		_log("FAIL: 未找到卡牌库网格")
		return
	_log("卡牌库网格子节点数: " + str(lib_grid.get_child_count()))
	if lib_grid.get_child_count() == 0:
		_log("FAIL: 卡牌库为空")
		return
	for test_id in ["薄葬", "批命", "必然杀"]:
		if root.has_method("_show_card_detail"):
			root._show_card_detail(test_id)
			await get_tree().create_timer(0.3).timeout
			_check_info_box(root, test_id)
		else:
			_log("FAIL: 场景无 _show_card_detail 方法")

func _check_info_box(root, card_id: String) -> void:
	var info_box = root.get("_detail_info_box")
	if info_box and is_instance_valid(info_box):
		_log("PASS [" + card_id + "]: info_box 存在且有效 visible=" + str(info_box.visible))
		var vbox = info_box.get_child(0) if info_box.get_child_count() > 0 else null
		if vbox:
			_log("  子节点数: " + str(vbox.get_child_count()))
			for i in vbox.get_child_count():
				var c = vbox.get_child(i)
				if c is RichTextLabel:
					_log("  子[" + str(i) + "] text=" + c.text)
	else:
		_log("INFO [" + card_id + "]: info_box 为空")

func _verify_and_screenshot() -> void:
	var root = GameManager.current_scene
	_log("phase 2 当前场景: " + (root.name if root else "null"))
	var tex = get_viewport().get_texture()
	if tex:
		var img = tex.get_image()
		if img:
			var err = img.save_png(_shot_path)
			_log("截图保存: " + _shot_path + " err=" + str(err))
		else:
			_log("INFO: 无法获取图像（headless模式）")
	else:
		_log("INFO: 无视口纹理（headless模式）")