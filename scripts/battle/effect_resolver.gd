class_name EffectResolver

var card_database: CardDatabase
var card_system: CardSystem = null
var _temp_attack_boost: int = 0
var _temp_hook_ids: Array = []

signal effect_resolved(effect_type: int, result: Dictionary)
signal damage_dealt(target, amount: int)
signal block_gained(target, amount: int)
signal healing_done(target, amount: int)
signal cards_drawn(count: int)
signal buff_applied(target, buff: BuffData)

func _init():
	card_database = CardDatabase.new()

func resolve_effects(effects: Array, source, target = null) -> Array:
	var results: Array = []
	for e in effects:
		results.append(resolve_effect(e, source, target))
	return results

func resolve_effect(effect: Dictionary, source, target = null) -> Dictionary:
	var effect_type_str = effect.get("effect_type", "")
	var value = effect.get("value", 0)
	var result: Dictionary = {"success": false, "value": 0}
	
	var base_stat = effect.get("base_stat", "")
	var multiplier = effect.get("multiplier", 1.0)
	if base_stat != "" and source is PlayerManager:
		var stat_value = 0
		if base_stat == "strength": stat_value = source.get_strength()
		elif base_stat == "dexterity": stat_value = source.get_dexterity()
		value = value + int(stat_value * multiplier)
	
	match effect_type_str:
		"damage": result = _resolve_damage(value, source, target)
		"block": result = _resolve_block(value, source, target)
		"heal": result = _resolve_heal(value, source, target)
		"damage_boost": result = _resolve_damage_boost(value, source)
		"temp_damage_boost": result = _resolve_temp_damage_boost(value, source)
		"skip_attack": result = _resolve_skip_attack(value, source)
		"store_damage": result = _resolve_store_damage(source)
		"ignore_block": result = _resolve_ignore_block(source)
		"counter_stance": result = _resolve_counter_stance(source)
		"draw": result = _resolve_draw(value, source)
		"search_draw": result = _resolve_search_draw(effect, source)
		"search_discard": result = _resolve_search_discard(effect, source)
		"search_draw_by_tag": result = _resolve_search_draw_by_tag(effect, source)
		"search_discard_by_tag": result = _resolve_search_discard_by_tag(effect, source)
		"exhaust_random": result = _resolve_exhaust_random(value, source)
		"discard_random": result = _resolve_discard_random(value, source)
		"shuffle_discard_to_draw": result = _resolve_shuffle_discard_to_draw(source)
		"apply_buff", "apply_debuff": result = _resolve_apply_buff(effect, target)
		"add_card_to_hand": result = _resolve_add_card(effect, source)
	
	effect_resolved.emit(effect_type_str, result)
	return result

func _get_hook_chain(source) -> HookChain:
	if source is PlayerManager: return source.hook_chain
	if source is EnemyUnit: return source.hook_chain
	return null

func _resolve_damage(base_damage: int, source, target) -> Dictionary:
	if target == null:
		return {"success": false, "value": 0}
	var hc = _get_hook_chain(source)
	
	if source is PlayerManager and hc:
		var ctx: Dictionary = {}
		hc.trigger("on_attack_start", 0, ctx)
		var base = hc.trigger("calc_attack_base", source.base_strength, ctx)
		base = int(hc.trigger("calc_attack_mult", int(base), ctx))
		var add = hc.trigger("calc_attack_damage", 0, ctx)
		var raw = int(base) + int(add)
		source.damage_final_mult = 1.0
		var final_dmg = hc.trigger("calc_attack_final", raw, ctx)
		hc.trigger("on_attack_hit", final_dmg, {"hit_index": 0})
		if target is EnemyUnit:
			target.take_damage(final_dmg, ctx.get("ignore_block", false))
		elif target is PlayerManager:
			target.take_damage(final_dmg)
		hc.trigger("on_attack_end", 0, ctx)
		damage_dealt.emit(target, final_dmg)
		return {"success": true, "value": final_dmg, "target": target}
	
	if hc:
		var total = base_damage
		var ctx: Dictionary = {}
		hc.trigger("on_attack_start", total, ctx)
		var hit_value = hc.trigger("calc_attack_base", total, ctx)
		hit_value = hc.trigger("calc_attack_mult", hit_value, ctx)
		hit_value = hc.trigger("calc_attack_damage", hit_value, ctx)
		hit_value = hc.trigger("calc_attack_final", hit_value, ctx)
		hc.trigger("on_attack_hit", hit_value, {"hit_index": 0})
		if target is PlayerManager: target.take_damage(hit_value)
		elif target is EnemyUnit: target.take_damage(hit_value)
		hc.trigger("on_attack_end", 0, ctx)
		damage_dealt.emit(target, hit_value)
		return {"success": true, "value": hit_value, "target": target}
	
	if target is PlayerManager:
		var actual = target.take_damage(base_damage)
		damage_dealt.emit(target, actual)
		return {"success": true, "value": actual, "target": target}
	elif target is EnemyUnit:
		var actual = target.take_damage(base_damage)
		damage_dealt.emit(target, actual)
		return {"success": true, "value": actual, "target": target}
	return {"success": false, "value": 0}

