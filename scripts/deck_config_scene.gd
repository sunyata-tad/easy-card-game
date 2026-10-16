extends Control

var card_database: CardDatabase
var deck_manager: Node

var current_deck_name: String = ""
var current_deck_cards: Dictionary = {}

var deck_name_dropdown: OptionButton
var deck_grid: GridContainer
var library_grid: GridContainer
var search_input: LineEdit
var filter_type: OptionButton
var filter_rarity: OptionButton
var filter_tag: OptionButton
var deck_count_label: Label
var status_label: Label
var name_input: LineEdit
var filter_unlocked_only: CheckBox

var all_card_ids: Array = []
var _deck_scroll: ScrollContainer = null
var _lib_scroll: ScrollContainer = null
var _refresh_pending: bool = false
var _detail_panel: Panel = null
var _detail_big_card: Panel = null
var _detail_tags: Label = null

const TYPE_CN := {
	"attack": "攻击",
	"skill": "技能",
	"power": "能力",
}
const RARITY_CN := {
	"basic": "基础",
	"common": "普通",
	"uncommon": "稀有",
	"rare": "史诗",
	"epic": "唯一",
	"unique": "唯一",
}
const RARITY_ORDER := {
	"basic": 0,
	"common": 1,
	"uncommon": 2,
	"rare": 3,
	"epic": 4,
	"unique": 5,
}
const TAG_CN := {
	"Attack": "攻击",
	"Basic": "基础",
	"Skill": "技能",
	"Common": "普通",
	"Uncommon": "罕见",
	"Rare": "稀有",
	"Epic": "史诗",
	"Unique": "唯一",
	"Debuff": "减益",
	"Innate": "固有",
	"Retain": "保留",
	"Exhaust": "消耗",
	"PermanentExhaust": "永久消耗",
	"Constant": "恒常",
	"UniqueNoDup": "独一",
	"Derived": "衍生",
}

const RARITY_COLORS = {
	"basic": Color(0.6, 0.6, 0.6),
	"common": Color(0.8, 0.8, 0.8),
	"uncommon": Color(0.3, 0.7, 1.0),
	"rare": Color(1.0, 0.7, 0.2),
	"epic": Color(0.8, 0.3, 1.0),
	"unique": Color(1.0, 0.4, 0.4),
}

func _ready():
	card_database = CardDatabase.new()
	var dm_script = load("res://scripts/deck_manager.gd")
	deck_manager = dm_script.new()
	add_child(deck_manager)
	CardPoolManager.unlock_all_cards()
	all_card_ids = card_database.get_all_card_ids()
	all_card_ids.erase("_模板_卡牌名")
	all_card_ids.erase("模板示例")
	var filtered: Array = []
	for cid in all_card_ids:
		var c = card_database.get_card(cid)
		if c and not c.has_tag("Derived") and c.type in ["attack", "skill", "power"]:
			filtered.append(cid)
	all_card_ids = filtered
	_build_ui()
	_build_detail_panel()
	_refresh_deck_dropdown()
	_refresh_library()

func _build_ui():
	size = get_viewport_rect().size
	if UIStyle:
		UIStyle.add_background(self, "menu", 0.35)
	else:
		var bg = ColorRect.new()
		bg.color = Color(0.08, 0.09, 0.12, 1)
		bg.size = size
		add_child(bg)

	var top_bar = HBoxContainer.new()
	top_bar.position = Vector2(20, 10)
	top_bar.size = Vector2(size.x - 40, 40)
	top_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(top_bar)

	var back_btn = Button.new()
	back_btn.text = "← 返回"
	back_btn.custom_minimum_size = Vector2(100, 36)
	back_btn.pressed.connect(_on_back)
	if UIStyle:
		UIStyle.attach_button_anim(back_btn)
	top_bar.add_child(back_btn)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var save_btn = Button.new()
	save_btn.text = "保存卡组"
	save_btn.custom_minimum_size = Vector2(100, 36)
	save_btn.pressed.connect(_on_save)
	if UIStyle:
		UIStyle.attach_button_anim(save_btn)
	top_bar.add_child(save_btn)

	var delete_btn = Button.new()
	delete_btn.text = "删除卡组"
	delete_btn.custom_minimum_size = Vector2(100, 36)
	delete_btn.pressed.connect(_on_delete)
	if UIStyle:
		UIStyle.attach_button_anim(delete_btn)
	top_bar.add_child(delete_btn)

	var _left_margin = size.x * 0.1
	var main_area = HBoxContainer.new()
	main_area.position = Vector2(20 + _left_margin, 60)
	main_area.size = Vector2(size.x - 40 - _left_margin, size.y - 100)
	main_area.add_theme_constant_override("separation", 12)
	add_child(main_area)

	var left_panel = _build_left_panel()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.custom_minimum_size = Vector2(size.x * 0.28, size.y - 100)
	main_area.add_child(left_panel)

	var right_panel = _build_right_panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.custom_minimum_size = Vector2(size.x * 0.52, size.y - 100)
	main_area.add_child(right_panel)

	status_label = Label.new()
	status_label.position = Vector2(20, size.y - 30)
	status_label.size = Vector2(size.x - 40, 24)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(status_label)

