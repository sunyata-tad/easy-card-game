## ScreenShake —— 屏幕震动效果（操作目标 Control 的 position 逐帧随机抖动 + 衰减）
## 用法：实例化后 setup(target_control)，调 shake(amplitude, duration)
## 抖动根 Control 的 position 让所有子节点跟着移动，实现屏幕震动
extends Node

var _target: Control = null
var _amplitude: float = 0.0
var _duration: float = 0.0
var _elapsed: float = 0.0
var _original_pos: Vector2 = Vector2.ZERO
var _shaking: bool = false

func setup(target: Control) -> void:
	_target = target
	_original_pos = target.position

func shake(amplitude: float, duration: float) -> void:
	if _target == null or amplitude <= 0.0 or duration <= 0.0:
		return
	_amplitude = amplitude
	_duration = duration
	_elapsed = 0.0
	_shaking = true

func _process(delta: float) -> void:
	if not _shaking or _target == null:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		_target.position = _original_pos
		_shaking = false
		return
	var decay := 1.0 - _elapsed / _duration
	var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _amplitude * decay
	_target.position = _original_pos + offset