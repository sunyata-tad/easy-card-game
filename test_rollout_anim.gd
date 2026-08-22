## 铺开验证测试：确认所有修改脚本编译通过 + 安全场景的按钮已注入 anim。
extends Node

const SCRIPTS := [
	"res://scripts/ui_style.gd",
	"res://scripts/ui/animated_button.gd",
	"res://scripts/battle/ui_controller.gd",
	"res://scripts/battle.gd",
	"res://scripts/map_screen.gd",
	"res://scripts/relic_list_panel.gd",
	"res://scripts/relic_choice_card.gd",
	"res://scripts/game_over_screen.gd",
	"res://scripts/reward_screen.gd",
	"res://scripts/character_select_screen.gd",
	"res://scripts/character_creation_screen.gd",
	"res://scripts/start.gd",
]

var _done := false
var _timeout := 0.0
var _pass := 0
var _fail := 0

func _ready():
	_run()

func _run():
	for path in SCRIPTS:
		var scr = load(path)
		if scr == null:
			_report(false, "load %s" % path)
		else:
			_report(true, "load %s" % path)
	await _check_scene("res://scenes/GameOverScreen.tscn", ["RestartButton", "QuitButton"])
	await _check_scene("res://scenes/CharacterSelectScreen.tscn", ["ButtonContainer/CreateButton", "ButtonContainer/SelectButton", "ButtonContainer/DeleteButton", "ButtonContainer/BackButton"])
	await _check_scene("res://scenes/CharacterCreationScreen.tscn", ["ButtonContainer/PrevButton", "ButtonContainer/NextButton", "ButtonContainer/CancelButton"])
	print("=== SUMMARY: %d PASS, %d FAIL ===" % [_pass, _fail])
	_done = true

func _check_scene(scene_path: String, button_paths: Array):
	var scene = load(scene_path)
	if scene == null:
		_report(false, "load scene %s" % scene_path)
		return
	var inst = scene.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	for bp in button_paths:
		var btn = inst.get_node_or_null(bp)
		if btn == null:
			_report(false, "%s 节点 %s 不存在" % [scene_path, bp])
		elif btn.has_meta("anim_attached"):
			_report(true, "%s:%s 已注入 anim" % [scene_path.get_file(), bp])
		else:
			_report(false, "%s:%s 未注入 anim" % [scene_path.get_file(), bp])
	inst.queue_free()

func _report(ok: bool, label: String):
	if ok:
		_pass += 1
		print("PASS %s" % label)
	else:
		_fail += 1
		print("FAIL %s" % label)

func _process(delta):
	_timeout += delta
	if _done or _timeout > 20.0:
		if not _done:
			print("TIMEOUT")
		get_tree().quit()