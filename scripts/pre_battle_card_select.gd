## 战斗前信息显示场景：左侧敌人信息 + 右侧我方信息与卡组
## 流程：地图请求战斗 → 本场景 → 编辑卡组/直接出战 → 进入战斗
extends Control

var _card_db: CardDatabase = CardDatabase.new()
var _pending_enemies: Array = []     ## 待战斗的敌人列表
var _test_mode: bool = false
var _deck_cards: Array = []          ## 当前卡组卡牌

## UI节点
var _enemy_list: VBoxContainer
var _deck_grid: GridContainer
var _deck_count_label: Label
var _confirm_btn: Button

func _ready() -> void:
	_build_ui()
	_refresh_all()

## 接收数据（从GameManager.change_scene传入）
func receive_data(data: Dictionary) -> void:
	_pending_enemies = data.get("enemies", [])
	_test_mode = data.get("test_mode", false)
	call_deferred("_refresh_all")

## 构建UI
func _build_ui() -> void:
	var vp_size = get_viewport_rect().size
	# 背景
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 标题
	var title = Label.new()
	title.text = "战斗准备"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	title.horizontal_alignment = 1
	title.position = Vector2(0, 12)
	title.size = Vector2(vp_size.x, 40)
	add_child(title)

	# ===== 左侧：敌人信息 =====
	var left_panel = PanelContainer.new()
	left_panel.position = Vector2(20, 70)
	left_panel.size = Vector2(vp_size.x * 0.45, vp_size.y - 180)
	_apply_panel_style(left_panel, Color(0.5, 0.3, 0.3, 0.6))
	add_child(left_panel)
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)
	var enemy_title = Label.new()
	enemy_title.text = "敌方信息"
	enemy_title.add_theme_font_size_override("font_size", 18)
	enemy_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	left_vbox.add_child(enemy_title)
	_enemy_list = VBoxContainer.new()
	_enemy_list.add_theme_constant_override("separation", 10)
	left_vbox.add_child(_enemy_list)

	# ===== 右侧：我方信息 =====
	var right_panel = PanelContainer.new()
	right_panel.position = Vector2(vp_size.x * 0.47, 70)
	right_panel.size = Vector2(vp_size.x * 0.51, vp_size.y - 180)
	_apply_panel_style(right_panel, Color(0.3, 0.4, 0.5, 0.6))
	add_child(right_panel)
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)
	var my_title = Label.new()
	my_title.text = "我方信息"
	my_title.add_theme_font_size_override("font_size", 18)
	my_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	right_vbox.add_child(my_title)
	# 编辑卡组按钮
	var edit_btn = Button.new()
	edit_btn.text = "编辑卡组"
	edit_btn.custom_minimum_size = Vector2(100, 32)
	edit_btn.pressed.connect(_on_edit_deck)
	right_vbox.add_child(edit_btn)
	UIStyle.attach_button_anim(edit_btn)
	# 卡组标题
	_deck_count_label = Label.new()
	_deck_count_label.text = "战斗卡组"
	_deck_count_label.add_theme_font_size_override("font_size", 14)
	_deck_count_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	right_vbox.add_child(_deck_count_label)
	# 卡组网格
	var deck_scroll = ScrollContainer.new()
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(deck_scroll)
	_deck_grid = GridContainer.new()
	_deck_grid.columns = 3
	_deck_grid.add_theme_constant_override("h_separation", 6)
	_deck_grid.add_theme_constant_override("v_separation", 6)
	deck_scroll.add_child(_deck_grid)

	# ===== 底部按钮 =====
	_confirm_btn = Button.new()
	_confirm_btn.text = "出战"
	_confirm_btn.custom_minimum_size = Vector2(140, 50)
	_confirm_btn.add_theme_font_size_override("font_size", 20)
	_confirm_btn.position = Vector2(vp_size.x - 170, vp_size.y - 80)
	_confirm_btn.pressed.connect(_on_confirm)
	add_child(_confirm_btn)
	UIStyle.attach_button_anim(_confirm_btn)

	var back_btn = Button.new()
	back_btn.text = "返回地图"
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.position = Vector2(30, vp_size.y - 80)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)
	UIStyle.attach_button_anim(back_btn)

