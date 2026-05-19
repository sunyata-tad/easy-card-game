class_name PlayerManager

var current_hp: int
var max_hp: int
var block: int = 0
var buff_manager: BuffManager
var strength: int = 0
var dexterity: int = 0
var temp_damage_bonus: int = 0
var selected_target_index: int = 0

signal hp_changed(current: int, maximum: int)
signal block_changed(amount: int)
signal player_died()
signal player_damaged(amount: int)
signal player_healed(amount: int)
signal target_selected(index: int)

func _init(initial_max_hp: int = 80):
	max_hp = initial_max_hp
	current_hp = max_hp
	buff_manager = BuffManager.new()
	_connect_buff_signals()

func _connect_buff_signals() -> void:
	pass

func get_total_damage() -> int:
	return strength + temp_damage_bonus

func add_temp_damage_bonus(amount: int) -> void:
	temp_damage_bonus += amount

func reset_temp_damage_bonus() -> void:
	temp_damage_bonus = 0

func set_selected_target(index: int) -> void:
	selected_target_index = index
	target_selected.emit(index)

func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	
	var damage_mult = buff_manager.get_modifier("damage_taken")
	var actual_damage = int(amount * damage_mult)
	
	if block > 0:
		if block >= actual_damage:
			block -= actual_damage
			block_changed.emit(block)
			return 0
		else:
			actual_damage -= block
			block = 0
			block_changed.emit(block)
	
	current_hp = maxi(current_hp - actual_damage, 0)
	hp_changed.emit(current_hp, max_hp)
	player_damaged.emit(actual_damage)
	
	if current_hp <= 0:
		player_died.emit()
	
	return actual_damage

func gain_block(amount: int) -> void:
	if amount <= 0:
		return
	
	var block_mult = buff_manager.get_modifier("block")
	var actual_block = int(amount * block_mult)
	block += actual_block
	block_changed.emit(block)

func heal(amount: int) -> int:
	if amount <= 0:
		return 0
	
	var heal_mult = buff_manager.get_modifier("heal")
	var actual_heal = int(amount * heal_mult)
	var old_hp = current_hp
	current_hp = mini(current_hp + actual_heal, max_hp)
	var healed = current_hp - old_hp
	
	if healed > 0:
		hp_changed.emit(current_hp, max_hp)
		player_healed.emit(healed)
	
	return healed

func reset_block() -> void:
	block = 0
	block_changed.emit(block)

func set_max_hp(value: int) -> void:
	max_hp = value
	current_hp = mini(current_hp, max_hp)
	hp_changed.emit(current_hp, max_hp)

func is_alive() -> bool:
	return current_hp > 0

func get_hp_percent() -> float:
	return float(current_hp) / float(max_hp)

func apply_buff(buff: BuffData) -> void:
	buff_manager.apply_buff(buff)
