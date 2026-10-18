class_name CardInfoBox

const KEYWORD_TAGS := ["Exhaust", "Retain", "Innate", "Ethereal", "Unplayable", "PermanentExhaust", "Constant", "UniqueNoDup", "Derived"]

const TAG_CN := {
	"Exhaust": "消耗",
	"Retain": "保留",
	"Innate": "固有",
	"Ethereal": "虚无",
	"Unplayable": "不可打出",
	"PermanentExhaust": "永久消耗",
	"Constant": "恒常",
	"UniqueNoDup": "独一",
	"Derived": "衍生",
}

static var _tag_descs: Dictionary = {}
static var _buff_data: Dictionary = {}
static var _loaded: bool = false

static func _load_data() -> void:
	if _loaded:
		return
	var tf = load("res://data/tags.json")
	if tf:
		var td: Dictionary = tf.data if tf is JSON else tf
		_tag_descs = td.get("tag_properties", {})
	var bf = load("res://data/buffs.json")
	if bf:
		var bd: Dictionary = bf.data if bf is JSON else bf
		_buff_data = bd.get("buffs", {})
	_loaded = true

static func _get_tag_desc(tag: String) -> String:
	_load_data()
	var desc: String = _tag_descs.get(tag, {}).get("description", "")
	if tag == "Derived" and desc == "":
		desc = "衍生卡，非牌库原生卡牌"
	var cn = TAG_CN.get(tag, tag)
	if desc.begins_with(cn + "："):
		desc = desc.substr(cn.length() + 1)
	elif desc.begins_with(cn + ":"):
		desc = desc.substr(cn.length() + 1)
	return desc

static func _get_buff_info(buff_id: String) -> Dictionary:
	_load_data()
	return _buff_data.get(buff_id, {})

static func has_info(card: CardData) -> bool:
	for tag in card.tags:
		if KEYWORD_TAGS.has(tag):
			return true
	for effect in card.effects:
		var et = effect.get("effect_type", "")
		if et in ["apply_debuff", "apply_buff"] and effect.has("buff_id"):
			return true
	return false

static func fill_info_container(vbox: VBoxContainer, card: CardData, font_size: int = 12) -> bool:
	var has_content := false

	for tag in card.tags:
		if not KEYWORD_TAGS.has(tag):
			continue
		has_content = true
		var cn_name = TAG_CN.get(tag, tag)
		var desc = _get_tag_desc(tag)
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.text = "[b]%s[/b]：%s" % [cn_name, desc]
		rtl.add_theme_color_override("default_color", Color(0.75, 0.8, 0.85))
		rtl.add_theme_font_size_override("normal_font_size", font_size)
		rtl.custom_minimum_size = Vector2(180, 0)
		vbox.add_child(rtl)

	var seen_buffs: Dictionary = {}
	for effect in card.effects:
		var et = effect.get("effect_type", "")
		if et not in ["apply_debuff", "apply_buff"]:
			continue
		var bid = effect.get("buff_id", "")
		if bid == "" or seen_buffs.has(bid):
			continue
		seen_buffs[bid] = true
		var binfo = _get_buff_info(bid)
		if binfo.is_empty():
			continue
		has_content = true
		var bname: String = binfo.get("name", bid)
		var bdesc: String = binfo.get("description", "")
		bdesc = bdesc.replace("{stacks}", str(effect.get("value", 1)))
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.text = "[b]%s[/b]：%s" % [bname, bdesc]
		rtl.add_theme_color_override("default_color", Color(0.75, 0.8, 0.85))
		rtl.add_theme_font_size_override("normal_font_size", font_size)
		rtl.custom_minimum_size = Vector2(180, 0)
		vbox.add_child(rtl)

	return has_content

static func build_info_box(card: CardData, max_width: float = 200.0) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(max_width, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.5, 0.6, 0.7)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_top = 5
	style.content_margin_right = 6
	style.content_margin_bottom = 5
	box.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	box.add_child(vbox)

	var has_content := false

	for tag in card.tags:
		if not KEYWORD_TAGS.has(tag):
			continue
		has_content = true
		var cn_name = TAG_CN.get(tag, tag)
		var desc = _get_tag_desc(tag)
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.text = "[b]%s[/b]：%s" % [cn_name, desc]
		rtl.add_theme_color_override("default_color", Color(0.75, 0.8, 0.85))
		rtl.add_theme_font_size_override("normal_font_size", 11)
		vbox.add_child(rtl)

	var seen_buffs: Dictionary = {}
	for effect in card.effects:
		var et = effect.get("effect_type", "")
		if et not in ["apply_debuff", "apply_buff"]:
			continue
		var bid = effect.get("buff_id", "")
		if bid == "" or seen_buffs.has(bid):
			continue
		seen_buffs[bid] = true
		var binfo = _get_buff_info(bid)
		if binfo.is_empty():
			continue
		has_content = true
		var bname: String = binfo.get("name", bid)
		var bdesc: String = binfo.get("description", "")
		bdesc = bdesc.replace("{stacks}", str(effect.get("value", 1)))
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.text = "[b]%s[/b]：%s" % [bname, bdesc]
		rtl.add_theme_color_override("default_color", Color(0.75, 0.8, 0.85))
		rtl.add_theme_font_size_override("normal_font_size", 11)
		vbox.add_child(rtl)

	if not has_content:
		box.queue_free()
		return null
	return box