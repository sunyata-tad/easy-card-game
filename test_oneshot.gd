## 一次性按钮消失测试：验证 play_one_shot_disappear 禁用+动画+回调。
extends Node

var _timeout := 0.0
var _done := false
var _pass := 0
var _fail := 0
var _callback_called := false

func _ready():
	_run()

func _run():
	await get_tree().process_frame
	await get_tree().process_frame
	var btn: Button = Button.new()
	btn.text = "宝箱"
	btn.size = Vector2(100, 40)
	btn.position = Vector2(50, 50)
	add_child(btn)
	UIStyle.attach_button_anim(btn)
	UIStyle.play_one_shot_disappear(btn, func(): _callback_called = true)
	_check(btn.disabled, "按钮已禁用")
	await get_tree().create_timer(0.3).timeout
	_check(btn.offset_transform_scale.y < 0.1, "消失 scale.y≈0 (实际:%s)" % btn.offset_transform_scale.y)
	_check(btn.modulate.a < 0.1, "消失 modulate.a≈0 (实际:%s)" % btn.modulate.a)
	_check(_callback_called, "回调已调用")
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