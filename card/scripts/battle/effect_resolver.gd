class_name EffectResolver

enum EffectType {
	DAMAGE,
	BLOCK,
	HEAL,
	DRAW,
	SEARCH_DRAW_PILE,
	SEARCH_DISCARD_PILE,
	APPLY_BUFF,
	APPLY_DEBUFF,
	ADD_CARD_TO_HAND,
	DISCARD_HAND,
	EXHAUST_CARD,
	GAIN_ENERGY,
	LOSE_HP
}

var card_database: CardDatabase
var buff_database

signal effect_resolved(effect_type: int, result: Dictionary)
signal damage_dealt(target, amount: int)
signal block_gained(target, amount: int)
signal healing_done(target, amount: int)
signal cards_drawn(count: int)
signal buff_applied(target, buff: BuffData)

func _init():
	card_database = CardDatabase.new()

func resolve_effects(effects: Array, source, target = null) -> Dictionary:
	var results: Dictionary = {}
	
	for effect in effects:
		var result = resolve_effect(effect, source, target)
		results[effect.get("effect_type", "unknown")] = result
	
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
			stat_value = source.strength
		elif base_stat == "dexterity":
			stat_value = source.dexterity
		value = int(stat_value * multiplier)
	
	match effect_type_str:
		"damage":
			result = _resolve_damage(value, source, target)
		"block":
			result = _resolve_block(value, source, target)
		"heal":
			result = _resolve_heal(value, source, target)
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
		"apply_buff":
			result = _resolve_apply_buff(effect, target)
		"apply_debuff":
			result = _resolve_apply_debuff(effect, target)
		"add_card_to_hand":
			result = _resolve_add_card(effect, source)
	
	effect_resolved.emit(effect_type_str, result)
	return result

func _resolve_damage(base_damage: int, source, target) -> Dictionary:
	if target == null:
		return {"success": false, "value": 0}
	
	var damage_mult: float = 1.0
	if source is PlayerManager:
		damage_mult = source.buff_manager.get_modifier("damage")
	elif source.has_method("get") and source.get("buff_manager"):
		damage_mult = source.buff_manager.get_modifier("damage")
	
	var final_damage = int(base_damage * damage_mult)
	
	if target is PlayerManager:
		var actual = target.take_damage(final_damage)
		damage_dealt.emit(target, actual)
		return {"success": true, "value": actual, "target": target}
	elif target is EnemyUnit:
		var actual = target.take_damage(final_damage)
		damage_dealt.emit(target, actual)
		return {"success": true, "value": actual, "target": target}
	
	return {"success": false, "value": 0}

func _resolve_block(base_block: int, source, target) -> Dictionary:
	var block_mult: float = 1.0
	if source is PlayerManager:
		block_mult = source.buff_manager.get_modifier("block")
	elif source.has_method("get") and source.get("buff_manager"):
		block_mult = source.buff_manager.get_modifier("block")
	
	var final_block = int(base_block * block_mult)
	
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
		heal_mult = target.buff_manager.get_modifier("heal")
	
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

func _resolve_draw(count: int, source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"):
		var card_system = source.card_system
		var drawn = card_system.draw_cards(count)
		cards_drawn.emit(drawn.size())
		return {"success": true, "value": drawn.size(), "cards": drawn}
	return {"success": false, "value": 0}

func _resolve_search_draw(effect: Dictionary, source) -> Dictionary:
	var card_id = effect.get("card_id", "")
	var card_system = null
	
	if source.has_method("get") and source.get("card_system"):
		card_system = source.card_system
	
	if card_system:
		var card = card_system.search_and_draw(card_id)
		if card:
			return {"success": true, "value": 1, "card": card}
	
	return {"success": false, "value": 0}

func _resolve_search_discard(effect: Dictionary, source) -> Dictionary:
	var card_id = effect.get("card_id", "")
	var card_system = null
	
	if source.has_method("get") and source.get("card_system"):
		card_system = source.card_system
	
	if card_system:
		var card = card_system.search_discard_and_draw(card_id)
		if card:
			return {"success": true, "value": 1, "card": card}
	
	return {"success": false, "value": 0}

func _resolve_apply_buff(effect: Dictionary, target) -> Dictionary:
	var buff_id = effect.get("buff_id", "")
	var stacks = effect.get("value", 1)
	
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

func _resolve_apply_debuff(effect: Dictionary, target) -> Dictionary:
	return _resolve_apply_buff(effect, target)

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
			"stacks": stacks,
			"modifiers": {"damage_mult": 1.0 + 0.25 * stacks}
		},
		"dexterity": {
			"id": "dexterity",
			"name": "敏捷",
			"buff_type": "buff",
			"duration": -1,
			"stacks": stacks,
			"modifiers": {"block_mult": 1.0 + 0.25 * stacks}
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
