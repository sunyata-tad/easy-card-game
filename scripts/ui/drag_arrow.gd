## 拖拽箭头：在卡牌拖拽时从卡牌位置指向目标的箭头线。
## Godot 特色：
## - extends Control 继承 UI 控件基类
## - _draw() 是 Godot 的自定义绘制回调，在其中调用 draw_line 和 draw_polygon 画图
## - queue_redraw() 请求引擎在下一帧重绘（类似 HTML Canvas 的 requestRedraw）
## - PackedVector2Array 是紧凑型 Vector2 数组（类似 Python 的 list of tuples 但更高效）
class_name DragArrow
extends Control

var start_pos: Vector2 = Vector2.ZERO     ## 箭头起始位置
var end_pos: Vector2 = Vector2.ZERO       ## 箭头终点位置
var is_visible: bool = false             ## 是否显示

## 美术参数
var glow_color: Color = Color(1.0, 0.85, 0.3, 0.25)   ## 发光颜色（外层光晕）
var line_color: Color = Color(1.0, 0.9, 0.4, 0.9)     ## 主线颜色
var head_color: Color = Color(1.0, 0.95, 0.5, 1.0)    ## 箭头颜色
var glow_width: float = 10.0          ## 发光线宽
var line_width: float = 3.5           ## 主线线宽
var head_size: float = 18.0           ## 箭头尺寸
var start_radius: float = 6.0         ## 起点圆圈半径

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

## 自定义绘制：发光线 + 主线 + 大箭头 + 起点圆圈
func _draw():
	if not is_visible:
		return

	var diff := end_pos - start_pos
	var distance := diff.length()
	if distance < 10:
		return

	var direction := diff / distance

	# 1. 发光层（粗线 + 半透明）
	draw_line(start_pos, end_pos, glow_color, glow_width, true)

	# 2. 主线
	draw_line(start_pos, end_pos, line_color, line_width, true)

	# 3. 起点圆圈（双层发光）
	draw_circle(start_pos, start_radius + 3, Color(glow_color.r, glow_color.g, glow_color.b, 0.2))
	draw_circle(start_pos, start_radius, line_color)
	draw_circle(start_pos, start_radius - 2, Color(0.05, 0.05, 0.08, 0.9))

	# 4. 箭头：凹底三角（4顶点，更有锐利感）
	var head_base := end_pos - direction * head_size
	var perp := Vector2(-direction.y, direction.x)
	var head_w := head_size * 0.6
	var head_indent := head_size * 0.25  # 凹入深度

	var p_tip := end_pos
	var p_left := head_base + perp * head_w
	var p_right := head_base - perp * head_w
	var p_indent := head_base - direction * head_indent

	# 箭头发光
	var glow_pts := PackedVector2Array([p_tip, p_left + perp * 3, p_right - perp * 3])
	var glow_cols := PackedColorArray([glow_color, glow_color, glow_color])
	draw_polygon(glow_pts, glow_cols)

	# 箭头主体（凹底四边形）
	var head_pts := PackedVector2Array([p_tip, p_left, p_indent, p_right])
	var head_cols := PackedColorArray([head_color, head_color, head_color, head_color])
	draw_polygon(head_pts, head_cols)

	# 箭头描边
	draw_polyline(head_pts + PackedVector2Array([p_tip]), Color(1, 1, 1, 0.4), 1.0, true)

## 设置箭头的首尾位置并立即重绘
func set_points(from_pos: Vector2, to_pos: Vector2):
	start_pos = from_pos
	end_pos = to_pos
	is_visible = true
	queue_redraw()

var _fade_tween: Tween = null

func show_arrow():
	is_visible = true
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	queue_redraw()

func hide_arrow():
	is_visible = false
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	modulate.a = 1.0
	queue_redraw()

## [未调用] 设置箭头颜色。若已实现调用方，请删除此标记注释。
func set_color(color: Color):
	line_color = color
	head_color = Color(color.r, color.g, color.b, 1.0)
	glow_color = Color(color.r, color.g, color.b, 0.25)
	if is_visible:
		queue_redraw()