func _resolve_block(base_block: int, source, target) -> Dictionary:
	var block_mult: float = 1.0
	if target is PlayerManager: block_mult = target.buff_manager.get_mult("block")
	elif target is EnemyUnit: block_mult = target.buff_manager.get_mult("block")
	var final_block = int(base_block * block_mult)
	if final_block <= 0: return {"success": false, "value": 0}
	if target is PlayerManager: target.gain_block(final_block); block_gained.emit(target, final_block)
	elif target is EnemyUnit: target.gain_block(final_block); block_gained.emit(target, final_block)
	return {"success": true, "value": final_block, "target": target}

func _resolve_heal(base_heal: int, source, target) -> Dictionary:
	var heal_mult: float = 1.0
	if target is PlayerManager: heal_mult = target.buff_manager.get_mult("heal")
	var final_heal = int(base_heal * heal_mult)
	if target is PlayerManager: var actual = target.heal(final_heal); healing_done.emit(target, actual); return {"success": true, "value": actual, "target": target}
	elif target is EnemyUnit: var actual = target.heal(final_heal); healing_done.emit(target, actual); return {"success": true, "value": actual, "target": target}
	return {"success": false, "value": 0}

func _resolve_damage_boost(value: int, source) -> Dictionary:
	if source is PlayerManager: source.base_strength += value; return {"success": true, "value": value}
	return {"success": false, "value": 0}

func _resolve_temp_damage_boost(value: int, source) -> Dictionary:
	if source is PlayerManager:
		_temp_attack_boost += value
		var hook_id = "temp_atk_%d" % _temp_hook_ids.size()
		source.hook_chain.register("calc_attack_base", func(v, _c): return v + value, 5, hook_id)
		_temp_hook_ids.append(hook_id)
		return {"success": true, "value": value}
	return {"success": false, "value": 0}

func _resolve_skip_attack(_value: int, source) -> Dictionary:
	if source is PlayerManager and not source.buff_manager.has_buff("skip_attack"):
		var buff = BuffData.new({"id": "skip_attack", "name": "蓄势", "buff_type": "buff", "duration": 1, "stacks": 1, "trigger_timing": "on_turn_end_remove"})
		source.buff_manager.apply_buff(buff)
		return {"success": true, "value": 1}
	return {"success": false, "value": 0}

func _resolve_store_damage(source) -> Dictionary:
	## 走前3步管道计算 raw_damage，累加到 pending
	if source is PlayerManager:
		var ctx: Dictionary = {}
		var v = source.base_strength
		v = source.hook_chain.trigger("calc_attack_base", v, ctx)
		v = int(source.hook_chain.trigger("calc_attack_mult", v, ctx))
		var add = source.hook_chain.trigger("calc_attack_damage", 0, ctx)
		var raw = v + add
		clear_temp_hooks(source)
		source.pending_stored_damage += raw
		return {"success": true, "value": raw, "stored_total": source.pending_stored_damage}
	return {"success": false, "value": 0}

func _resolve_ignore_block(source) -> Dictionary:
	if source is PlayerManager:
		var buff = BuffData.new({"id": "ignore_block", "name": "破甲", "buff_type": "buff", "duration": 1, "stacks": 1, "trigger_timing": "on_turn_end_remove"})
		source.buff_manager.apply_buff(buff)
		return {"success": true, "value": 1}
	return {"success": false, "value": 0}

func _resolve_counter_stance(source) -> Dictionary:
	if source is PlayerManager:
		var buff = BuffData.new({"id": "counter_stance", "name": "招架", "buff_type": "buff", "duration": 1, "stacks": 1, "trigger_timing": "on_turn_end_remove"})
		source.buff_manager.apply_buff(buff)
		return {"success": true, "value": 1}
	return {"success": false, "value": 0}

func _resolve_draw(count: int, source) -> Dictionary:
	if card_system: var drawn = card_system.draw_cards(count); cards_drawn.emit(drawn.size()); return {"success": true, "value": drawn.size()}
	elif source.has_method("get") and source.get("card_system"): var cs = source.card_system; var drawn = cs.draw_cards(count); return {"success": true, "value": drawn.size()}
	return {"success": false, "value": 0}

