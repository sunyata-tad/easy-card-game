class_name BuffManager

var buffs: Array = []
var hook_chain: HookChain = null

const HOOK_BASE: String = "calc_attack_base"
const HOOK_MULT: String = "calc_attack_mult"
const HOOK_ADDITION: String = "calc_attack_damage"
const HOOK_FINAL_MULT: String = "calc_attack_final"
const HOOK_DAMAGE_TAKEN: String = "on_damage_taken"
const HOOK_BLOCK: String = "calc_attack_block"
const HOOK_ATTACK_START: String = "on_attack_start"
const HOOK_ATTACK_HIT: String = "on_attack_hit"
const HOOK_ATTACK_END: String = "on_attack_end"

signal buff_applied(buff: BuffData)
signal buff_removed(buff: BuffData)
signal buff_expired(buff: BuffData)
signal buffs_changed()

var DURATION_STACK_BUFFS: Array = ["weak", "vulnerable"]

func _init(target_hook_chain: HookChain = null):
	hook_chain = target_hook_chain

func _hook_id(buff_id: String, suffix: String = "") -> String:
	return "buff_" + buff_id + ("_" + suffix if suffix != "" else "")

func _register_buff_hook(buff: BuffData) -> void:
	if hook_chain == null: return
	match buff.id:
		"strength":
			hook_chain.register(HOOK_ADDITION, func(v, _c): return v + buff.stacks, 10, _hook_id("strength"))
		"dexterity":
			hook_chain.register(HOOK_BLOCK, func(v, _c): return v + buff.stacks, 10, _hook_id("dexterity"))
		"temp_strength":
			hook_chain.register(HOOK_BASE, func(v, _c): return v + buff.stacks, 5, _hook_id("temp_strength"))
		"weak":
			hook_chain.register(HOOK_FINAL_MULT, func(v, _c): return maxi(1, int(v * 0.75)), 20, _hook_id("weak"))
		"vulnerable":
			hook_chain.register(HOOK_DAMAGE_TAKEN, func(v, _c): return maxi(1, int(v * 1.5)), 20, _hook_id("vulnerable"))
		"skip_attack":
			hook_chain.register(HOOK_ATTACK_START, func(v, c): c["skip_attack"] = true; return v, 100, _hook_id("skip_attack"))
		"ignore_block":
			hook_chain.register(HOOK_ATTACK_START, func(v, c): c["ignore_block"] = true; return v, 50, _hook_id("ignore_block"))
		"counter_stance":
			hook_chain.register(HOOK_ATTACK_HIT, func(v, c): if v is int and v > 0: c["counter_damage"] = v; return v, 50, _hook_id("counter_stance"))

func _unregister_buff_hook(buff_id: String) -> void:
	if hook_chain == null: return
	hook_chain.unregister(HOOK_BASE, _hook_id(buff_id))
	hook_chain.unregister(HOOK_ADDITION, _hook_id(buff_id))
	hook_chain.unregister(HOOK_BLOCK, _hook_id(buff_id))
	hook_chain.unregister(HOOK_MULT, _hook_id(buff_id))
	hook_chain.unregister(HOOK_FINAL_MULT, _hook_id(buff_id))
	hook_chain.unregister(HOOK_DAMAGE_TAKEN, _hook_id(buff_id))
	hook_chain.unregister(HOOK_ATTACK_START, _hook_id(buff_id))
	hook_chain.unregister(HOOK_ATTACK_HIT, _hook_id(buff_id))

func _update_strength_hook(new_stacks: int) -> void:
	if hook_chain == null: return
	hook_chain.unregister(HOOK_ADDITION, _hook_id("strength"))
	hook_chain.register(HOOK_ADDITION, func(v, _c): return v + new_stacks, 10, _hook_id("strength"))

func _update_temp_strength_hook(new_stacks: int) -> void:
	if hook_chain == null: return
	hook_chain.unregister(HOOK_BASE, _hook_id("temp_strength"))
	hook_chain.register(HOOK_BASE, func(v, _c): return v + new_stacks, 5, _hook_id("temp_strength"))

func apply_buff(buff: BuffData) -> void:
	var existing = get_buff_by_id(buff.id)
	if existing != null:
		if DURATION_STACK_BUFFS.has(buff.id):
			if buff.duration > 0: existing.duration += buff.duration
		else:
			existing.add_stacks(buff.stacks)
			if buff.duration > 0 and existing.duration < buff.duration: existing.duration = buff.duration
			if buff.id == "strength": _update_strength_hook(existing.stacks)
			elif buff.id == "temp_strength": _update_temp_strength_hook(existing.stacks)
	else:
		var new_buff = buff.duplicate(); buffs.append(new_buff); _register_buff_hook(new_buff)
	buff_applied.emit(buff); buffs_changed.emit()

func remove_buff(buff_id: String) -> void:
	var buff = get_buff_by_id(buff_id)
	if buff != null: _unregister_buff_hook(buff_id); buffs.erase(buff); buff_removed.emit(buff); buffs_changed.emit()

func get_buff_by_id(buff_id: String) -> BuffData:
	for buff in buffs: if buff.id == buff_id: return buff
	return null

func get_all_buffs() -> Array: return buffs.duplicate()

func has_buff(buff_id: String) -> bool: return get_buff_by_id(buff_id) != null

func get_flat_add(stat_name: String) -> float:
	var total: float = 0.0
	for buff in buffs: if buff.modifiers.has(stat_name + "_add"): total += buff.modifiers[stat_name + "_add"]
	return total

func get_mult(stat_name: String) -> float:
	var total: float = 1.0
	for buff in buffs: if buff.modifiers.has(stat_name + "_mult"): total *= buff.modifiers[stat_name + "_mult"]
	return total

func tick_buffs(timing: String) -> Array:
	var triggered: Array = []
	for buff in buffs:
		if buff.trigger_timing == timing and buff.tick_effect.size() > 0:
			var e = buff.tick_effect.duplicate(); e.buff_id = buff.id; e.stacks = buff.stacks; triggered.append(e)
	return triggered

func decrease_durations() -> void:
	var expired: Array = []
	for buff in buffs:
		buff.decrease_duration()
		if buff.stack_decay.has("on_turn_end"): buff.remove_stacks(buff.stack_decay["on_turn_end"])
		elif buff.stack_decay.has("on_turn_end_pct"): buff.remove_stacks(max(int(buff.stacks * buff.stack_decay["on_turn_end_pct"]), 1))
		if buff.is_expired(): expired.append(buff)
	for buff in expired: _unregister_buff_hook(buff.id); buffs.erase(buff); buff_expired.emit(buff)
	if expired.size() > 0: buffs_changed.emit()

func decay_on_event(event: String) -> void:
	var expired: Array = []
	for buff in buffs:
		if buff.stack_decay.has(event): buff.remove_stacks(buff.stack_decay[event])
		if buff.is_expired(): expired.append(buff)
	for buff in expired: _unregister_buff_hook(buff.id); buffs.erase(buff); buff_expired.emit(buff)
	if expired.size() > 0: buffs_changed.emit()

func clear_all_buffs() -> void:
	for buff in buffs: _unregister_buff_hook(buff.id)
	buffs.clear(); buffs_changed.emit()

func remove_at_turn_end() -> void:
	var to_remove: Array = []
	for buff in buffs: if buff.trigger_timing == "on_turn_end_remove": to_remove.append(buff)
	for buff in to_remove: _unregister_buff_hook(buff.id); buffs.erase(buff); buff_expired.emit(buff)
	if to_remove.size() > 0: buffs_changed.emit()