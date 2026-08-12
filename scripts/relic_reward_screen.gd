## 遗物奖励场景：Boss 战后遗物三选一。
## 逻辑：从遗物池随机 3 件（不可重复者排除已拥有，可重复者始终可选）→ 玩家选 1 → 加入遗物 → 返回地图。
extends Control

var _choices: Array = []   ## 当前展示的三件遗物（RelicData）

func _ready():
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.18, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var title := Label.new()
	title.text = "遗物抉择"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-200, 40)
	title.size = Vector2(400, 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := Label.new()
	sub.text = "Boss 已被击退，从三件遗物中选择一件"
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.position = Vector2(-250, 86)
	sub.size = Vector2(500, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	_choices = _roll_choices()

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	add_child(hbox)

	for relic in _choices:
		hbox.add_child(_make_choice_card(relic))

## 从遗物池抽取 3 件（兜底：池空时给占位遗物，保证流程正常）
func _roll_choices() -> Array:
	var relic_db := RelicDatabase.new()
	var pool: Array = relic_db.get_relic_pool(GameData.get_relics() if GameData else [])
	pool.shuffle()
	var picked: Array = []
	for i in mini(3, pool.size()):
		var relic = relic_db.get_relic(pool[i])
		if relic:
			picked.append(relic)
	if picked.is_empty():
		var fallback = relic_db.get_relic("placeholder_crown")
		if fallback:
			picked.append(fallback)
	return picked

func _make_choice_card(relic: RelicData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 320)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	style.border_color = Color(0.55, 0.45, 0.25, 1)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = relic.name
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = relic.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(desc_lbl)

	if not relic.flavor_text.is_empty():
		var flavor := Label.new()
		flavor.text = "—— %s ——" % relic.flavor_text
		flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavor.add_theme_font_size_override("font_size", 13)
		flavor.add_theme_color_override("font_color", Color(0.62, 0.62, 0.72))
		vbox.add_child(flavor)

	var pick_btn := Button.new()
	pick_btn.text = "选择"
	pick_btn.custom_minimum_size = Vector2(0, 38)
	pick_btn.pressed.connect(_on_pick.bind(relic))
	vbox.add_child(pick_btn)

	return panel

func _on_pick(relic: RelicData) -> void:
	if GameData:
		GameData.grant_relic(relic.id)
	SaveManager.save_map_state()
	var cached = SaveManager.get_cached_map_state()
	GameManager.go_to_map("endless", cached)
