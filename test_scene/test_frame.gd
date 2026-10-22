## 最简单的测试：检查场景树是否处理帧
extends Node

var _log_path := "user://test_frame_log.txt"
var _faf: FileAccess
var _frame_count := 0

func _ready():
	_faf = FileAccess.open(_log_path, FileAccess.WRITE)
	_log("=== 帧测试 ===")
	_log("ready called")
	call_deferred("_run")

func _process(delta: float) -> void:
	_frame_count += 1
	if _frame_count <= 5 or _frame_count % 100 == 0:
		_log("  frame %d" % _frame_count)
	if _frame_count == 300:
		_log("=== 300帧完成 ===")
		if _faf:
			_faf.close()
		get_tree().quit()

func _log(msg: String) -> void:
	if _faf:
		_faf.store_line(msg)
	print(msg)

func _run() -> void:
	_log("run called")
	# Don't start battle, just wait for frames
	_log("waiting for frames...")