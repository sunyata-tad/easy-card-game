## 遗物数据库：从 data/relics.json 加载遗物定义。
class_name RelicDatabase

var _relics: Dictionary = {}

func _init():
	_load()

func _load() -> void:
	var file = FileAccess.open("res://data/relics.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json and json.has("relics"):
			for rid in json["relics"]:
				var data = json["relics"][rid]
				data["id"] = rid
				_relics[rid] = RelicData.new(data)
		file.close()

func get_relic(id: String) -> RelicData:
	return _relics.get(id, null)

func has_relic(id: String) -> bool:
	return _relics.has(id)

## 获取所有遗物 id 列表
func get_all_relic_ids() -> Array:
	return _relics.keys()

## 获取可获得的遗物池（用于 Boss 战后三选一）
## @param owned_ids: 已拥有的遗物 id（不可重复者排除）
## 可重复遗物始终在池中（保证流程不卡死，如占位遗物"头环"）
func get_relic_pool(owned_ids: Array) -> Array:
	var pool: Array = []
	for rid in _relics:
		var r = _relics[rid]
		if r.repeatable or not owned_ids.has(rid):
			pool.append(rid)
	return pool
