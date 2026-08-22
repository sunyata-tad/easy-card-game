## AnimatedButton —— 基于 Godot 4.7 Offset Transform 的动画按钮脚本。
## 挂到 Button 节点（编辑器设 script，或 set_script 到动态按钮）：
## 悬停放大、点击挤压、移出复原。纯视觉，不影响 Container 布局。
## 依赖 Control.offset_transform_* (Godot 4.7 新增)；offset_transform_visual_only 默认 true。
extends Button

@export var hover_scale: Vector2 = Vector2(1.08, 1.08)
@export var press_scale: Vector2 = Vector2(0.94, 0.94)
@export var hover_time: float = 0.12
@export var press_time: float = 0.08

var _anim_tween: Tween = null
var _is_hovered: bool = false


func _ready() -> void:
	offset_transform_enabled = true
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not button_down.is_connected(_on_button_down):
		button_down.connect(_on_button_down)
	if not button_up.is_connected(_on_button_up):
		button_up.connect(_on_button_up)


func _on_mouse_entered() -> void:
	_is_hovered = true
	_tween_scale(hover_scale, hover_time)


func _on_mouse_exited() -> void:
	_is_hovered = false
	_tween_scale(Vector2.ONE, hover_time)


func _on_button_down() -> void:
	_tween_scale(press_scale, press_time)


func _on_button_up() -> void:
	_tween_scale(hover_scale if _is_hovered else Vector2.ONE, press_time)


func _tween_scale(target: Vector2, duration: float) -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "offset_transform_scale", target, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)