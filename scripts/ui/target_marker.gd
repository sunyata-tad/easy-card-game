## 目标标记：在选中的敌人上显示金色半透明方框和剑图标。
## Godot 特色：
## - _process(delta) 每帧调用（类似 Unity 的 Update），用于持续更新标记位置
## - is_instance_valid(node) 检查节点是否还没被释放（避免引用已销毁的节点）
extends Control

var target_node: Control = null    ## 被标记的目标节点
var marker_rect: ColorRect = null  ## 标记矩形（半透明金色覆盖层）

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	
	marker_rect = ColorRect.new()
	marker_rect.color = Color(1.0, 0.8, 0.0, 0.3)
	marker_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(marker_rect)
	
	_create_border()

func _create_border():
	var border = ColorRect.new()
	border.color = Color(1.0, 0.8, 0.0, 1.0)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style_box = StyleBoxFlat.new()
	style_box.border_color = Color(1.0, 0.8, 0.0, 1.0)
	style_box.set_border_width_all(3)
	style_box.bg_color = Color(0, 0, 0, 0)

## 每帧更新：将标记位置和大小同步到目标节点
func _process(_delta):
	if target_node == null:
		marker_rect.visible = false
		return
	
	if not is_instance_valid(target_node):
		target_node = null
		marker_rect.visible = false
		return
	
	marker_rect.visible = true
	marker_rect.global_position = target_node.global_position
	marker_rect.size = target_node.size
	
	# 创建/更新剑形标签
	var label = get_node_or_null("TargetLabel")
	if label == null:
		label = Label.new()
		label.name = "TargetLabel"
		label.text = "⚔"
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0, 1.0))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)
	
	label.global_position = target_node.global_position + target_node.size / 2 - Vector2(16, 16)

func set_target(node: Control):
	target_node = node

func clear():
	target_node = null
	marker_rect.visible = false
	
	var label = get_node_or_null("TargetLabel")
	if label:
		label.visible = false
