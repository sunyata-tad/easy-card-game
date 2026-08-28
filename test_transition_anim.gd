## 过渡动画测试：验证 TransitionManager 流程 + play_button_vanish + spawn_shards + play_press_ripple + 按下涟漪。
extends Node

var _timeout := 0.0
var _done := false
var _pass := 0
var _fail := 0
var _reentered := false

func _ready():
	_run()

func _run():
	_check(TransitionManager != null, "TransitionManager 存在")
	var btn: Button = Button.new()
	btn.text = "测试"
	btn.size = Vector2(100, 40)
	btn.position = Vector2(50, 50)
	add_child(btn)
	UIStyle.attach_button_anim(btn)
	UIStyle.play_button_vanish(btn, 0.15)
	await get_tree().create_timer(0.25).timeout
	_check(btn.offset_transform_scale.y < 0.1, "vanish scale.y≈0 (实际:%s)" % btn.offset_transform_scale.y)
	_check(btn.modulate.a < 0.1, "vanish modulate.a≈0 (实际:%s)" % btn.modulate.a)
	UIStyle.spawn_shards(btn, 8)
	await get_tree().process_frame
	_check(_find_canvas_layer(99) != null, "spawn_shards 创建 CanvasLayer(99)")
	await get_tree().create_timer(0.6).timeout
	UIStyle.play_press_ripple(btn)
	await get_tree().process_frame
	_check(_find_canvas_layer(98) != null, "play_press_ripple 创建 CanvasLayer(98)")
	await get_tree().create_timer(0.5).timeout
	var btn2: Button = Button.new()
	btn2.text = "涟漪"
	btn2.size = Vector2(100, 40)
	btn2.position = Vector2(50, 100)
	add_child(btn2)
	UIStyle.attach_button_anim(btn2)
	btn2.emit_signal("button_down")
	await get_tree().process_frame
	_check(_find_canvas_layer(98) != null, "button_down 触发涟漪")
	await get_tree().create_timer(0.5).timeout
	var btn3: Button = Button.new()
	btn3.text = "过渡"
	btn3.size = Vector2(100, 40)
	btn3.position = Vector2(50, 150)
	add_child(btn3)
	TransitionManager.transition(func(): pass, btn3)
	await get_tree().create_timer(0.1).timeout
	_check(TransitionManager.is_transitioning(), "transition 开始 is_transitioning=true")
	await get_tree().create_timer(1.3).timeout
	_check(not TransitionManager.is_transitioning(), "transition 完成 is_transitioning=false")
	var btn4: Button = Button.new()
	btn4.text = "重入"
	btn4.size = Vector2(100, 40)
	btn4.position = Vector2(50, 200)
	add_child(btn4)
	var reentered := false
	TransitionManager.transition(func(): pass, btn4)
	await get_tree().create_timer(0.1).timeout
	TransitionManager.transition(func(): _reentered = true, null)
	await get_tree().create_timer(1.5).timeout
	_check(_reentered, "重入 transition 立即执行 callable (_reentered=true)")
	_check(not TransitionManager.is_transitioning(), "重入后 is_transitioning=false")
	print("=== SUMMARY: %d PASS, %d FAIL ===" % [_pass, _fail])
	_done = true

func _find_canvas_layer(layer: int) -> Node:
	for c in get_tree().root.get_children():
		if c is CanvasLayer and c.layer == layer:
			return c
	return null

func _check(ok: bool, label: String):
	if ok:
		_pass += 1
		print("PASS %s" % label)
	else:
		_fail += 1
		print("FAIL %s" % label)

func _process(delta):
	_timeout += delta
	if _done or _timeout > 15.0:
		if not _done:
			print("TIMEOUT")
		get_tree().quit()