func _build_left_panel():
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.15, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.2, 0.25, 1)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var name_row = HBoxContainer.new()
	vbox.add_child(name_row)

	var name_lbl = Label.new()
	name_lbl.text = "卡组名:"
	name_row.add_child(name_lbl)

	name_input = LineEdit.new()
	name_input.placeholder_text = "输入卡组名"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.text_changed.connect(_on_name_changed)
	name_row.add_child(name_input)

	deck_name_dropdown = OptionButton.new()
	deck_name_dropdown.custom_minimum_size = Vector2(150, 30)
	deck_name_dropdown.item_selected.connect(_on_deck_selected)
	name_row.add_child(deck_name_dropdown)

	deck_count_label = Label.new()
	deck_count_label.text = "卡组: 0/40-60"
	vbox.add_child(deck_count_label)

	var deck_scroll = ScrollContainer.new()
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_scroll.resized.connect(_on_scroll_resized)
	vbox.add_child(deck_scroll)

	_deck_scroll = deck_scroll
	deck_grid = GridContainer.new()
	deck_grid.columns = 3
	deck_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_grid.add_theme_constant_override("h_separation", 5)
	deck_grid.add_theme_constant_override("v_separation", 5)
	deck_scroll.add_child(deck_grid)

	return panel

func _build_right_panel():
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.15, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.2, 0.25, 1)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	vbox.add_child(filter_row)

	filter_type = OptionButton.new()
	filter_type.add_item("全部类型", 0)
	filter_type.item_selected.connect(_on_filter_changed)
	filter_row.add_child(filter_type)

	filter_rarity = OptionButton.new()
	filter_rarity.add_item("全部稀有度", 0)
	filter_rarity.item_selected.connect(_on_filter_changed)
	filter_row.add_child(filter_rarity)

	filter_tag = OptionButton.new()
	filter_tag.add_item("全部词条", 0)
	filter_tag.item_selected.connect(_on_filter_changed)
	filter_row.add_child(filter_tag)

	search_input = LineEdit.new()
	search_input.placeholder_text = "搜索卡名或效果..."
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.text_changed.connect(_on_search_changed)
	vbox.add_child(search_input)

	filter_unlocked_only = CheckBox.new()
	filter_unlocked_only.text = "只显示已解锁"
	filter_unlocked_only.toggled.connect(_on_filter_changed)
	vbox.add_child(filter_unlocked_only)

	var lib_scroll = ScrollContainer.new()
	lib_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lib_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lib_scroll.resized.connect(_on_scroll_resized)
	vbox.add_child(lib_scroll)

	_lib_scroll = lib_scroll
	library_grid = GridContainer.new()
	library_grid.columns = 6
	library_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_grid.add_theme_constant_override("h_separation", 5)
	library_grid.add_theme_constant_override("v_separation", 5)
	lib_scroll.add_child(library_grid)

	return panel

func _refresh_deck_dropdown():
	deck_name_dropdown.clear()
	deck_name_dropdown.add_item("（选择卡组）", 0)
	var names = deck_manager.get_all_deck_names()
	var idx = 1
	for n in names:
		deck_name_dropdown.add_item(n, idx)
		idx += 1