func _resolve_search_draw(effect: Dictionary, source) -> Dictionary:
	var cs = card_system
	if not cs and source.has_method("get") and source.get("card_system"): cs = source.card_system
	if cs: var card = cs.search_and_draw(effect.get("card_id", "")); return {"success": card != null, "value": 1} if card else {}
	return {"success": false, "value": 0}

func _resolve_search_discard(effect: Dictionary, source) -> Dictionary:
	var cs = card_system
	if not cs and source.has_method("get") and source.get("card_system"): cs = source.card_system
	if cs: var card = cs.search_discard_and_draw(effect.get("card_id", "")); return {"success": card != null, "value": 1} if card else {}
	return {"success": false, "value": 0}

func apply_buff(effect: Dictionary, target) -> Dictionary:
	return _resolve_apply_buff(effect, target)

func _resolve_apply_buff(effect: Dictionary, target) -> Dictionary:
	var buff_id = effect.get("buff_id", effect.get("buff_type", ""))
	var stacks = effect.get("stacks", effect.get("value", 1))
	if buff_id.is_empty(): return {"success": false, "value": 0}
	var buff_data = _create_buff_from_id(buff_id, stacks)
	if buff_data == null: return {"success": false, "value": 0}
	if target is PlayerManager: target.apply_buff(buff_data); buff_applied.emit(target, buff_data)
	elif target is EnemyUnit: target.apply_buff(buff_data); buff_applied.emit(target, buff_data)
	return {"success": true, "value": stacks, "buff": buff_data}

func _resolve_add_card(effect: Dictionary, source) -> Dictionary:
	var card = card_database.get_card(effect.get("card_id", ""))
	if card == null: return {"success": false, "value": 0}
	if source.has_method("get") and source.get("card_system"): source.card_system.add_to_hand(card.duplicate()); return {"success": true, "value": 1}
	return {"success": false, "value": 0}

func _resolve_search_draw_by_tag(effect: Dictionary, source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"):
		var card = source.card_system.search_and_draw_by_tag(effect.get("target_tag", ""))
		return {"success": card != null, "value": 1}
	return {"success": false, "value": 0}

func _resolve_search_discard_by_tag(effect: Dictionary, source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"):
		var card = source.card_system.search_discard_and_draw_by_tag(effect.get("target_tag", ""))
		return {"success": card != null, "value": 1}
	return {"success": false, "value": 0}

func _resolve_exhaust_random(count: int, source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"):
		var cs = source.card_system; var exhausted = 0
		for i in count: if cs.exhaust_random_hand_card(): exhausted += 1
		return {"success": exhausted > 0, "value": exhausted}
	return {"success": false, "value": 0}

func _resolve_discard_random(count: int, source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"):
		var cs = source.card_system; var discarded = 0
		for i in count: if cs.discard_random_hand_card(): discarded += 1
		return {"success": discarded > 0, "value": discarded}
	return {"success": false, "value": 0}

func clear_temp_hooks(source) -> void:
	if source and source.hook_chain:
		for hook_id in _temp_hook_ids: source.hook_chain.unregister("calc_attack_base", hook_id)
	_temp_hook_ids.clear()
	_temp_attack_boost = 0

func clear_all_temp_hooks(source) -> void:
	clear_temp_hooks(source)

func _resolve_shuffle_discard_to_draw(source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"): source.card_system.manual_shuffle_discard_to_draw(); return {"success": true, "value": 1}
	return {"success": false, "value": 0}

func _create_buff_from_id(buff_id: String, stacks: int = 1) -> BuffData:
	var configs = {
		"strength": {"id": "strength", "name": "力量", "buff_type": "buff", "duration": -1, "stacks": stacks},
		"dexterity": {"id": "dexterity", "name": "敏捷", "buff_type": "buff", "duration": -1, "stacks": stacks},
		"weak": {"id": "weak", "name": "虚弱", "buff_type": "debuff", "duration": 2, "stacks": stacks, "modifiers": {"damage_mult": 0.75}},
		"vulnerable": {"id": "vulnerable", "name": "易伤", "buff_type": "debuff", "duration": 2, "stacks": stacks, "modifiers": {"damage_taken_mult": 1.5}},
		"poison": {"id": "poison", "name": "中毒", "buff_type": "debuff", "duration": -1, "stacks": stacks, "trigger_timing": "on_turn_end", "tick_effect": {"type": "damage", "value": 1}},
		"regen": {"id": "regen", "name": "再生", "buff_type": "buff", "duration": -1, "stacks": stacks, "trigger_timing": "on_turn_start", "tick_effect": {"type": "heal", "value": 1}},
	}
	if configs.has(buff_id): return BuffData.new(configs[buff_id].duplicate(true))
	return null