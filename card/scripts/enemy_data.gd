class_name EnemyData

var id: String
var name: String
var max_hp: int
var ai_type: String
var actions: Array
var description: String

func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "未知敌人")
	max_hp = data.get("max_hp", 50)
	ai_type = data.get("ai_type", "passive")
	actions = data.get("actions", [])
	description = data.get("description", "")

func duplicate() -> EnemyData:
	return EnemyData.new({
		"id": id,
		"name": name,
		"max_hp": max_hp,
		"ai_type": ai_type,
		"actions": actions.duplicate(true),
		"description": description
	})