func _on_deck_selected(index: int):
	if index == 0:
		return
	var deck_name = deck_name_dropdown.get_item_text(index)
	var data = deck_manager.load_deck(deck_name)
	if data.is_empty():
		return
	current_deck_name = deck_name
	current_deck_cards.clear()
	for entry in data.get("cards", []):
		current_deck_cards[entry.get("card_id", "")] = entry.get("count", 0)
	name_input.text = deck_name
	_refresh_deck_display()

func _on_name_changed(new_text: String):
	current_deck_name = new_text

func _on_filter_changed(_arg: Variant = null):
	_refresh_library()

func _on_search_changed(_text: String):
	_refresh_library()

func _on_scroll_resized():
	if _refresh_pending:
		return
	_refresh_pending = true
	call_deferred("_do_deferred_refresh")

func _do_deferred_refresh():
	_refresh_pending = false
	_refresh_library()
	_refresh_deck_display()

func _sort_card_ids(ids: Array) -> Array:
	ids.sort_custom(func(a, b):
		var ca = card_database.get_card(a)
		var cb = card_database.get_card(b)
		if ca == null or cb == null:
			return false
		var ra = RARITY_ORDER.get(ca.rarity, 99)
		var rb = RARITY_ORDER.get(cb.rarity, 99)
		if ra != rb:
			return ra < rb
		var ta = TYPE_CN.get(ca.type, ca.type)
		var tb = TYPE_CN.get(cb.type, cb.type)
		if ta != tb:
			return ta < tb
		return ca.name < cb.name
	)
	return ids

func _calc_columns(scroll: ScrollContainer, card_w: float, sep: float) -> int:
	var avail: float = scroll.size.x
	if avail <= 0:
		avail = scroll.custom_minimum_size.x
	if avail <= 0:
		return 1
	var col = int(floor((avail + sep) / (card_w + sep)))
	return max(1, col)

func _get_filtered_card_ids() -> Array:
	var result: Array = []
	var type_filter = filter_type.get_selected_id()
	var rarity_filter = filter_rarity.get_selected_id()
	var tag_filter = filter_tag.get_selected_id()
	var search_text = search_input.text.to_lower()
	var unlocked_only = filter_unlocked_only.button_pressed

	for card_id in all_card_ids:
		var card = card_database.get_card(card_id)
		if card == null:
			continue
		if unlocked_only and not CardPoolManager.has_card(card_id):
			continue
		if type_filter > 0:
			var type_cn = filter_type.get_item_text(type_filter)
			if TYPE_CN.get(card.type, card.type) != type_cn:
				continue
		if rarity_filter > 0:
			var rarity_cn = filter_rarity.get_item_text(rarity_filter)
			if RARITY_CN.get(card.rarity, card.rarity) != rarity_cn:
				continue
		if tag_filter > 0:
			var tag_cn = filter_tag.get_item_text(tag_filter)
			var matched = false
			for t in card.tags:
				if TAG_CN.get(t, t) == tag_cn:
					matched = true
					break
			if not matched:
				continue
		if search_text != "":
			var name_match = card.name.to_lower().find(search_text) >= 0
			var desc_match = card.description.to_lower().find(search_text) >= 0
			if not name_match and not desc_match:
				continue
		result.append(card_id)
	return result

func _refresh_library():
	_populate_filter_options()
	for child in library_grid.get_children():
		child.queue_free()
	if _lib_scroll:
		library_grid.columns = _calc_columns(_lib_scroll, 80, 5)
	var ids = _get_filtered_card_ids()
	_sort_card_ids(ids)
	for card_id in ids:
		var card = card_database.get_card(card_id)
		if card == null:
			continue
		var is_locked = not CardPoolManager.has_card(card_id)
		var widget = _create_small_card_widget(card, current_deck_cards.get(card_id, 0), true, is_locked)
		library_grid.add_child(widget)

