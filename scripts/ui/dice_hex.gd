## 六边形骰子节点：绘制正六边形格子+速度数字，支持空/装填/激活三种状态配色
class_name DiceHex
extends Control

var dice_value: String = "?" : set = set_value
var bg_color: Color = Color(0.16, 0.17, 0.21)      ## 背景色
var border_color: Color = Color(0.4, 0.42, 0.48)   ## 边框色
var text_color: Color = Color(0.5, 0.5, 0.55)      ## 文字色
var _value_font_size: int = 30

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func set_value(v: String) -> void:
	dice_value = v
	queue_redraw()

## 设置三种状态配色 (is_filled=已装填, is_active=激活待装填)
func set_state_colors(is_filled: bool, is_active: bool) -> void:
	if is_active:
		# 激活：金色高亮
		bg_color = Color(0.24, 0.19, 0.06)
		border_color = Color(1.0, 0.85, 0.3)
		text_color = Color(1.0, 0.85, 0.3)
	elif is_filled:
		# 已装填：正常色（蓝底黄字）
		bg_color = Color(0.13, 0.16, 0.24)
		border_color = Color(0.45, 0.6, 0.9)
		text_color = Color(1.0, 0.92, 0.5)
	else:
		# 空：灰色
		bg_color = Color(0.16, 0.17, 0.21)
		border_color = Color(0.4, 0.42, 0.48)
		text_color = Color(0.5, 0.5, 0.55)
	queue_redraw()

## 缩放反馈（悬浮/点击）
func set_hover_scale(scale_factor: float) -> void:
	pivot_offset = size / 2
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * scale_factor, 0.12).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var pts := _hex_points(size)
	if pts.size() < 6:
		return
	# 填充
	draw_colored_polygon(pts, bg_color)
	# 边框
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], border_color, 3.0)
	# 文字
	var font := ThemeDB.fallback_font
	if font:
		var fs := _value_font_size
		var text_size := font.get_string_size(dice_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2((size.x - text_size.x) / 2.0, (size.y + text_size.y * 0.72) / 2.0)
		draw_string(font, pos, dice_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

## 生成尖顶朝上的正六边形顶点
func _hex_points(s: Vector2) -> PackedVector2Array:
	var cx := s.x / 2.0
	var cy := s.y / 2.0
	var r := minf(s.x, s.y) / 2.0 - 2.0
	var pts := PackedVector2Array()
	for i in 6:
		var angle := -PI / 2.0 + i * PI / 3.0  # 从正上方开始
		pts.append(Vector2(cx + r * cos(angle), cy + r * sin(angle)))
	return pts