class_name EffectResolver

var card_database: CardDatabase
var buff_database
var card_system: CardSystem = null

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
	
	for i in effects.size():
		var result = resolve_effect(effects[i], source, target)
		results.append(result)
	
	return results

func resolve_effect(effect: Dictionary, source, target = null) -> Dictionary:
	var effect_type_str = effect.get("effect_type", "")
	var value = effect.get("value", 0)
	var result: Dictionary = {"success": false, "value": 0}
	
	var base_stat = effect.get("base_stat", "")
	var multiplier = effect.get("multiplier", 1.0)
	
	if base_stat != "" and source is PlayerManager:
		var stat_value = 0
		if base_stat == "strength":
			stat_value = source.get_strength()
		elif base_stat == "dexterity":
			stat_value = source.get_dexterity()
		value = value + int(stat_value * multiplier)
	
	match effect_type_str:
		"damage":
			result = _resolve_damage(value, source, target)
		"block":
			result = _resolve_block(value, source, target)
		"heal":
			result = _resolve_heal(value, source, target)
		"damage_boost":
			result = _resolve_damage_boost(value, source)
		"temp_damage_boost":
			result = _resolve_temp_damage_boost(value, source)
		"skip_attack":
			result = _resolve_skip_attack(value, source)
		"store_damage":
			result = _resolve_store_damage(source)
		"ignore_block":
			result = _resolve_ignore_block(source)
		"counter_stance":
			result = _resolve_counter_stance(source)
		"draw":
			result = _resolve_draw(value, source)
		"search_draw":
			result = _resolve_search_draw(effect, source)
		"search_discard":
			result = _resolve_search_discard(effect, source)
		"search_draw_by_tag":
			result = _resolve_search_draw_by_tag(effect, source)
		"search_discard_by_tag":
			result = _resolve_search_discard_by_tag(effect, source)
		"exhaust_random":
			result = _resolve_exhaust_random(value, source)
		"discard_random":
			result = _resolve_discard_random(value, source)
		"shuffle_discard_to_draw":
			result = _resolve_shuffle_discard_to_draw(source)
		"apply_buff", "apply_debuff":
			result = _resolve_apply_buff(effect, target)
		"add_card_to_hand":
			result = _resolve_add_card(effect, source)
	
	effect_resolved.emit(effect_type_str, result)
	return result

func _resolve_damage(base_damage: int, source, target) -> Dictionary:
	if target == null:
		return {"success": false, "value": 0}
	
	var total_damage = base_damage
	if source is PlayerManager:
		var strength_buff = source.buff_manager.get_buff_by_id("strength")
		if strength_buff:
			total_damage += strength_buff.stacks
		var temp_buff = source.buff_manager.get_buff_by_id("temp_strength")
		if temp_buff:
			total_damage += temp_buff.stacks
	
	var damage_mult: float = 1.0
	if source is PlayerManager:
		damage_mult = source.buff_manager.get_mult("damage")
		total_damage = int(source.hook_chain.trigger("calc_attack_damage", total_damage))
	elif source.has_method("get") and source.get("buff_manager"):
		total_damage += int(source.buff_manager.get_flat_add("damage"))
		damage_mult = source.buff_manager.get_mult("damage")
	
	var final_damage = int(total_damage * damage_mult)
	
	var should_ignore_block = false
	if source is PlayerManager:
		should_ignore_block = source.buff_manager.has_buff("ignore_block")
	
	if target is PlayerManager:
		var actual = target.take_damage(final_damage)
		damage_dealt.emit(target, actual)
		return {"success": true, "value": actual, "target": target}
	elif target is EnemyUnit:
		var actual = target.take_damage(final_damage, should_ignore_block)
		damage_dealt.emit(target, actual)
		return {"success": true, "value": actual, "target": target}
	
	return {"success": false, "value": 0}

func _resolve_block(base_block: int, source, target) -> Dictionary:
	var block_mult: float = 1.0
	if target is PlayerManager:
		block_mult = target.buff_manager.get_mult("block")
	elif target is EnemyUnit:
		block_mult = target.buff_manager.get_mult("block")
	
	var final_block = int(base_block * block_mult)
	if final_block <= 0:
		return {"success": false, "value": 0}
	
	if target is PlayerManager:
		target.gain_block(final_block)
		block_gained.emit(target, final_block)
		return {"success": true, "value": final_block, "target": target}
	elif target is EnemyUnit:
		target.gain_block(final_block)
		block_gained.emit(target, final_block)
		return {"success": true, "value": final_block, "target": target}
	
	return {"success": false, "value": 0}

