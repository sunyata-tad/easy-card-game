## ScreenShake —— 屏幕震动效果（操作 Camera2D 的 offset 逐帧随机抖动 + 衰减）
## 用法：实例化后 setup(camera)，调 shake(amplitude, duration)
extends Node

var _camera: Camera2D = null
var _amplitude: float = 0.0
var _duration: float = 0.0
var _elapsed: float = 0.0
var _original_offset: Vector2 = Vector2.ZERO
var _shaking: bool = false

func setup(camera: Camera2D) -> void:
	_camera = camera
	_original_offset = camera.offset

func shake(amplitude: float, duration: float) -> void:
	if _camera == null or amplitude <= 0.0 or duration <= 0.0:
		return
	_amplitude = amplitude
	_duration = duration
	_elapsed = 0.0
	_shaking = true

func _process(delta: float) -> void:
	if not _shaking or _camera == null:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		_camera.offset = _original_offset
		_shaking = false
		return
	var decay := 1.0 - _elapsed / _duration
	var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _amplitude * decay
	_camera.offset = _original_offset + offset