func _populate_filter_options():
	var types: Array = []
	var rarities: Array = []
	var tags: Array = []
	for card_id in all_card_ids:
		var card = card_database.get_card(card_id)
		if card == null:
			continue
		var type_cn = TYPE_CN.get(card.type, card.type)
		if not types.has(type_cn):
			types.append(type_cn)
		var rarity_cn = RARITY_CN.get(card.rarity, card.rarity)
		if not rarities.has(rarity_cn):
			rarities.append(rarity_cn)
		for t in card.tags:
			var tag_cn = TAG_CN.get(t, t)
			if not tags.has(tag_cn):
				tags.append(tag_cn)
	types.sort()
	rarities.sort_custom(func(a, b): return RARITY_ORDER.get(a, 99) < RARITY_ORDER.get(b, 99))
	tags.sort()
	_rebuild_option_button(filter_type, "全部类型", types)
	_rebuild_option_button(filter_rarity, "全部稀有度", rarities)
	_rebuild_option_button(filter_tag, "全部词条", tags)

func _rebuild_option_button(btn: OptionButton, all_text: String, options: Array):
	var selected_idx = btn.get_selected_id()
	var selected_text = btn.get_item_text(selected_idx) if selected_idx > 0 else ""
	btn.clear()
	btn.add_item(all_text, 0)
	var idx = 1
	for opt in options:
		btn.add_item(opt, idx)
		if opt == selected_text:
			btn.select(idx)
		idx += 1
	if selected_idx == 0 or selected_text == "":
		btn.select(0)

func _refresh_deck_display():
	for child in deck_grid.get_children():
		child.queue_free()
	if _deck_scroll:
		deck_grid.columns = _calc_columns(_deck_scroll, 80, 5)
	var total = 0
	var card_ids = current_deck_cards.keys()
	_sort_card_ids(card_ids)
	for card_id in card_ids:
		var count = current_deck_cards[card_id]
		if count <= 0:
			continue
		var card = card_database.get_card(card_id)
		if card == null:
			continue
		total += count
		var widget = _create_small_card_widget(card, count, false, false)
		deck_grid.add_child(widget)
	deck_count_label.text = "卡组: %d/40-60" % total
	var color = Color(0.7, 0.7, 0.7)
	if total < deck_manager.MIN_DECK_SIZE or total > deck_manager.MAX_DECK_SIZE:
		color = Color(1.0, 0.4, 0.4)
	else:
		color = Color(0.4, 1.0, 0.4)
	deck_count_label.add_theme_color_override("font_color", color)

