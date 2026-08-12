## 无头测试：通用持有遗物面板（RelicListPanel）
## 覆盖：多遗物填充 / 标题计数 / 行数与默认详情 / 空列表兜底
## 运行方式：godot --headless --path . res://test_relic_panel.tscn
extends Node

var fail_count: int = 0
var _elapsed: float = 0.0

func _ready() -> void:
	_run()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 12.0:
		_log("!!! 看门狗超时强制退出")
		get_tree().quit()

func _log(msg: String) -> void:
	print("[RELIC-PANEL-TEST] ", msg)

func _check(cond: bool, label: String) -> void:
	if cond:
		_log("PASS: " + label)
	else:
		fail_count += 1
		_log("FAIL: " + label)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _run() -> void:
	_log("=== 遗物面板测试开始 ===")
	GameData.initialize_new_run()
	GameData.grant_relic("immortal_cycle")
	GameData.grant_relic("placeholder_crown")
	GameData.grant_relic("placeholder_crown")  # 可重复允许重复

	# 多遗物：面板填充（不去重，实得 3 个实例：终末轮回 + 头环×2）
	var panel = load("res://scenes/RelicListPanel.tscn").instantiate()
	add_child(panel)
	panel.setup(GameData.get_relics())
	await _wait(0.1)

	var title: Label = panel.get_node("Margin/VBox/TitleLabel")
	_check(title.text.contains("3"), "标题计数显示3 (实际:%s)" % title.text)
	var list: VBoxContainer = panel.get_node("Margin/VBox/HBox/Scroll/List")
	_check(list.get_child_count() == 3, "列表行数=3 (实际:%d)" % list.get_child_count())
	var detail: Label = panel.get_node("Margin/VBox/HBox/DetailLabel")
	_check(detail.text.contains("终末轮回"), "默认详情显示第一个遗物 终末轮回")

	# 数据层：不去重（重复头环保留为多个实例）
	var ids: Array = GameData.get_relic_ids()
	_check(ids.size() == 3 and ids.count("placeholder_crown") == 2,
		"不去重：3个遗物id、头环×2 (实际:%s)" % str(ids))

	# 存档往返：遗物持久化（重复保留）
	var saved = SaveManager._serialize_game_data()
	var saved_ids: Array = saved.get("relics", [])
	_check(saved_ids.size() == 3 and saved_ids.count("placeholder_crown") == 2,
		"存档序列化保留3个遗物(含重复头环)")
	SaveManager.apply_game_data({"game_data": saved})
	_check(GameData.get_relics().size() == 3, "读档恢复3个遗物实例")

	# 大量遗物（构造含重复头环的数组）：面板应能容纳任意数量行（滚动）
	var db := RelicDatabase.new()
	var many: Array = []
	for i in 5:
		many.append(db.get_relic("placeholder_crown"))
	many.append(db.get_relic("immortal_cycle"))
	var panel3 = load("res://scenes/RelicListPanel.tscn").instantiate()
	add_child(panel3)
	panel3.setup(many)
	await _wait(0.1)
	var list3: VBoxContainer = panel3.get_node("Margin/VBox/HBox/Scroll/List")
	_check(list3.get_child_count() == 6, "大量遗物(6)行数=6 (实际:%d)" % list3.get_child_count())

	# 空列表兜底
	var panel2 = load("res://scenes/RelicListPanel.tscn").instantiate()
	add_child(panel2)
	panel2.setup([])
	await _wait(0.1)
	var detail2: Label = panel2.get_node("Margin/VBox/HBox/DetailLabel")
	_check(detail2.text.contains("没有遗物"), "空列表显示'当前没有遗物'")

	_log("=== 遗物面板测试结束 ===")
	if fail_count == 0:
		_log(">>> 全部通过")
	else:
		_log(">>> 失败 %d 项" % fail_count)
	get_tree().quit()
