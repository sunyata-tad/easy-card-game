## 无头测试：4.7 Offset Transform UI 动画（AnimatedButton 注入/脚本 + slide_in/stagger_in/slide_out）
## 运行方式：godot --headless --path . res://test_ui_anim.tscn
extends Node

var fail_count: int = 0
var _elapsed: float = 0.0

func _ready() -> void:
	_run()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 15.0:
		_log("!!! 看门狗超时强制退出")
		get_tree().quit()

func _log(msg: String) -> void:
	print("[UI-ANIM-TEST] ", msg)

func _check(cond: bool, label: String) -> void:
	if cond:
		_log("PASS: " + label)
	else:
		fail_count += 1
		_log("FAIL: " + label)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _run() -> void:
	_log("=== UI 动画测试开始 ===")

	# --- 块1 注入函数 attach_button_anim ---
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 40)
	add_child(btn)
	UIStyle.attach_button_anim(btn)
	_check(btn.offset_transform_enabled == true, "attach_button_anim 开启 offset_transform_enabled")
	_check(btn.get_meta("anim_attached", false) == true, "attach 设置 anim_attached 标记")
	UIStyle.attach_button_anim(btn)
	_check(btn.mouse_entered.get_connections().size() == 1, "重复 attach 不重复连接信号")
	btn.emit_signal("mouse_entered")
	await _wait(0.2)
	_check(btn.offset_transform_scale.x > 1.0, "悬停后 scale.x > 1.0 (实际:%s)" % str(btn.offset_transform_scale))
	btn.emit_signal("mouse_exited")
	await _wait(0.2)
	_check(absf(btn.offset_transform_scale.x - 1.0) < 0.01, "移出后 scale 回到 ~1.0 (实际:%s)" % str(btn.offset_transform_scale))
	btn.emit_signal("button_down")
	await _wait(0.1)
	_check(btn.offset_transform_scale.x < 1.0, "按下后 scale.x < 1.0 挤压 (实际:%s)" % str(btn.offset_transform_scale))
	btn.emit_signal("button_up")
	await _wait(0.15)
	_check(absf(btn.offset_transform_scale.x - 1.0) < 0.01, "释放后 scale 回到 ~1.0 (实际:%s)" % str(btn.offset_transform_scale))
	btn.queue_free()

	# --- 块1 独立脚本 animated_button.gd ---
	var btn2 := Button.new()
	btn2.set_script(load("res://scripts/ui/animated_button.gd"))
	add_child(btn2)
	await _wait(0.05)
	_check(btn2.offset_transform_enabled == true, "animated_button.gd 脚本开启 offset_transform_enabled")
	btn2.emit_signal("mouse_entered")
	await _wait(0.2)
	_check(btn2.offset_transform_scale.x > 1.0, "脚本按钮悬停 scale.x > 1.0 (实际:%s)" % str(btn2.offset_transform_scale))
	btn2.emit_signal("mouse_exited")
	await _wait(0.2)
	_check(absf(btn2.offset_transform_scale.x - 1.0) < 0.01, "脚本按钮移出 scale 回到 ~1.0")
	btn2.queue_free()

	# --- 块2 slide_in / stagger_in ---
	var c1 := Control.new()
	c1.custom_minimum_size = Vector2(100, 40)
	add_child(c1)
	var c2 := Control.new()
	c2.custom_minimum_size = Vector2(100, 40)
	add_child(c2)
	var tweens: Array = UIStyle.stagger_in([c1, c2], Vector2(0, 80), 0.3, 0.06)
	_check(tweens.size() == 2, "stagger_in 返回 2 个 Tween")
	_check(c1.offset_transform_enabled == true, "stagger_in 开启 c1 offset_transform_enabled")
	_check(absf(c1.offset_transform_position.y - 80.0) < 0.01, "c1 初始 offset_transform_position.y=80 (实际:%s)" % str(c1.offset_transform_position.y))
	_check(absf(c1.modulate.a - 0.0) < 0.01, "c1 初始 modulate.a=0")
	_check(absf(c2.offset_transform_position.y - 80.0) < 0.01, "c2 初始 offset_transform_position.y=80")
	await _wait(0.6)
	_check(absf(c1.offset_transform_position.y - 0.0) < 1.0, "c1 动画后 position.y ~0 (实际:%s)" % str(c1.offset_transform_position.y))
	_check(absf(c1.modulate.a - 1.0) < 0.01, "c1 动画后 modulate.a ~1 (实际:%s)" % str(c1.modulate.a))
	_check(absf(c2.modulate.a - 1.0) < 0.01, "c2 动画后 modulate.a ~1 (实际:%s)" % str(c2.modulate.a))
	c1.queue_free()
	c2.queue_free()

	# --- 块2 slide_out ---
	var c3 := Control.new()
	c3.custom_minimum_size = Vector2(100, 40)
	add_child(c3)
	c3.offset_transform_enabled = true
	c3.modulate.a = 1.0
	UIStyle.slide_out(c3, Vector2(0, 60), 0.3)
	await _wait(0.5)
	_check(c3.visible == false, "slide_out 结束后 visible=false")
	_check(absf(c3.modulate.a - 0.0) < 0.01, "slide_out 后 modulate.a ~0")
	c3.queue_free()

	_log("=== UI 动画测试结束 ===")
	if fail_count == 0:
		_log(">>> 全部通过")
	else:
		_log(">>> 失败 %d 项" % fail_count)
	get_tree().quit()