func _create_card_visual(card: CardData, w: float, h: float, count: int = 0, is_locked: bool = false, show_detail: bool = false) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(w, h)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 1) if is_locked else Color(0.13, 0.14, 0.18, 1)
	var rarity_color = RARITY_COLORS.get(card.rarity, Color(0.6, 0.6, 0.6))
	if is_locked:
		rarity_color = Color(0.3, 0.3, 0.3)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = rarity_color
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var pad := 2.0
	var art_h := h * 0.5
	var band_h := h * 0.05
	var text_top := art_h
	var text_bottom := h - band_h - pad

	if card.art != "" and not is_locked:
		var tex_rect = TextureRect.new()
		tex_rect.offset_left = pad
		tex_rect.offset_top = pad
		tex_rect.offset_right = w - pad
		tex_rect.offset_bottom = art_h
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var tex = load(card.art)
		if tex:
			tex_rect.texture = tex
		panel.add_child(tex_rect)

	var text_bg = ColorRect.new()
	text_bg.offset_left = pad
	text_bg.offset_top = text_top
	text_bg.offset_right = w - pad
	text_bg.offset_bottom = text_bottom
	text_bg.color = Color(0.06, 0.07, 0.1, 0.9)
	panel.add_child(text_bg)

	var name_size := 10
	var type_size := 10
	var desc_size := 8
	var rarity_size := 10
	if show_detail:
		name_size = 16
		type_size = 13
		desc_size = 13
		rarity_size = 12

	var name_h := h * 0.12 if not show_detail else h * 0.1
	var name_lbl = Label.new()
	name_lbl.offset_left = pad + 3
	name_lbl.offset_top = text_top + 2
	name_lbl.offset_right = w - pad - 3
	name_lbl.offset_bottom = text_top + 2 + name_h
	name_lbl.text = card.name
	name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5) if is_locked else Color.WHITE)
	name_lbl.add_theme_font_size_override("font_size", name_size)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(name_lbl)

	var desc_top := text_top + 2 + name_h + 2
	if show_detail:
		var type_lbl = Label.new()
		type_lbl.offset_left = pad + 3
		type_lbl.offset_top = desc_top
		type_lbl.offset_right = w - pad - 3
		type_lbl.offset_bottom = desc_top + h * 0.08
		type_lbl.text = TYPE_CN.get(card.type, card.type)
		type_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		type_lbl.add_theme_font_size_override("font_size", type_size)
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(type_lbl)
		desc_top += h * 0.08

	var desc_lbl = Label.new()
	desc_lbl.offset_left = pad + 3
	desc_lbl.offset_top = desc_top
	desc_lbl.offset_right = w - pad - 3
	desc_lbl.offset_bottom = text_bottom
	desc_lbl.text = card.description
	desc_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45) if is_locked else Color(0.7, 0.7, 0.75))
	desc_lbl.add_theme_font_size_override("font_size", desc_size)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(desc_lbl)

	var band = ColorRect.new()
	band.offset_left = pad
	band.offset_top = text_bottom
	band.offset_right = w - pad
	band.offset_bottom = h - pad
	band.color = rarity_color
	panel.add_child(band)

	if show_detail:
		var rarity_lbl = Label.new()
		rarity_lbl.offset_left = pad + 3
		rarity_lbl.offset_top = text_bottom
		rarity_lbl.offset_right = w - pad - 3
		rarity_lbl.offset_bottom = h - pad
		rarity_lbl.text = RARITY_CN.get(card.rarity, card.rarity)
		rarity_lbl.add_theme_color_override("font_color", Color.BLACK)
		rarity_lbl.add_theme_font_size_override("font_size", rarity_size)
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(rarity_lbl)

	if is_locked:
		var lock_lbl = Label.new()
		lock_lbl.offset_left = pad
		lock_lbl.offset_top = pad
		lock_lbl.offset_right = w - pad
		lock_lbl.offset_bottom = art_h
		lock_lbl.text = "🔒"
		lock_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		lock_lbl.add_theme_font_size_override("font_size", int(h * 0.19))
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(lock_lbl)
	elif count > 1:
		var count_lbl = Label.new()
		count_lbl.offset_left = w * 0.75
		count_lbl.offset_top = pad
		count_lbl.offset_right = w - pad
		count_lbl.offset_bottom = pad + h * 0.13
		count_lbl.text = "x%d" % count
		count_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		count_lbl.add_theme_font_size_override("font_size", 10)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		panel.add_child(count_lbl)

	return panel

func _create_small_card_widget(card: CardData, count: int, is_library: bool = false, is_locked: bool = false) -> Control:
	var panel = _create_card_visual(card, 80, 105, count, is_locked, false)
	panel.gui_input.connect(_on_card_widget_input.bind(card.id, is_library, is_locked))
	if not is_locked:
		panel.mouse_entered.connect(_on_card_hover_entered.bind(panel))
		panel.mouse_exited.connect(_on_card_hover_exited.bind(panel))
	return panel

