extends Node

func _ready() -> void:
	var f := FileAccess.open("user://test_cost_log.txt", FileAccess.WRITE)
	var db := CardDatabase.new()
	for id in ["斩击", "重斩", "烈斩", "攻守兼备", "格挡", "铁壁"]:
		var c = db.get_card(id)
		if c and f:
			f.store_line("%s cost=%d" % [id, c.cost])
	if f: f.close()
	get_tree().quit()