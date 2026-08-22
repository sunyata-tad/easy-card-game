## UIStyle —— 全局 UI 样式助手（Autoload）
## 提供统一的配色、星云背景、面板/按钮/标题等样式助手，供纯代码构建的界面复用。
## 主题本身由 res://ui/theme.tres 提供（project.godot 的 gui/theme/custom 全局应用）。
extends Node

# ============================ 配色 ============================
const COLOR_BG_DARK := Color(0.055, 0.065, 0.12)
const COLOR_PANEL := Color(0.06, 0.07, 0.13, 0.94)
const COLOR_PANEL_BORDER := Color(0.32, 0.32, 0.52, 0.7)
const COLOR_GOLD := Color(0.85, 0.66, 0.28)
const COLOR_GOLD_BRIGHT := Color(1.0, 0.85, 0.5)
const COLOR_GOLD_DIM := Color(0.6, 0.45, 0.16)
const COLOR_TEXT := Color(0.9, 0.88, 0.85)
const COLOR_TEXT_MUTED := Color(0.62, 0.62, 0.72)
const COLOR_DANGER := Color(0.9, 0.32, 0.32)
const COLOR_HEALTH := Color(0.85, 0.25, 0.28)
const COLOR_BLOCK := Color(0.35, 0.75, 0.95)
const COLOR_SUCCESS := Color(0.4, 0.85, 0.5)
const COLOR_POWER := Color(0.65, 0.45, 0.9)

# ====================== 星云背景资源 ======================
const NEBULA_BLUE: Array[String] = [
	"res://assets/Large 1024x1024/Blue Nebula/Blue_Nebula_01-1024x1024.png",
	"res://assets/Large 1024x1024/Blue Nebula/Blue_Nebula_02-1024x1024.png",
	"res://assets/Large 1024x1024/Blue Nebula/Blue_Nebula_03-1024x1024.png",
	"res://assets/Large 1024x1024/Blue Nebula/Blue_Nebula_04-1024x1024.png",
	"res://assets/Large 1024x1024/Blue Nebula/Blue_Nebula_05-1024x1024.png",
	"res://assets/Large 1024x1024/Blue Nebula/Blue_Nebula_06-1024x1024.png",
	"res://assets/Large 1024x1024/Blue Nebula/Blue_Nebula_07-1024x1024.png",
	"res://assets/Large 1024x1024/Blue Nebula/Blue_Nebula_08-1024x1024.png",
]

const NEBULA_GREEN: Array[String] = [
	"res://assets/Large 1024x1024/Green Nebula/Green_Nebula_01-1024x1024.png",
	"res://assets/Large 1024x1024/Green Nebula/Green_Nebula_02-1024x1024.png",
	"res://assets/Large 1024x1024/Green Nebula/Green_Nebula_03-1024x1024.png",
	"res://assets/Large 1024x1024/Green Nebula/Green_Nebula_04-1024x1024.png",
	"res://assets/Large 1024x1024/Green Nebula/Green_Nebula_05-1024x1024.png",
	"res://assets/Large 1024x1024/Green Nebula/Green_Nebula_06-1024x1024.png",
	"res://assets/Large 1024x1024/Green Nebula/Green_Nebula_07-1024x1024.png",
	"res://assets/Large 1024x1024/Green Nebula/Green_Nebula_08-1024x1024.png",
]

const NEBULA_PURPLE: Array[String] = [
	"res://assets/Large 1024x1024/Purple Nebula/Purple_Nebula_01-1024x1024.png",
	"res://assets/Large 1024x1024/Purple Nebula/Purple_Nebula_02-1024x1024.png",
	"res://assets/Large 1024x1024/Purple Nebula/Purple_Nebula_03-1024x1024.png",
	"res://assets/Large 1024x1024/Purple Nebula/Purple_Nebula_04-1024x1024.png",
	"res://assets/Large 1024x1024/Purple Nebula/Purple_Nebula_05-1024x1024.png",
	"res://assets/Large 1024x1024/Purple Nebula/Purple_Nebula_06-1024x1024.png",
	"res://assets/Large 1024x1024/Purple Nebula/Purple_Nebula_07-1024x1024.png",
	"res://assets/Large 1024x1024/Purple Nebula/Purple_Nebula_08-1024x1024.png",
]

const STARFIELDS: Array[String] = [
	"res://assets/Large 1024x1024/Starfields/Starfield_01-1024x1024.png",
	"res://assets/Large 1024x1024/Starfields/Starfield_02-1024x1024.png",
	"res://assets/Large 1024x1024/Starfields/Starfield_03-1024x1024.png",
	"res://assets/Large 1024x1024/Starfields/Starfield_04-1024x1024.png",
	"res://assets/Large 1024x1024/Starfields/Starfield_05-1024x1024.png",
	"res://assets/Large 1024x1024/Starfields/Starfield_06-1024x1024.png",
	"res://assets/Large 1024x1024/Starfields/Starfield_07-1024x1024.png",
	"res://assets/Large 1024x1024/Starfields/Starfield_08-1024x1024.png",
]

