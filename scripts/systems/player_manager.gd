class_name PlayerManager

var current_hp: int
var max_hp: int
var block: int = 0
var base_strength: int = 0
var base_dexterity: int = 0
var pending_stored_damage: int = 0
var buff_manager: BuffManager
var hook_chain: HookChain
var selected_target_index: int = 0
var is_dead: bool = false
var selected_target: EnemyUnit = null

signal hp_changed(current: int, maximum: int)
signal block_changed(amount: int)
signal player_died()
signal player_damaged(amount: int)
signal player_healed(amount: int)
signal target_selected(index: int)
signal counter_damage(amount: int)

func _init(initial_max_hp: int = 80):
	max_hp = initial_max_hp
	current_hp = max_hp
	hook_chain = HookChain.new()
	buff_manager = BuffManager.new(hook_chain)

func get_strength() -> int:
	var buff = buff_manager.get_buff_by_id("strength")
	return base_strength + (buff.stacks if buff else 0)

func get_dexterity() -> int:
	var buff = buff_manager.get_buff_by_id("dexterity")
	return base_dexterity + (buff.stacks if buff else 0)

func get_stored_power() -> int:
	return pending_stored_damage

func get_total_damage() -> int:
	return base_strength + int(buff_manager.get_flat_add("damage"))

func get_expected_attack_damage() -> int:
	var v = hook_chain.trigger("calc_attack_base", base_strength, {})
	v = hook_chain.trigger("calc_attack_mult", int(v), {})
	v = hook_chain.trigger("calc_attack_damage", v, {})
	v = hook_chain.trigger("calc_attack_final", v, {})
	return int(v)

func get_total_block() -> int:
	return base_dexterity + int(buff_manager.get_flat_add("block"))

func set_selected_target(index: int) -> void:
	selected_target_index = index
	target_selected.emit(index)

func take_damage(amount: int) -> int:
	if is_dead or amount <= 0: return 0
	var actual_damage = int(hook_chain.trigger("on_damage_taken", amount, {"source_type": "enemy"}))
	if block > 0:
		if block >= actual_damage:
			var blocked = actual_damage; block -= actual_damage; block_changed.emit(block)
			if buff_manager.has_buff("counter_stance"): counter_damage.emit(blocked)
			return 0
		else:
			actual_damage -= block; block = 0; block_changed.emit(block)
	current_hp = maxi(current_hp - actual_damage, 0)
	hp_changed.emit(current_hp, max_hp); player_damaged.emit(actual_damage)
	if current_hp <= 0: is_dead = true; player_died.emit()
	return actual_damage

func gain_block(amount: int) -> void:
	if amount <= 0: return
	block += amount; block_changed.emit(block)

func heal(amount: int) -> int:
	if amount <= 0: return 0
	var heal_mult = buff_manager.get_mult("heal")
	var actual_heal = int(amount * heal_mult)
	var old_hp = current_hp
	current_hp = mini(current_hp + actual_heal, max_hp)
	var healed = current_hp - old_hp
	if healed > 0: hp_changed.emit(current_hp, max_hp); player_healed.emit(healed)
	return healed

func reset_block() -> void: block = 0; block_changed.emit(block)

func set_max_hp(value: int) -> void: max_hp = value; current_hp = mini(current_hp, max_hp); hp_changed.emit(current_hp, max_hp)

func is_alive() -> bool: return not is_dead and current_hp > 0

func get_hp_percent() -> float: return float(current_hp) / float(max_hp)

func apply_buff(buff: BuffData) -> void: buff_manager.apply_buff(buff)