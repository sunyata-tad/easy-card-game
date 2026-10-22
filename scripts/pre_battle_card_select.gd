## 战斗前选卡场景：从大卡池（所有解锁卡）选~9张组成战斗卡组
## 流程：地图请求战斗 → 本场景选卡 → 确认后进入战斗
extends Control

const TARGET_DECK_SIZE := 9  ## 目标卡组大小

const RARITY_COLOR := {
	"basic": Color(0.6, 0.6, 0.6),
	"common": Color(0.3, 0.8, 0.3),
	"uncommon": Color(0.3, 0.5, 0.9),
	"rare": Color(0.8, 0.5, 0.9),
	"epic": Color(1.0, 0.7, 0.2),
}
const TYPE_CN := {"attack": "攻", "skill": "技", "power": "力"}

var _card_db: CardDatabase = CardDatabase.new()
var _pool_card_ids: Array = []       ## 大卡池中所有卡牌ID
var _selected_cards: Array = []      ## 已选卡牌（CardData数组）
var _pending_enemies: Array = []     ## 待战斗的敌人列表
var _test_mode: bool = false

## UI节点
var _pool_grid: GridContainer
var _pool_scroll: ScrollContainer
var _selected_grid: GridContainer
var _confirm_btn: Button
var _count_label: Label

func _ready() -> void:
	_build_ui()
	_load_card_pool()

## 接收数据（从GameManager.change_scene传入）
func receive_data(data: Dictionary) -> void:
	_pending_enemies = data.get("enemies", [])
	_test_mode = data.get("test_mode", false)

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
	title.text = "选择战斗卡组（%d张）" % TARGET_DECK_SIZE
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	title.horizontal_alignment = 1
	title.position = Vector2(0, 12)
	title.size = Vector2(vp_size.x, 40)
	add_child(title)
	
	# 卡池区域
	var pool_title = Label.new()
	pool_title.text = "卡池（点击加入卡组，可重复选）"
	pool_title.add_theme_font_size_override("font_size", 14)
	pool_title.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	pool_title.position = Vector2(20, 55)
	add_child(pool_title)
	
	_pool_scroll = ScrollContainer.new()
	_pool_scroll.position = Vector2(20, 80)
	_pool_scroll.size = Vector2(vp_size.x - 40, 340)
	add_child(_pool_scroll)
	
	_pool_grid = GridContainer.new()
	_pool_grid.columns = 7
	_pool_grid.add_theme_constant_override("h_separation", 8)
	_pool_grid.add_theme_constant_override("v_separation", 8)
	_pool_scroll.add_child(_pool_grid)
	
	# 已选卡组区域
	var selected_title = Label.new()
	selected_title.text = "战斗卡组（点击移除）"
	selected_title.add_theme_font_size_override("font_size", 14)
	selected_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	selected_title.position = Vector2(20, 435)
	add_child(selected_title)
	
	_selected_grid = GridContainer.new()
	_selected_grid.columns = 9
	_selected_grid.add_theme_constant_override("h_separation", 6)
	_selected_grid.add_theme_constant_override("v_separation", 6)
	_selected_grid.position = Vector2(20, 460)
	_selected_grid.size = Vector2(vp_size.x - 180, 100)
	add_child(_selected_grid)
	
	# 计数标签
	_count_label = Label.new()
	_count_label.text = "已选: 0/%d" % TARGET_DECK_SIZE
	_count_label.add_theme_font_size_override("font_size", 16)
	_count_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_count_label.position = Vector2(20, 570)
	add_child(_count_label)
	
	# 确认按钮
	_confirm_btn = Button.new()
	_confirm_btn.text = "确认出战"
	_confirm_btn.custom_minimum_size = Vector2(140, 50)
	_confirm_btn.add_theme_font_size_override("font_size", 18)
	_confirm_btn.position = Vector2(vp_size.x - 160, 560)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_on_confirm)
	add_child(_confirm_btn)
	UIStyle.attach_button_anim(_confirm_btn)
	
	# 返回按钮
	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(80, 36)
	back_btn.position = Vector2(vp_size.x - 100, 15)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)
	UIStyle.attach_button_anim(back_btn)

