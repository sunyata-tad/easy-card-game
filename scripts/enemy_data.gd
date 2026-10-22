## 敌人数据模型：存储单个敌人的静态配置（来自 JSON）。
class_name EnemyData

var id: String              ## 敌人唯一 id
var name: String            ## 显示名称
var max_hp: int             ## 最大血量
var ai_type: String         ## AI 类型："aggressive"/"defensive"/"balanced" 等
var actions: Array          ## 旧格式行动列表（新流程不用）
var description: String     ## 描述文本
var art: String = ""        ## 美术资源路径
## 新流程字段
var deck: String = "basic"  ## 卡组类型（"basic"=基础卡组）
var energy: int = 3         ## 初始能量
var energy_regen: int = 1   ## 每回合能量恢复
var slots: int = 1          ## 槽位数量
var speed: int = 1          ## 速度属性

func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "未知敌人")
	max_hp = data.get("max_hp", 50)
	ai_type = data.get("ai_type", "passive")
	actions = data.get("actions", [])
	description = data.get("description", "")
	art = data.get("art", "")
	# 新流程字段
	deck = data.get("deck", "basic")
	energy = data.get("energy", 3)
	energy_regen = data.get("energy_regen", 1)
	slots = data.get("slots", 1)
	speed = data.get("speed", 1)

func duplicate() -> EnemyData:
	return EnemyData.new({
		"id": id,
		"name": name,
		"max_hp": max_hp,
		"ai_type": ai_type,
		"actions": actions.duplicate(true),
		"description": description,
		"art": art,
		"deck": deck,
		"energy": energy,
		"energy_regen": energy_regen,
		"slots": slots,
		"speed": speed
	})