func _apply_panel_style(panel: PanelContainer, border_color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

## 刷新所有显示
func _refresh_all() -> void:
	_refresh_enemy_info()
	_refresh_my_deck()

## 刷新敌人信息（不含卡组）
func _refresh_enemy_info() -> void:
	if _enemy_list == null:
		return
	for child in _enemy_list.get_children():
		child.queue_free()
	if _pending_enemies.is_empty():
		var empty = Label.new()
		empty.text = "（无敌人）"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_enemy_list.add_child(empty)
		return
	for enemy_data in _pending_enemies:
		var card = PanelContainer.new()
		_apply_enemy_card_style(card)
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		card.add_child(vbox)
		# 敌人名称
		var name_label = Label.new()
		name_label.text = enemy_data.name
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
		vbox.add_child(name_label)
		# 血量
		var hp_label = Label.new()
		hp_label.text = "生命值: %d" % enemy_data.max_hp
		hp_label.add_theme_font_size_override("font_size", 13)
		hp_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
		vbox.add_child(hp_label)
		# AI类型
		var ai_label = Label.new()
		ai_label.text = "行动模式: %s" % _ai_type_cn(enemy_data.ai_type)
		ai_label.add_theme_font_size_override("font_size", 13)
		ai_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		vbox.add_child(ai_label)
		# 描述/被动
		if enemy_data.description != "":
			var desc_label = Label.new()
			desc_label.text = enemy_data.description
			desc_label.add_theme_font_size_override("font_size", 12)
			desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_label.custom_minimum_size = Vector2(300, 0)
			vbox.add_child(desc_label)
		_enemy_list.add_child(card)

func _apply_enemy_card_style(card: PanelContainer) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.06, 0.08, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.6, 0.3, 0.3, 0.7)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

func _ai_type_cn(ai_type: String) -> String:
	match ai_type:
		"aggressive": return "激进"
		"defensive": return "防御"
		"balanced": return "均衡"
		_: return ai_type

## 刷新我方卡组
func _refresh_my_deck() -> void:
	if _deck_grid == null:
		return
	for child in _deck_grid.get_children():
		child.queue_free()
	_deck_cards = GameData.get_deck()
	_deck_count_label.text = "战斗卡组 (%d张)" % _deck_cards.size()
	# 按卡牌逐个展开显示（含重复）
	for card in _deck_cards:
		var node = _create_deck_card_preview(card, 1)
		_deck_grid.add_child(node)

## 创建卡组卡牌预览
func _create_deck_card_preview(card: CardData, count: int) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(90, 110)
	var rarity_color = {"basic": Color(0.6, 0.6, 0.6), "common": Color(0.3, 0.8, 0.3), "uncommon": Color(0.3, 0.5, 0.9), "rare": Color(0.8, 0.5, 0.9), "epic": Color(1.0, 0.7, 0.2)}.get(card.rarity, Color(0.5, 0.5, 0.5))
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = rarity_color
	style.set_corner_radius_all(5)
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	# 费用+名称
	var top = HBoxContainer.new()
	vbox.add_child(top)
	var cost_label = Label.new()
	cost_label.text = "%d" % card.cost
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	top.add_child(cost_label)
	var name_label = Label.new()
	name_label.text = card.name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top.add_child(name_label)
	# 描述
	var desc_label = Label.new()
	desc_label.text = card.description
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(82, 0)
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)
	# 数量标记
	if count > 1:
		var count_label = Label.new()
		count_label.text = "x%d" % count
		count_label.add_theme_font_size_override("font_size", 11)
		count_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		count_label.horizontal_alignment = 2
		vbox.add_child(count_label)
	return panel

## 编辑卡组：进入卡组编辑界面（返回时回到本界面）
func _on_edit_deck() -> void:
	GameManager.go_to_deck_config_from_prebattle(_pending_enemies, _test_mode)

## 确认出战
func _on_confirm() -> void:
	GameManager.start_battle(_pending_enemies, _test_mode)

## 返回地图
func _on_back() -> void:
	GameManager.go_to_map()