## 加载大卡池
func _load_card_pool() -> void:
	_pool_card_ids = CardPoolManager.get_all_card_ids()
	_pool_card_ids.sort_custom(_sort_by_rarity)
	for card_id in _pool_card_ids:
		var card = _card_db.get_card(card_id)
		if card == null:
			continue
		var node = _create_card_preview(card, false)
		_pool_grid.add_child(node)

func _sort_by_rarity(a: String, b: String) -> bool:
	var card_a = _card_db.get_card(a)
	var card_b = _card_db.get_card(b)
	if card_a == null or card_b == null:
		return false
	var order = {"basic": 0, "common": 1, "uncommon": 2, "rare": 3, "epic": 4}
	return order.get(card_a.rarity, 5) < order.get(card_b.rarity, 5)

## 创建卡牌预览节点（简洁卡片，可点击）
func _create_card_preview(card: CardData, is_selected: bool) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(130, 80)
	var style = StyleBoxFlat.new()
	var rarity_color = RARITY_COLOR.get(card.rarity, Color(0.5, 0.5, 0.5))
	style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = rarity_color
	style.set_corner_radius_all(5)
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	
	# 第一行：费用 + 名称
	var top_row = HBoxContainer.new()
	vbox.add_child(top_row)
	
	var cost_label = Label.new()
	cost_label.text = "%d" % card.cost
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	cost_label.custom_minimum_size = Vector2(20, 0)
	top_row.add_child(cost_label)
	
	var name_label = Label.new()
	name_label.text = card.name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top_row.add_child(name_label)
	
	# 第二行：类型 + 稀有度
	var bottom_row = HBoxContainer.new()
	vbox.add_child(bottom_row)
	
	var type_label = Label.new()
	type_label.text = TYPE_CN.get(card.type, "?")
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", rarity_color)
	type_label.custom_minimum_size = Vector2(20, 0)
	bottom_row.add_child(type_label)
	
	var rarity_label = Label.new()
	var rarity_cn = {"basic": "基础", "common": "普通", "uncommon": "罕见", "rare": "稀有", "epic": "唯一"}
	rarity_label.text = rarity_cn.get(card.rarity, card.rarity)
	rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(rarity_label)
	
	# 交互
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_selected:
		panel.gui_input.connect(_on_selected_card_input.bind(card))
	else:
		panel.gui_input.connect(_on_pool_card_input.bind(card))
	
	return panel

## 卡池卡牌点击：加入卡组
func _on_pool_card_input(event: InputEvent, card: CardData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected_cards.size() >= TARGET_DECK_SIZE:
			_count_label.text = "已满 %d/%d" % [TARGET_DECK_SIZE, TARGET_DECK_SIZE]
			return
		_selected_cards.append(card.duplicate())
		_refresh_selected()

## 已选卡牌点击：移除
func _on_selected_card_input(event: InputEvent, card: CardData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _selected_cards.size():
			if _selected_cards[i].name == card.name:
				_selected_cards.remove_at(i)
				break
		_refresh_selected()

## 刷新已选卡组显示
func _refresh_selected() -> void:
	for child in _selected_grid.get_children():
		child.queue_free()
	for card in _selected_cards:
		var node = _create_card_preview(card, true)
		_selected_grid.add_child(node)
	_count_label.text = "已选: %d/%d" % [_selected_cards.size(), TARGET_DECK_SIZE]
	_confirm_btn.disabled = _selected_cards.size() < TARGET_DECK_SIZE

## 确认：设置战斗卡组，进入战斗
func _on_confirm() -> void:
	if _selected_cards.size() < TARGET_DECK_SIZE:
		return
	GameData.player_deck = _selected_cards
	GameManager.start_battle(_pending_enemies, _test_mode)

## 返回
func _on_back() -> void:
	GameManager.go_to_map()