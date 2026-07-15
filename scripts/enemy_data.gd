## 敌人数据模型：存储单个敌人的静态配置（来自 JSON）。
class_name EnemyData

var id: String              ## 敌人唯一 id
var name: String            ## 显示名称
var max_hp: int             ## 最大血量
var ai_type: String         ## AI 类型："random"（随机行动）、"pattern"（固定模式）等
var actions: Array          ## 行动列表，每个元素是 {"type": "attack", "damage": 5} 等
var description: String     ## 描述文本

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
