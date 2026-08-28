## 连点测试：验证复原动画期间 button_down 仍能触发缩回动画 + 涟漪每次创建。
extends Node

var _timeout := 0.0
var _done := false
var _pass := 0
var _fail := 0
var _btn: Button

func _ready():
	_run()

func _run():
	await get_tree().process_frame
	await get_tree().process_frame
	_btn = Button.new()
	_btn.size = Vector2(100, 40)
	_btn.position = Vector2(50, 50)
	add_child(_btn)
	UIStyle.attach_button_anim(_btn)
	_btn.emit_signal("button_down")
	await get_tree().process_frame
	await get_tree().process_frame
	var s1 := _btn.offset_transform_scale.x
	_check(s1 < 0.99, "第1次按下 scale.x<0.99 (实际:%s)" % s1)
	_btn.emit_signal("button_up")
	await get_tree().create_timer(0.02).timeout
	var s_mid := _btn.offset_transform_scale.x
	_check(s_mid > s1, "复原中 scale 回升 (实际 mid:%s down:%s)" % [s_mid, s1])
	_btn.emit_signal("button_down")
	await get_tree().process_frame
	await get_tree().process_frame
	var s2 := _btn.offset_transform_scale.x
	_check(s2 < 0.97, "复原中再按 scale.x<0.97 (实际:%s)" % s2)
	var ripple_layers := 0
	for c in get_tree().root.get_children():
		if c is CanvasLayer and c.layer == 98:
			ripple_layers += 1
	_check(ripple_layers >= 2, "至少 2 个涟漪层 (实际:%s)" % ripple_layers)
	print("=== SUMMARY: %d PASS, %d FAIL ===" % [_pass, _fail])
	_done = true

func _check(ok: bool, label: String):
	if ok:
		_pass += 1
		print("PASS %s" % label)
	else:
		_fail += 1
		print("FAIL %s" % label)

func _process(delta):
	_timeout += delta
	if _done or _timeout > 10.0:
		if not _done:
			print("TIMEOUT")
		get_tree().quit()