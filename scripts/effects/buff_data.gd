class_name BuffData

var id: String
var name: String
var buff_type: String
var duration: int
var stacks: int
var max_stacks: int
var trigger_timing: String
var modifiers: Dictionary
var tick_effect: Dictionary
var icon_path: String

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

func add_stacks(amount: int) -> void:
	stacks = mini(stacks + amount, max_stacks)

func remove_stacks(amount: int) -> void:
	stacks = maxi(stacks - amount, 0)

func decrease_duration() -> void:
	if duration > 0:
		duration -= 1

func is_expired() -> bool:
	return duration == 0 or stacks <= 0

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
		"icon_path": icon_path
	})
