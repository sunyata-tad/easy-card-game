class_name DragArrow
extends Control

var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO
var arrow_color: Color = Color(1.0, 0.8, 0.2, 0.8)
var line_width: float = 3.0
var arrow_head_size: float = 12.0
var is_visible: bool = false

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

func _draw():
	if not is_visible:
		return
	
	var direction = (end_pos - start_pos).normalized()
	var distance = start_pos.distance_to(end_pos)
	
	if distance < 10:
		return
	
	draw_line(start_pos, end_pos, arrow_color, line_width)
	
	var arrow_head_base = end_pos - direction * arrow_head_size
	var perpendicular = Vector2(-direction.y, direction.x)
	var arrow_left = arrow_head_base + perpendicular * (arrow_head_size * 0.5)
	var arrow_right = arrow_head_base - perpendicular * (arrow_head_size * 0.5)
	
	var arrow_points = PackedVector2Array([end_pos, arrow_left, arrow_right])
	var colors = PackedColorArray([arrow_color, arrow_color, arrow_color])
	draw_polygon(arrow_points, colors)

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
