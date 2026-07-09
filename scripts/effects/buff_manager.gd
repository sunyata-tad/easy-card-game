class_name BuffManager

var buffs: Array = []

signal buff_applied(buff: BuffData)
signal buff_removed(buff: BuffData)
signal buff_expired(buff: BuffData)
signal buffs_changed()

var DURATION_STACK_BUFFS: Array = ["weak", "vulnerable"]

static var _buff_db: Dictionary = {}
static var _modifier_formula_builders: Dictionary = {
	"damage_add": func(stacks: int) -> Dictionary: return {"damage_add": float(stacks)},
	"block_add": func(stacks: int) -> Dictionary: return {"block_add": float(stacks)},
	"damage_mult_025": func(_stacks: int) -> Dictionary: return {"damage_mult": 0.75},
	"damage_taken_mult_05": func(_stacks: int) -> Dictionary: return {"damage_taken_mult": 1.5},
}

var MODIFIER_FORMULAS: Dictionary = {}

func _init():
	_load_buff_db()
	_build_modifier_formulas()

func _load_buff_db() -> void:
	if not _buff_db.is_empty():
		return
	var file = FileAccess.open("res://data/buffs.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json and json.has("buffs"):
			_buff_db = json["buffs"]
		file.close()

func _get_buff_data(buff_id: String) -> Dictionary:
	if _buff_db.is_empty():
		_load_buff_db()
	return _buff_db.get(buff_id, {})

func _build_modifier_formulas() -> void:
	if not MODIFIER_FORMULAS.is_empty():
		return
	for buff_id in _buff_db:
		var data = _buff_db[buff_id]
		var formula_key = data.get("modifier_formula")
		if formula_key != null and _modifier_formula_builders.has(formula_key):
			MODIFIER_FORMULAS[buff_id] = _modifier_formula_builders[formula_key]
		else:
			MODIFIER_FORMULAS[buff_id] = func(_stacks: int) -> Dictionary: return {}

func apply_buff(buff: BuffData) -> void:
	var existing = get_buff_by_id(buff.id)
	if existing != null:
		if DURATION_STACK_BUFFS.has(buff.id):
			if buff.duration > 0:
				existing.duration += buff.duration
		else:
			existing.add_stacks(buff.stacks)
			if buff.duration > 0 and existing.duration < buff.duration:
				existing.duration = buff.duration
			recalculate_modifiers(existing)
	else:
		var new_buff = buff.duplicate()
		recalculate_modifiers(new_buff)
		buffs.append(new_buff)
	
	buff_applied.emit(buff)
	buffs_changed.emit()

func recalculate_modifiers(buff: BuffData) -> void:
	if MODIFIER_FORMULAS.has(buff.id):
		buff.modifiers = MODIFIER_FORMULAS[buff.id].call(buff.stacks)

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

func get_flat_add(stat_name: String) -> float:
	var total_add: float = 0.0
	for buff in buffs:
		if buff.modifiers.has(stat_name + "_add"):
			total_add += buff.modifiers[stat_name + "_add"]
	return total_add

func get_mult(stat_name: String) -> float:
	var total_mult: float = 1.0
	for buff in buffs:
		if buff.modifiers.has(stat_name + "_mult"):
			total_mult *= buff.modifiers[stat_name + "_mult"]
	return total_mult

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
		if buff.stack_decay.has("on_turn_end"):
			var decay_amount = buff.stack_decay["on_turn_end"]
			buff.remove_stacks(decay_amount)
			recalculate_modifiers(buff)
		elif buff.stack_decay.has("on_turn_end_pct"):
			var pct = buff.stack_decay["on_turn_end_pct"]
			var decay_amount = max(int(buff.stacks * pct), 1)
			buff.remove_stacks(decay_amount)
			recalculate_modifiers(buff)
		if buff.is_expired():
			expired_buffs.append(buff)
	
	for buff in expired_buffs:
		buffs.erase(buff)
		buff_expired.emit(buff)
	
	if expired_buffs.size() > 0:
		buffs_changed.emit()

func decay_on_event(event: String) -> void:
	var expired_buffs: Array = []
	
	for buff in buffs:
		if buff.stack_decay.has(event):
			var decay_amount = buff.stack_decay[event]
			buff.remove_stacks(decay_amount)
			recalculate_modifiers(buff)
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