## 每个屏幕固定使用的背景（保证不同界面有不同的星云观感）
const SCREEN_BG: Dictionary = {
	"menu": "res://assets/Large 1024x1024/Blue Nebula/Blue_Nebula_01-1024x1024.png",
	"battle": "res://assets/Large 1024x1024/Blue Nebula/Blue_Nebula_07-1024x1024.png",
	"map": "res://assets/Large 1024x1024/Purple Nebula/Purple_Nebula_06-1024x1024.png",
	"character_select": "res://assets/Large 1024x1024/Green Nebula/Green_Nebula_03-1024x1024.png",
	"character_creation": "res://assets/Large 1024x1024/Purple Nebula/Purple_Nebula_05-1024x1024.png",
	"reward": "res://assets/Large 1024x1024/Green Nebula/Green_Nebula_02-1024x1024.png",
	"relic_reward": "res://assets/Large 1024x1024/Purple Nebula/Purple_Nebula_03-1024x1024.png",
	"game_over": "res://assets/Large 1024x1024/Starfields/Starfield_08-1024x1024.png",
}

var _texture_cache: Dictionary = {}

# ====================== 背景 ======================

func background_for(screen: String) -> Texture2D:
	var path: String = SCREEN_BG.get(screen, SCREEN_BG["menu"])
	return _load_texture(path)


func random_background(kind: String) -> Texture2D:
	var paths := _paths_for_kind(kind)
	if paths.is_empty():
		return _load_texture(SCREEN_BG["menu"])
	return _load_texture(paths[randi() % paths.size()])


func _paths_for_kind(kind: String) -> Array:
	match kind:
		"blue": return NEBULA_BLUE
		"green": return NEBULA_GREEN
		"purple": return NEBULA_PURPLE
		"starfield", "star": return STARFIELDS
		"any":
			var all: Array = []
			all.append_array(NEBULA_BLUE)
			all.append_array(NEBULA_GREEN)
			all.append_array(NEBULA_PURPLE)
			all.append_array(STARFIELDS)
			return all
	return []


func _load_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		push_warning("UIStyle: 无法加载背景纹理 " + path)
		return null
	_texture_cache[path] = tex
	return tex


## 给一个 Control 添加星云背景 + 暗色蒙版（插入到最底层，保证上层内容可读）。
## 返回背景 TextureRect（上层蒙版为 overlay）。
func add_background(parent: Control, screen: String, dim: float = 0.2) -> TextureRect:
	var tex := background_for(screen)
	var bg := TextureRect.new()
	bg.name = "NebulaBackground"
	if tex:
		bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	parent.move_child(bg, 0)

	var overlay := ColorRect.new()
	overlay.name = "NebulaOverlay"
	overlay.color = Color(0.02, 0.025, 0.05, dim)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(overlay)
	parent.move_child(overlay, 1)

	return bg

# ====================== 面板 / 按钮 / 标题 ======================

func panel_style(bg: Color = COLOR_PANEL, border: Color = COLOR_PANEL_BORDER, radius: int = 12, border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.border_width_left = border_w
	s.border_width_top = border_w
	s.border_width_right = border_w
	s.border_width_bottom = border_w
	s.set_content_margin_all(12)
	return s


func gold_panel_style() -> StyleBoxFlat:
	return panel_style(COLOR_PANEL, Color(0.85, 0.66, 0.28, 0.7), 12, 2)


func make_title(text: String, size: int = 40, color: Color = COLOR_GOLD_BRIGHT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func make_subtitle(text: String, size: int = 16, color: Color = COLOR_TEXT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


## 主行动按钮（金色实心 CTA）：返回 normal / hover / pressed 三态样式
func primary_styles() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.85, 0.66, 0.28, 0.95)
	normal.border_color = Color(1.0, 0.85, 0.5, 1.0)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	normal.shadow_color = Color(0, 0, 0, 0.4)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.8, 0.4, 1.0)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.6, 0.45, 0.16, 1.0)

	return {"normal": normal, "hover": hover, "pressed": pressed}


func style_primary_button(btn: Button) -> Button:
	var st := primary_styles()
	btn.add_theme_stylebox_override("normal", st["normal"])
	btn.add_theme_stylebox_override("hover", st["hover"])
	btn.add_theme_stylebox_override("pressed", st["pressed"])
	btn.add_theme_stylebox_override("focus", st["normal"])
	btn.add_theme_color_override("font_color", Color(0.1, 0.08, 0.04, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.1, 0.08, 0.04, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.85, 1))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.3))
	btn.add_theme_constant_override("outline_size", 1)
	btn.add_theme_font_size_override("font_size", 18)
	return btn


