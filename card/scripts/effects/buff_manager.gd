class_name BuffManager

var buffs: Array = []

signal buff_applied(buff: BuffData)
signal buff_removed(buff: BuffData)
signal buff_expired(buff: BuffData)
signal buffs_changed()

func _init():
	pass

func apply_buff(buff: BuffData) -> void:
	var existing = get_buff_by_id(buff.id)
	if existing != null:
		existing.add_stacks(buff.stacks)
		if buff.duration > 0 and existing.duration < buff.duration:
			existing.duration = buff.duration
	else:
		buffs.append(buff.duplicate())
	
	buff_applied.emit(buff)
	buffs_changed.emit()

func remove_buff(buff_id: String) -> void:
	var buff = get_buff_by_id(buff_id)
	if buff != null:
		buffs.erase(buff)
		buff_removed.emit(buff)
		buffs_changed.emit()

func get_buff_by_id(buff_id: String) -> BuffData:
	for buff in buffs:
		if buff.id == buff_id:
			return buff
	return null

func get_all_buffs() -> Array:
	return buffs.duplicate()

func has_buff(buff_id: String) -> bool:
	return get_buff_by_id(buff_id) != null

func get_modifier(stat_name: String) -> float:
	var total_mult: float = 1.0
	var total_add: float = 0.0
	
	for buff in buffs:
		if buff.modifiers.has(stat_name + "_mult"):
			total_mult *= buff.modifiers[stat_name + "_mult"]
		if buff.modifiers.has(stat_name + "_add"):
			total_add += buff.modifiers[stat_name + "_add"] * buff.stacks
	
	return total_mult + total_add

func tick_buffs(timing: String) -> Array:
	var triggered_effects: Array = []
	
	for buff in buffs:
		if buff.trigger_timing == timing and buff.tick_effect.size() > 0:
			var effect = buff.tick_effect.duplicate()
			effect.buff_id = buff.id
			effect.stacks = buff.stacks
			triggered_effects.append(effect)
	
	return triggered_effects

func decrease_durations() -> void:
	var expired_buffs: Array = []
	
	for buff in buffs:
		buff.decrease_duration()
		if buff.is_expired():
			expired_buffs.append(buff)
	
	for buff in expired_buffs:
		buffs.erase(buff)
		buff_expired.emit(buff)
	
	if expired_buffs.size() > 0:
		buffs_changed.emit()

func clear_all_buffs() -> void:
	buffs.clear()
	buffs_changed.emit()

func remove_at_turn_end() -> void:
	var to_remove: Array = []
	for buff in buffs:
		if buff.trigger_timing == "on_turn_end_remove":
			to_remove.append(buff)
	for buff in to_remove:
		buffs.erase(buff)
		buff_expired.emit(buff)
	if to_remove.size() > 0:
		buffs_changed.emit()
