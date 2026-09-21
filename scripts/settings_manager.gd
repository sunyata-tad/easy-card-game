## SettingsManager —— 用户偏好设置管理器（Autoload）
## 独立于存档，持久化到 user://settings.json。删档不会重置偏好。
## 偏好定义不区分平台（全平台共享同一份 settings.json），
## 但某些偏好的"应用"和"UI 显示"会按平台过滤（如全屏仅 PC）。
extends Node

const SETTINGS_PATH := "user://settings.json"

## 默认偏好值（新增设置项时在此声明默认值）
const DEFAULTS := {
	"fullscreen": false,
	"master_volume": 1.0,
}

var _settings: Dictionary = {}

## 设置项变化通知。key 为设置名，value 为新值。
signal setting_changed(key: String, value)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply_fullscreen()

## 读取设置项。未声明则返回 default。
func get_setting(key: String, default: Variant = null) -> Variant:
	return _settings.get(key, default)

## 写入设置项并立即持久化 + 发信号。
func set_setting(key: String, value: Variant) -> void:
	_settings[key] = value
	_save()
	setting_changed.emit(key, value)

## 仅桌面端应用全屏模式。
func _apply_fullscreen() -> void:
	if not OS.has_feature("pc"):
		return
	var fullscreen: bool = _settings.get("fullscreen", false)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

## 切换全屏（仅 PC 调用）。立即应用 + 写回设置。
func toggle_fullscreen() -> void:
	if not OS.has_feature("pc"):
		return
	var current: bool = _settings.get("fullscreen", false)
	set_setting("fullscreen", not current)
	_apply_fullscreen()

func _load() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		_settings = DEFAULTS.duplicate(true)
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("SettingsManager: 无法读取设置文件")
		_settings = DEFAULTS.duplicate(true)
		return
	var json_string := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		push_error("SettingsManager: 设置文件解析失败，使用默认值")
		_settings = DEFAULTS.duplicate(true)
		return
	_settings = DEFAULTS.duplicate(true)
	_settings.merge(json.data, true)

func _save() -> void:
	var json_string := JSON.stringify(_settings, "  ")
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SettingsManager: 无法写入设置文件")
		return
	file.store_string(json_string)
	file.close()