## 移除按钮的盒式背景与内边距（用于扁平小徽章，如 buff 图标），
## 避免被全局按钮样式撑大、破坏小尺寸布局。
func strip_button_box(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# ====================== 4.7 Offset Transform 动画 ======================
## 给按钮注入悬停放大/点击挤压动画（基于 4.7 Control.offset_transform_*）。
## 纯视觉（offset_transform_visual_only 默认 true），Container 内缩放不挤动兄弟节点。
## 可重复调用，已注入则跳过。
func attach_button_anim(btn: Button, hover_scale: Vector2 = Vector2(1.08, 1.08),
		press_scale: Vector2 = Vector2(0.94, 0.94),
		hover_time: float = 0.12, press_time: float = 0.08) -> Button:
	if btn.get_meta("anim_attached", false):
		return btn
	btn.set_meta("anim_attached", true)
	btn.offset_transform_enabled = true
	btn.set_meta("anim_hover_scale", hover_scale)
	btn.set_meta("anim_press_scale", press_scale)
	btn.set_meta("anim_hover_time", hover_time)
	btn.set_meta("anim_press_time", press_time)
	btn.set_meta("anim_hovered", false)
	btn.mouse_entered.connect(_on_anim_mouse_entered.bind(btn))
	btn.mouse_exited.connect(_on_anim_mouse_exited.bind(btn))
	btn.button_down.connect(_on_anim_button_down.bind(btn))
	btn.button_up.connect(_on_anim_button_up.bind(btn))
	return btn


func _on_anim_mouse_entered(btn: Button) -> void:
	btn.set_meta("anim_hovered", true)
	_anim_tween_scale(btn, btn.get_meta("anim_hover_scale", Vector2(1.08, 1.08)),
		btn.get_meta("anim_hover_time", 0.12))


func _on_anim_mouse_exited(btn: Button) -> void:
	btn.set_meta("anim_hovered", false)
	_anim_tween_scale(btn, Vector2.ONE, btn.get_meta("anim_hover_time", 0.12))


func _on_anim_button_down(btn: Button) -> void:
	_anim_tween_scale(btn, btn.get_meta("anim_press_scale", Vector2(0.94, 0.94)),
		btn.get_meta("anim_press_time", 0.08))


func _on_anim_button_up(btn: Button) -> void:
	var target: Vector2 = btn.get_meta("anim_hover_scale", Vector2(1.08, 1.08)) if btn.get_meta("anim_hovered", false) else Vector2.ONE
	_anim_tween_scale(btn, target, btn.get_meta("anim_press_time", 0.08))


func _anim_tween_scale(btn: Button, target: Vector2, duration: float) -> void:
	if btn.has_meta("anim_tween"):
		var old: Variant = btn.get_meta("anim_tween")
		if old is Tween and old.is_valid():
			old.kill()
	var tw: Tween = btn.create_tween()
	tw.tween_property(btn, "offset_transform_scale", target, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	btn.set_meta("anim_tween", tw)


## 滑入：从 from_offset 偏移位置 + 淡入（offset_transform_position → 0, modulate:a → 1）。返回 Tween。
func slide_in(control: Control, from_offset: Vector2 = Vector2(0, 80),
		duration: float = 0.3, delay: float = 0.0) -> Tween:
	control.offset_transform_enabled = true
	control.offset_transform_position = from_offset
	control.modulate.a = 0.0
	control.visible = true
	var tw: Tween = control.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(control, "offset_transform_position", Vector2.ZERO, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(control, "modulate:a", 1.0, duration)
	return tw


## 错峰滑入：多个控件依次出现，第 i 个延迟 i*stagger。返回 Tween 数组。
func stagger_in(controls: Array, from_offset: Vector2 = Vector2(0, 80),
		duration: float = 0.3, stagger: float = 0.06) -> Array:
	var tweens: Array = []
	for i in controls.size():
		tweens.append(slide_in(controls[i], from_offset, duration, float(i) * stagger))
	return tweens


## 滑出：到 to_offset + 淡出，结束后 visible=false。返回 Tween。
func slide_out(control: Control, to_offset: Vector2 = Vector2(0, 80),
		duration: float = 0.3) -> Tween:
	control.offset_transform_enabled = true
	control.visible = true
	var tw: Tween = control.create_tween()
	tw.tween_property(control, "offset_transform_position", to_offset, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(control, "modulate:a", 0.0, duration)
	tw.tween_callback(func(): control.visible = false)
	return tw
