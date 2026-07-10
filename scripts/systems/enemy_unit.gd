class_name EnemyUnit

var data: EnemyData
var current_hp: int
var max_hp: int
var block: int = 0
var buff_manager: BuffManager
var hook_chain: HookChain
var is_dead: bool = false
var current_intent: Dictionary = {}

signal hp_changed(current: int, maximum: int)
signal block_changed(amount: int)
signal enemy_died()
signal enemy_damaged(amount: int)
signal intent_changed(intent: Dictionary)

func _init(enemy_data: EnemyData):
	data = enemy_data
	max_hp = enemy_data.max_hp
	current_hp = max_hp
	hook_chain = HookChain.new()
	buff_manager = BuffManager.new(hook_chain)

func take_damage(amount: int, ignore_target_block: bool = false) -> int:
	if amount <= 0 or is_dead:
		return 0
	
	var damage_mult = buff_manager.get_mult("damage_taken")
	var actual_damage = int(amount * damage_mult)
	
	if not ignore_target_block and block > 0:
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
	enemy_damaged.emit(actual_damage)
	
	if current_hp <= 0:
		is_dead = true
		clear_intent()
		enemy_died.emit()
	
	return actual_damage

func gain_block(amount: int) -> void:
	if amount <= 0:
		return
	block += amount
	block_changed.emit(block)

func heal(amount: int) -> int:
	if amount <= 0:
		return 0
	var old_hp = current_hp
	current_hp = mini(current_hp + amount, max_hp)
	var healed = current_hp - old_hp
	if healed > 0:
		hp_changed.emit(current_hp, max_hp)
	return healed

func reset_block() -> void:
	block = 0
	block_changed.emit(block)

func set_intent(intent: Dictionary) -> void:
	current_intent = intent
	intent_changed.emit(intent)

func clear_intent() -> void:
	current_intent = {}
	intent_changed.emit({})

func decide_next_intent() -> void:
	if data.actions.is_empty():
		clear_intent()
		return
	
	var action = data.actions.pick_random()
	set_intent(action)

func is_alive() -> bool:
	return not is_dead and current_hp > 0

func get_name() -> String:
	return data.name

func apply_buff(buff: BuffData) -> void:
	buff_manager.apply_buff(buff)
