## 无头测试：主菜单 start.tscn 加载 + 动画注入 + 入场错峰验证
## 运行方式：godot --headless --path . res://test_start_anim.tscn
extends Node

var fail_count: int = 0
var _elapsed: float = 0.0

func _ready() -> void:
	_run()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 10.0:
		_log("!!! 看门狗超时强制退出")
		get_tree().quit()

func _log(msg: String) -> void:
	print("[START-ANIM-TEST] ", msg)

func _check(cond: bool, label: String) -> void:
	if cond:
		_log("PASS: " + label)
	else:
		fail_count += 1
		_log("FAIL: " + label)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _run() -> void:
	_log("=== 主菜单动画测试开始 ===")
	var start_scene = load("res://scenes/start.tscn").instantiate()
	add_child(start_scene)
	await _wait(0.05)
	var sb = start_scene.get_node_or_null("MenuCenter/MenuBox/Button_start")
	var eb = start_scene.get_node_or_null("MenuCenter/MenuBox/Button_exit")
	_check(sb != null, "开始按钮存在")
	_check(eb != null, "退出按钮存在")
	if sb:
		_check(sb.get_meta("anim_attached", false) == true, "开始按钮已注入 attach_button_anim")
		_check(sb.offset_transform_enabled == true, "开始按钮 offset_transform_enabled=true")
	if eb:
		_check(eb.get_meta("anim_attached", false) == true, "退出按钮已注入 attach_button_anim")
		_check(eb.offset_transform_enabled == true, "退出按钮 offset_transform_enabled=true")
	await _wait(0.6)
	if sb:
		_check(absf(sb.modulate.a - 1.0) < 0.02, "入场后开始按钮 modulate.a ~1 (实际:%s)" % str(sb.modulate.a))
		_check(absf(sb.offset_transform_position.y - 0.0) < 1.0, "入场后开始按钮 position.y ~0 (实际:%s)" % str(sb.offset_transform_position.y))
	if eb:
		_check(absf(eb.modulate.a - 1.0) < 0.02, "入场后退出按钮 modulate.a ~1 (实际:%s)" % str(eb.modulate.a))
	start_scene.queue_free()
	_log("=== 主菜单动画测试结束 ===")
	if fail_count == 0:
		_log(">>> 全部通过")
	else:
		_log(">>> 失败 %d 项" % fail_count)
	get_tree().quit()