func _resolve_heal(base_heal: int, source, target) -> Dictionary:
	var heal_mult: float = 1.0
	if target is PlayerManager:
		heal_mult = target.buff_manager.get_mult("heal")
	
	var final_heal = int(base_heal * heal_mult)
	
	if target is PlayerManager:
		var actual = target.heal(final_heal)
		healing_done.emit(target, actual)
		return {"success": true, "value": actual, "target": target}
	elif target is EnemyUnit:
		var actual = target.heal(final_heal)
		healing_done.emit(target, actual)
		return {"success": true, "value": actual, "target": target}
	
	return {"success": false, "value": 0}

func _resolve_damage_boost(value: int, source) -> Dictionary:
	if source is PlayerManager:
		var buff = BuffData.new({
			"id": "strength",
			"name": "力量",
			"buff_type": "buff",
			"duration": -1,
			"stacks": value
		})
		source.buff_manager.apply_buff(buff)
		return {"success": true, "value": value, "new_strength": source.get_strength()}
	return {"success": false, "value": 0}

func _resolve_temp_damage_boost(value: int, source) -> Dictionary:
	if source is PlayerManager:
		var buff = BuffData.new({
			"id": "temp_strength",
			"name": "临时力量",
			"buff_type": "buff",
			"duration": 1,
			"stacks": value,
			"trigger_timing": "on_turn_end_remove"
		})
		source.buff_manager.apply_buff(buff)
		return {"success": true, "value": value}
	return {"success": false, "value": 0}

func _resolve_skip_attack(_value: int, source) -> Dictionary:
	if source is PlayerManager:
		var buff = BuffData.new({
			"id": "skip_attack",
			"name": "蓄势",
			"buff_type": "buff",
			"duration": 1,
			"stacks": 1,
			"trigger_timing": "on_turn_end_remove"
		})
		source.buff_manager.apply_buff(buff)
		return {"success": true, "value": 1}
	return {"success": false, "value": 0}

func _resolve_store_damage(source) -> Dictionary:
	if source is PlayerManager:
		var current = source.get_strength()
		var temp_buff = source.buff_manager.get_buff_by_id("temp_strength")
		if temp_buff:
			current += temp_buff.stacks
			source.buff_manager.remove_buff("temp_strength")
		var stored_buff = source.buff_manager.get_buff_by_id("stored_power")
		if stored_buff:
			stored_buff.add_stacks(current)
			source.buff_manager.recalculate_modifiers(stored_buff)
		else:
			var new_buff = BuffData.new({
				"id": "stored_power",
				"name": "蓄力",
				"buff_type": "buff",
				"duration": -1,
				"stacks": current
			})
			source.buff_manager.apply_buff(new_buff)
		return {"success": true, "value": current, "stored_total": source.get_stored_power()}
	return {"success": false, "value": 0}

func _resolve_ignore_block(source) -> Dictionary:
	if source is PlayerManager:
		var buff = BuffData.new({
			"id": "ignore_block",
			"name": "破甲",
			"buff_type": "buff",
			"duration": 1,
			"stacks": 1,
			"trigger_timing": "on_turn_end_remove"
		})
		source.buff_manager.apply_buff(buff)
		return {"success": true, "value": 1}
	return {"success": false, "value": 0}

func _resolve_counter_stance(source) -> Dictionary:
	if source is PlayerManager:
		var buff = BuffData.new({
			"id": "counter_stance",
			"name": "招架",
			"buff_type": "buff",
			"duration": 1,
			"stacks": 1,
			"trigger_timing": "on_turn_end_remove"
		})
		source.buff_manager.apply_buff(buff)
		return {"success": true, "value": 1}
	return {"success": false, "value": 0}

func _resolve_draw(count: int, source) -> Dictionary:
	if card_system:
		var drawn = card_system.draw_cards(count)
		cards_drawn.emit(drawn.size())
		return {"success": true, "value": drawn.size(), "cards": drawn}
	elif source.has_method("get") and source.get("card_system"):
		var cs = source.card_system
		var drawn = cs.draw_cards(count)
		cards_drawn.emit(drawn.size())
		return {"success": true, "value": drawn.size(), "cards": drawn}
	return {"success": false, "value": 0}

func _resolve_search_draw(effect: Dictionary, source) -> Dictionary:
	var card_id = effect.get("card_id", "")
	var cs = card_system
	if not cs and source.has_method("get") and source.get("card_system"):
		cs = source.card_system
	
	if cs:
		var card = cs.search_and_draw(card_id)
		if card:
			return {"success": true, "value": 1, "card": card}
	
	return {"success": false, "value": 0}

func _resolve_search_discard(effect: Dictionary, source) -> Dictionary:
	var card_id = effect.get("card_id", "")
	var cs = card_system
	if not cs and source.has_method("get") and source.get("card_system"):
		cs = source.card_system
	
	if cs:
		var card = cs.search_discard_and_draw(card_id)
		if card:
			return {"success": true, "value": 1, "card": card}
	
	return {"success": false, "value": 0}

