## 全局场景过渡管理器（Autoload）：包装场景切换，提供黑屏淡入/淡出过渡。
## 流程：按钮消失+碎片 → 黑屏淡入 → 执行切换(callable) → 黑屏淡出 + 新场景入场。
## _play_cover/_play_uncover 保留为过场动画接口，当前实现为纯黑屏淡入淡出。
extends Node

const COVER_DURATION := 0.3
const UNCOVER_DURATION := 0.35
const BTN_VANISH_DURATION := 0.2

var _layer: CanvasLayer
var _overlay: ColorRect
var _tween: Tween
var _is_transitioning: bool = false
var _transition_token := 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100

	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_overlay)

func is_transitioning() -> bool:
	return _is_transitioning

## 通用过渡：先播 from_btn 消失+碎片，再黑屏淡入，执行 callable（场景切换），最后黑屏淡出 + 新场景入场。
## callable 应执行实际的场景切换（如 GameManager.go_to_xxx）。
func transition(callable: Callable, from_btn: Control = null) -> void:
	if _is_transitioning:
		_transition_token += 1
		callable.call()
		_overlay.modulate.a = 0.0
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_is_transitioning = false
		return
	_is_transitioning = true
	_transition_token += 1
	var my_token := _transition_token
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if from_btn and is_instance_valid(from_btn):
		if UIStyle:
			UIStyle.play_button_vanish(from_btn, BTN_VANISH_DURATION)
			UIStyle.spawn_shards(from_btn)
		await get_tree().create_timer(BTN_VANISH_DURATION).timeout
		if _transition_token != my_token:
			return
	_play_cover()
	await _tween.finished
	if _transition_token != my_token:
		return
	callable.call()
	await get_tree().process_frame
	if _transition_token != my_token:
		return
	if is_instance_valid(get_tree()) and get_tree().root.get_child_count() > 0:
		var new_scene = GameManager.current_scene if GameManager else null
		if new_scene and is_instance_valid(new_scene) and new_scene.has_method("play_entry_animation"):
			new_scene.play_entry_animation()
		_play_uncover()
		await _tween.finished
		if _transition_token != my_token:
			return
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false

## 黑屏淡入（过场接口，可替换为其他覆盖动画）
func _play_cover() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_overlay.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_overlay, "modulate:a", 1.0, COVER_DURATION)

## 黑屏淡出（过场接口，可替换为其他 uncover 动画）
func _play_uncover() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_overlay.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_property(_overlay, "modulate:a", 0.0, UNCOVER_DURATION)
