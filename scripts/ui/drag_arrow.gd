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
var arrow_color: Color = Color(1.0, 0.8, 0.2, 0.8)  ## 箭头颜色
var line_width: float = 3.0              ## 线宽
var arrow_head_size: float = 12.0        ## 箭头尖端大小
var is_visible: bool = false             ## 是否显示

func _ready():
	# 设置鼠标过滤器为忽略，确保箭头不拦截点击事件
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

## 自定义绘制：画一条线 + 一个三角形箭头头
func _draw():
	if not is_visible:
		return
	
	var direction = (end_pos - start_pos).normalized()
	var distance = start_pos.distance_to(end_pos)
	
	if distance < 10:
		return
	
	# 画线
	draw_line(start_pos, end_pos, arrow_color, line_width)
	
	# 计算箭头三角形的三个顶点
	var arrow_head_base = end_pos - direction * arrow_head_size
	var perpendicular = Vector2(-direction.y, direction.x)  # 垂直于线段方向
	var arrow_left = arrow_head_base + perpendicular * (arrow_head_size * 0.5)
	var arrow_right = arrow_head_base - perpendicular * (arrow_head_size * 0.5)
	
	# 画实心三角形箭头
	var arrow_points = PackedVector2Array([end_pos, arrow_left, arrow_right])
	var colors = PackedColorArray([arrow_color, arrow_color, arrow_color])
	draw_polygon(arrow_points, colors)

## 设置箭头的首尾位置并立即重绘
func set_points(from_pos: Vector2, to_pos: Vector2):
	start_pos = from_pos
	end_pos = to_pos
	is_visible = true
	queue_redraw()

func show_arrow():
	is_visible = true
	queue_redraw()

func hide_arrow():
	is_visible = false
	queue_redraw()

func set_color(color: Color):
	arrow_color = color
	if is_visible:
		queue_redraw()