func _resolve_apply_buff(effect: Dictionary, target) -> Dictionary:
	var buff_id = effect.get("buff_id", "")
	if buff_id.is_empty():
		buff_id = effect.get("buff_type", "")
	var stacks = effect.get("value", 1)
	if effect.has("stacks"):
		stacks = effect.stacks
	
	if buff_id.is_empty():
		return {"success": false, "value": 0}
	
	var buff_data = _create_buff_from_id(buff_id, stacks)
	if buff_data == null:
		return {"success": false, "value": 0}
	
	if target is PlayerManager:
		target.apply_buff(buff_data)
		buff_applied.emit(target, buff_data)
		return {"success": true, "value": stacks, "buff": buff_data}
	elif target is EnemyUnit:
		target.apply_buff(buff_data)
		buff_applied.emit(target, buff_data)
		return {"success": true, "value": stacks, "buff": buff_data}
	
	return {"success": false, "value": 0}

func _resolve_add_card(effect: Dictionary, source) -> Dictionary:
	var card_id = effect.get("card_id", "")
	if card_id.is_empty():
		return {"success": false, "value": 0}
	
	var card = card_database.get_card(card_id)
	if card == null:
		return {"success": false, "value": 0}
	
	if source.has_method("get") and source.get("card_system"):
		var card_system = source.card_system
		card_system.add_to_hand(card.duplicate())
		return {"success": true, "value": 1, "card": card}
	
	return {"success": false, "value": 0}

func _resolve_search_draw_by_tag(effect: Dictionary, source) -> Dictionary:
	var tag = effect.get("target_tag", "")
	if tag.is_empty():
		return {"success": false, "value": 0}
	
	if source.has_method("get") and source.get("card_system"):
		var card_system = source.card_system
		var card = card_system.search_and_draw_by_tag(tag)
		if card:
			return {"success": true, "value": 1, "card": card}
	
	return {"success": false, "value": 0}

func _resolve_search_discard_by_tag(effect: Dictionary, source) -> Dictionary:
	var tag = effect.get("target_tag", "")
	if tag.is_empty():
		return {"success": false, "value": 0}
	
	if source.has_method("get") and source.get("card_system"):
		var card_system = source.card_system
		var card = card_system.search_discard_and_draw_by_tag(tag)
		if card:
			return {"success": true, "value": 1, "card": card}
	
	return {"success": false, "value": 0}

func _resolve_exhaust_random(count: int, source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"):
		var card_system = source.card_system
		var exhausted_count = 0
		for i in count:
			var card = card_system.exhaust_random_hand_card()
			if card:
				exhausted_count += 1
		return {"success": exhausted_count > 0, "value": exhausted_count}
	return {"success": false, "value": 0}

func _resolve_discard_random(count: int, source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"):
		var card_system = source.card_system
		var discarded_count = 0
		for i in count:
			var card = card_system.discard_random_hand_card()
			if card:
				discarded_count += 1
		return {"success": discarded_count > 0, "value": discarded_count}
	return {"success": false, "value": 0}

func _resolve_shuffle_discard_to_draw(source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"):
		var card_system = source.card_system
		card_system.manual_shuffle_discard_to_draw()
		return {"success": true, "value": 1}
	return {"success": false, "value": 0}

func _create_buff_from_id(buff_id: String, stacks: int = 1) -> BuffData:
	var buff_configs: Dictionary = {
		"strength": {
			"id": "strength",
			"name": "力量",
			"buff_type": "buff",
			"duration": -1,
			"stacks": stacks
		},
		"dexterity": {
			"id": "dexterity",
			"name": "敏捷",
			"buff_type": "buff",
			"duration": -1,
			"stacks": stacks
		},
		"weak": {
			"id": "weak",
			"name": "虚弱",
			"buff_type": "debuff",
			"duration": 2,
			"stacks": stacks,
			"modifiers": {"damage_mult": 0.75}
		},
		"vulnerable": {
			"id": "vulnerable",
			"name": "易伤",
			"buff_type": "debuff",
			"duration": 2,
			"stacks": stacks,
			"modifiers": {"damage_taken_mult": 1.5}
		},
		"poison": {
			"id": "poison",
			"name": "中毒",
			"buff_type": "debuff",
			"duration": -1,
			"stacks": stacks,
			"trigger_timing": "on_turn_end",
			"tick_effect": {"type": "damage", "value": 1}
		},
		"regen": {
			"id": "regen",
			"name": "再生",
			"buff_type": "buff",
			"duration": -1,
			"stacks": stacks,
			"trigger_timing": "on_turn_start",
			"tick_effect": {"type": "heal", "value": 1}
		}
	}
	
	if buff_configs.has(buff_id):
		var config = buff_configs[buff_id].duplicate(true)
		config.stacks = stacks
		return BuffData.new(config)
	
	return null
