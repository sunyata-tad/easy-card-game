## 涟漪/碎片不拦截点击测试：验证涟漪 Panel 与碎片 ColorRect 的 mouse_filter == IGNORE。
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
	var ripple_ignore := true
	var ripple_found := false
	for c in get_tree().root.get_children():
		if c is CanvasLayer and c.layer == 98:
			ripple_found = true
			for cc in c.get_children():
				if cc is Panel and cc.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					ripple_ignore = false
			break
	_check(ripple_found, "涟漪 Panel 已创建")
	_check(ripple_ignore, "涟漪 Panel mouse_filter=IGNORE")
	UIStyle.play_one_shot_disappear(_btn)
	await get_tree().process_frame
	await get_tree().process_frame
	var shard_ignore := true
	var shard_found := false
	for c in get_tree().root.get_children():
		if c is CanvasLayer and c.layer == 99:
			shard_found = true
			for cc in c.get_children():
				if cc is ColorRect and cc.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					shard_ignore = false
			break
	_check(shard_found, "碎片 ColorRect 已创建")
	_check(shard_ignore, "碎片 ColorRect mouse_filter=IGNORE")
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
