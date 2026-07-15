## Buff（增益/减益效果）的数据模型，存储单个 buff 的所有属性和状态。
## Godot 特色：
## - _init(data) 是构造函数，在 BuffData.new(dict) 时自动调用（类似 Python 的 __init__）
## - Dictionary 的 .get(key, default) 方法安全获取值，key 不存在时返回默认值
## - mini(a, b) / maxi(a, b) 是 Godot 内置的取小/取大函数（类似 Python 的 min/max，但专门用于整数）
class_name BuffData

var id: String              ## buff 唯一标识，如 "strength"、"weak"
var name: String            ## 显示名称
var buff_type: String       ## 类型："buff"（增益）或 "debuff"（减益）
var duration: int           ## 剩余持续回合数，-1 表示永久
var stacks: int             ## 当前叠加层数
var max_stacks: int         ## 最大叠加层数
var trigger_timing: String  ## 触发时机，如 "on_turn_start"、"on_turn_end"、"passive"
var modifiers: Dictionary   ## 属性修正值，如 {"block_add": 5, "damage_mult": 1.5}
var tick_effect: Dictionary ## 持续型效果，如每回合造成伤害/治疗
var icon_path: String       ## 图标资源路径
var stack_decay: Dictionary ## 层数衰减规则，如 {"on_turn_end": 1} 表示每回合减1层

func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	buff_type = data.get("buff_type", "buff")
	duration = data.get("duration", -1)
	stacks = data.get("stacks", 1)
	max_stacks = data.get("max_stacks", 99)
	trigger_timing = data.get("trigger_timing", "passive")
	modifiers = data.get("modifiers", {})
	tick_effect = data.get("tick_effect", {})
	icon_path = data.get("icon_path", "")
	stack_decay = data.get("stack_decay", {})

## 增加层数，但不超过最大层数
func add_stacks(amount: int) -> void:
	stacks = mini(stacks + amount, max_stacks)

## 减少层数，不低于 0
func remove_stacks(amount: int) -> void:
	stacks = maxi(stacks - amount, 0)

## 减少 1 回合持续时间（仅限非永久的 buff）
func decrease_duration() -> void:
	if duration > 0:
		duration -= 1

## 判断 buff 是否已失效（持续回合耗尽或层数归零）
func is_expired() -> bool:
	return duration == 0 or stacks <= 0

## 深拷贝当前 buff 数据
## @param true 参数表示递归复制嵌套的 Dictionary（类似 Python 的 copy.deepcopy）
func duplicate() -> BuffData:
	return BuffData.new({
		"id": id,
		"name": name,
		"buff_type": buff_type,
		"duration": duration,
		"stacks": stacks,
		"max_stacks": max_stacks,
		"trigger_timing": trigger_timing,
		"modifiers": modifiers.duplicate(true),
		"tick_effect": tick_effect.duplicate(true),
		"icon_path": icon_path,
		"stack_decay": stack_decay.duplicate(true)
	})