func _on_card_hover_entered(panel: Panel):
	panel.offset_transform_enabled = true
	panel.z_index = 10
	if panel.has_meta("hover_tween"):
		var old: Variant = panel.get_meta("hover_tween")
		if old is Tween and old.is_valid():
			old.kill()
	var tw: Tween = panel.create_tween()
	tw.tween_property(panel, "offset_transform_scale", Vector2(1.08, 1.08), 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	panel.set_meta("hover_tween", tw)

func _on_card_hover_exited(panel: Panel):
	panel.z_index = 0
	if panel.has_meta("hover_tween"):
		var old: Variant = panel.get_meta("hover_tween")
		if old is Tween and old.is_valid():
			old.kill()
	var tw: Tween = panel.create_tween()
	tw.tween_property(panel, "offset_transform_scale", Vector2.ONE, 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	panel.set_meta("hover_tween", tw)

func _on_card_widget_input(event: InputEvent, card_id: String, is_library: bool, is_locked: bool = false):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_show_card_detail(card_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _detail_panel and _detail_panel.visible:
				_detail_panel.visible = false
			if is_locked:
				return
			if is_library:
				_add_card_to_deck(card_id)
			else:
				_remove_card_from_deck(card_id)

func _add_card_to_deck(card_id: String):
	var current_count = current_deck_cards.get(card_id, 0)
	var card = card_database.get_card(card_id)
	if card and card.rarity == "unique" and current_count >= 1:
		_show_status("唯一卡牌「%s」只能放入1张" % card.name)
		return
	if current_count >= deck_manager.MAX_CARD_COPIES:
		_show_status("每张卡至多放入%d张" % deck_manager.MAX_CARD_COPIES)
		return
	current_deck_cards[card_id] = current_count + 1
	_refresh_deck_display()
	_refresh_library()
	_show_status("")

func _remove_card_from_deck(card_id: String):
	var current_count = current_deck_cards.get(card_id, 0)
	if current_count <= 0:
		return
	current_count -= 1
	if current_count == 0:
		current_deck_cards.erase(card_id)
	else:
		current_deck_cards[card_id] = current_count
	_refresh_deck_display()
	_refresh_library()
	_show_status("")

func _on_save():
	if current_deck_name == "":
		_show_status("请输入卡组名")
		return
	var cards: Array = []
	for card_id in current_deck_cards:
		var count = current_deck_cards[card_id]
		if count > 0:
			cards.append({"card_id": card_id, "count": count})
	var validation = deck_manager.validate_deck(cards)
	if not validation.valid:
		_show_status(validation.error)
		return
	if deck_manager.save_deck(current_deck_name, cards):
		_show_status("卡组「%s」已保存" % current_deck_name)
		_refresh_deck_dropdown()
	else:
		_show_status("保存失败")

func _on_delete():
	if current_deck_name == "":
		_show_status("请先选择卡组")
		return
	if deck_manager.delete_deck(current_deck_name):
		_show_status("卡组「%s」已删除" % current_deck_name)
		current_deck_name = ""
		current_deck_cards.clear()
		name_input.text = ""
		_refresh_deck_dropdown()
		_refresh_deck_display()
		_refresh_library()
	else:
		_show_status("删除失败")

func _on_back():
	TransitionManager.transition(GameManager.go_to_main_menu)

func _build_detail_panel():
	_detail_panel = Panel.new()
	_detail_panel.position = Vector2(20, 60)
	_detail_panel.size = Vector2(size.x * 0.2, size.y - 100)
	_detail_panel.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.15, 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.5, 0.6, 0.9)
	style.set_corner_radius_all(6)
	_detail_panel.add_theme_stylebox_override("panel", style)

	_detail_tags = Label.new()
	_detail_tags.offset_left = 10
	_detail_tags.offset_right = -10
	_detail_tags.anchor_right = 1.0
	_detail_tags.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	_detail_tags.add_theme_font_size_override("font_size", 11)
	_detail_tags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_panel.add_child(_detail_tags)

	add_child(_detail_panel)

func _show_card_detail(card_id: String):
	var card = card_database.get_card(card_id)
	if card == null:
		return
	if _detail_big_card and is_instance_valid(_detail_big_card):
		_detail_big_card.queue_free()
	var card_w = _detail_panel.size.x - 20
	var card_h = card_w * 1.3125
	_detail_big_card = _create_card_visual(card, card_w, card_h, 0, false, true)
	_detail_big_card.position = Vector2(10, 10)
	_detail_panel.add_child(_detail_big_card)
	_detail_tags.offset_top = 10 + card_h + 8
	_detail_tags.offset_bottom = _detail_panel.size.y - 10
	var tag_texts: Array = []
	for t in card.tags:
		tag_texts.append(TAG_CN.get(t, t))
	_detail_tags.text = "词条: " + ", ".join(tag_texts)
	_detail_panel.visible = true

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if _detail_panel and _detail_panel.visible:
			var panel_rect = Rect2(_detail_panel.global_position, _detail_panel.size)
			if not panel_rect.has_point(event.global_position):
				_detail_panel.visible = false

func _show_status(text: String):
	status_label.text = text
