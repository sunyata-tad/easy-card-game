class_name BattleController

var state_machine: StateMachine
var turn_manager: TurnManager
var card_system: CardSystem
var enemy_system: EnemySystem
var player_manager: PlayerManager
var effect_resolver: EffectResolver
var ui_controller: UIController

var card_database: CardDatabase
var enemy_database: EnemyDatabase

var pending_card: CardData = null
var pending_card_node: Control = null
var is_first_turn: bool = true
var is_discard_phase: bool = false

signal battle_started()
signal battle_ended(victory: bool)
signal turn_changed(is_player_turn: bool)
signal discard_phase_started(cards_to_discard: int)
signal discard_phase_ended()

func _init():
	_initialize_systems()
	_connect_signals()

func _initialize_systems() -> void:
	state_machine = StateMachine.new()
	turn_manager = TurnManager.new()
	card_system = CardSystem.new()
	enemy_system = EnemySystem.new()
	player_manager = PlayerManager.new(80)
	effect_resolver = EffectResolver.new()
	card_database = CardDatabase.new()
	enemy_database = EnemyDatabase.new()

func _connect_signals() -> void:
	state_machine.state_enter.connect(_on_state_enter)
	
	turn_manager.player_turn_start.connect(_on_player_turn_start)
	
	card_system.card_played.connect(_on_card_played)
	card_system.hand_changed.connect(_on_hand_changed)
	card_system.deck_count_changed.connect(_on_deck_count_changed)
	
	enemy_system.enemy_died.connect(_on_enemy_died)
	enemy_system.enemy_damaged.connect(_on_enemy_damaged)
	enemy_system.all_enemies_defeated.connect(_on_all_enemies_defeated)
	
	player_manager.hp_changed.connect(_on_player_hp_changed)
	player_manager.block_changed.connect(_on_player_block_changed)
	player_manager.player_died.connect(_on_player_died)
	player_manager.counter_damage.connect(_on_counter_damage)

func setup_battle(root_node: Control, initial_deck: Array = [], enemies: Array = []) -> void:
	ui_controller = UIController.new(root_node)
	ui_controller.player_manager = player_manager
	_connect_ui_signals()
	
	if initial_deck.is_empty():
		initial_deck = card_database.load_starter_deck()
	
	card_system.initialize_deck(initial_deck)
	effect_resolver.card_system = card_system
	
	var max_hp = GameData.player_max_hp
	var current_hp = GameData.player_current_hp
	var strength = GameData.player_strength
	var dexterity = GameData.player_dexterity
	
	player_manager.max_hp = max_hp
	player_manager.current_hp = current_hp
	
	if strength != 0:
		var str_buff = BuffData.new({
			"id": "strength",
			"name": "力量",
			"buff_type": "buff",
			"duration": -1,
			"stacks": strength
		})
		player_manager.buff_manager.apply_buff(str_buff)
	
	if dexterity != 0:
		var dex_buff = BuffData.new({
			"id": "dexterity",
			"name": "敏捷",
			"buff_type": "buff",
			"duration": -1,
			"stacks": dexterity
		})
		player_manager.buff_manager.apply_buff(dex_buff)
	
	for enemy_data in enemies:
		enemy_system.add_enemy(enemy_data)
	
	if enemies.is_empty():
		var test_enemy = enemy_database.get_enemy("test_dummy")
		if test_enemy:
			enemy_system.add_enemy(test_enemy)

func start_battle() -> void:
	_update_initial_ui()
	battle_started.emit()
	_on_battle_init()
	state_machine.change_state(StateMachine.BattleState.DRAW_PHASE)

func _connect_ui_signals() -> void:
	ui_controller.card_clicked.connect(_on_ui_card_clicked)
	ui_controller.card_released.connect(_on_ui_card_released)
	ui_controller.card_cancelled.connect(_on_ui_card_cancelled)
	ui_controller.card_dropped.connect(_on_ui_card_dropped)
	ui_controller.card_played.connect(_on_ui_card_played)
	ui_controller.enemy_selected.connect(_on_ui_enemy_selected)
	ui_controller.end_turn_clicked.connect(_on_ui_end_turn_clicked)

func _check_battle_end_state() -> bool:
	if not state_machine.is_battle_active():
		return true
	if enemy_system.is_all_defeated():
		state_machine.change_state(StateMachine.BattleState.VICTORY)
		return true
	elif not player_manager.is_alive():
		state_machine.change_state(StateMachine.BattleState.DEFEAT)
		return true
	return false

func _on_state_enter(state: int) -> void:
	match state:
		StateMachine.BattleState.INIT:
			_on_battle_init()
		StateMachine.BattleState.DRAW_PHASE:
			_on_draw_phase()
		StateMachine.BattleState.PLAYER_TURN:
			_on_player_turn_phase()
		StateMachine.BattleState.RESOLVING:
			_on_resolving_phase()
		StateMachine.BattleState.ENEMY_TURN:
			_on_enemy_turn_phase()
		StateMachine.BattleState.TURN_END:
			_on_turn_end_phase()
		StateMachine.BattleState.VICTORY:
			_on_victory()
		StateMachine.BattleState.DEFEAT:
			_on_defeat()

func _on_battle_init() -> void:
	turn_manager.reset()
	is_first_turn = true
	is_discard_phase = false
	ui_controller.show_turn_banner("战斗开始!")

func _on_draw_phase() -> void:
	player_manager.reset_block()
	enemy_system.reset_all_block()
	player_manager.buff_manager.remove_at_turn_end()
	
	var draw_count = 5 if is_first_turn else 1
	is_first_turn = false
	
	card_system.draw_cards(draw_count)
	turn_changed.emit(true)
	_decide_all_enemy_intents()
	
	if not _check_battle_end_state():
		turn_manager.start_new_turn(true)
		state_machine.change_state(StateMachine.BattleState.PLAYER_TURN)

func _on_player_turn_phase() -> void:
	ui_controller.set_interactive(true)
	ui_controller.show_turn_banner("你的回合")

func _on_resolving_phase() -> void:
	ui_controller.set_interactive(false)

func _on_enemy_turn_phase() -> void:
	ui_controller.set_interactive(false)
	ui_controller.show_turn_banner("敌人回合")
	turn_manager.start_new_turn(false)
	turn_changed.emit(false)
	await _execute_enemy_turns()

func _on_turn_end_phase() -> void:
	var excess = card_system.hand.size() - CardSystem.MAX_HAND_SIZE
	if excess > 0:
		is_discard_phase = true
		ui_controller.set_interactive(false)
		discard_phase_started.emit(excess)
	else:
		await _resolve_end_turn()

func _resolve_end_turn() -> void:
	is_discard_phase = false
	discard_phase_ended.emit()
	await _process_turn_end_effects()
	turn_manager.end_current_turn()
	
	if not state_machine.is_battle_active():
		return
	
	if _check_battle_end_state():
		return
	
	state_machine.change_state(StateMachine.BattleState.DRAW_PHASE)

func confirm_discard_cards(cards_to_discard: Array) -> void:
	if not is_discard_phase:
		return
	
	for card in cards_to_discard:
		card_system.discard_specific_card(card)
	
	is_discard_phase = false
	discard_phase_ended.emit()
	
	var excess = card_system.hand.size() - CardSystem.MAX_HAND_SIZE
	if excess > 0:
		is_discard_phase = true
		ui_controller.set_interactive(false)
		discard_phase_started.emit(excess)
		return
	
	await _resolve_end_turn()

func _on_victory() -> void:
	sync_player_stats_to_gamedata()
	battle_ended.emit(true)

func _on_defeat() -> void:
	sync_player_stats_to_gamedata()
	battle_ended.emit(false)

func sync_player_stats_to_gamedata() -> void:
	if GameData:
		GameData.player_current_hp = player_manager.current_hp
		GameData.player_max_hp = player_manager.max_hp
		GameData.player_strength = player_manager.get_strength()
		GameData.player_dexterity = player_manager.get_dexterity()

func _process_turn_end_effects() -> void:
	_tick_buffs_on_turn_end(player_manager)
	for enemy in enemy_system.get_alive_enemies():
		_tick_buffs_on_turn_end(enemy)
	
	await _execute_player_auto_attack()
	
	if _check_battle_end_state():
		return
	
	await _execute_enemy_attacks()
	
	if _check_battle_end_state():
		return
	
	player_manager.buff_manager.decrease_durations()
	player_manager.buff_manager.remove_at_turn_end()
	for enemy in enemy_system.get_alive_enemies():
		enemy.buff_manager.decrease_durations()
		enemy.buff_manager.remove_at_turn_end()

func _execute_enemy_attacks() -> void:
	var alive_enemies = enemy_system.get_alive_enemies()
	
	for enemy in alive_enemies:
		_execute_single_enemy_turn(enemy)
		if not player_manager.is_alive():
			break
		await get_tree().create_timer(0.3).timeout

func _execute_player_auto_attack() -> void:
	var total_block = player_manager.get_total_block()
	
	if total_block > 0:
		player_manager.gain_block(total_block)
		_update_player_ui()
		await get_tree().create_timer(0.2).timeout
	
	if player_manager.buff_manager.has_buff("skip_attack"):
		ui_controller.show_state_message("蓄力中...伤害叠加至下回合", 1.2)
		await get_tree().create_timer(0.2).timeout
		return
	
	var total_damage = player_manager.get_total_damage()
	
	if total_damage > 0:
		total_damage = int(player_manager.hook_chain.trigger("calc_attack_damage", total_damage))
		
		var alive_enemies = enemy_system.get_alive_enemies()
		var target_enemy = player_manager.selected_target
		
		if target_enemy == null or not target_enemy.is_alive():
			if alive_enemies.size() > 0:
				target_enemy = alive_enemies[0]
				player_manager.selected_target = target_enemy
		
		if target_enemy and target_enemy.is_alive():
			var damage_mult = player_manager.buff_manager.get_mult("damage")
			var final_damage = int(total_damage * damage_mult)
			
			var actual = target_enemy.take_damage(final_damage, player_manager.buff_manager.has_buff("ignore_block"))
			ui_controller.update_single_enemy(target_enemy)
			ui_controller.show_damage_number(target_enemy, actual)
			await get_tree().create_timer(0.2).timeout
	
	player_manager.buff_manager.remove_buff("stored_power")

func _tick_buffs_on_turn_end(target) -> void:
	if target.has_method("get") and target.get("buff_manager"):
		var effects = target.buff_manager.tick_buffs("on_turn_end")
		for effect in effects:
			_apply_tick_effect(target, effect)

func _decide_all_enemy_intents() -> void:
	for enemy in enemy_system.get_alive_enemies():
		enemy.decide_next_intent()

func _execute_enemy_turns() -> void:
	await get_tree().create_timer(0.3).timeout
	state_machine.change_state(StateMachine.BattleState.TURN_END)

func _execute_single_enemy_turn(enemy: EnemyUnit) -> void:
	if not enemy.is_alive() or enemy.current_intent.is_empty():
		return
	if not player_manager.is_alive():
		return
	
	_execute_enemy_action(enemy, enemy.current_intent)

func _execute_enemy_action(enemy: EnemyUnit, action: Dictionary) -> void:
	var action_type = action.get("type", "")
	
	if not player_manager.is_alive():
		return
	
	match action_type:
		"attack":
			var base_damage = action.get("damage", 5)
			var damage_add = int(enemy.buff_manager.get_flat_add("damage"))
			var damage_mult = enemy.buff_manager.get_mult("damage")
			var final_damage = int((base_damage + damage_add) * damage_mult)
			if final_damage > 0:
				var actual = player_manager.take_damage(final_damage)
				_update_player_ui()
				ui_controller.show_damage_number(player_manager, actual)
		"defend":
			var base_block = action.get("block", 5)
			var block_mult = enemy.buff_manager.get_mult("block")
			var final_block = int(base_block * block_mult)
			if final_block > 0:
				enemy.gain_block(final_block)
				ui_controller.update_single_enemy(enemy)
		"buff":
			var buff_id = action.get("buff_id", "")
			var stacks = action.get("stacks", 1)
			if not buff_id.is_empty():
				effect_resolver._resolve_apply_buff({"buff_id": buff_id, "value": stacks}, enemy)
				ui_controller.update_single_enemy(enemy)
		"debuff":
			var buff_id = action.get("buff_id", "")
			var stacks = action.get("stacks", 1)
			if not buff_id.is_empty():
				effect_resolver._resolve_apply_buff({"buff_id": buff_id, "value": stacks}, player_manager)
				_update_player_ui()

func _on_player_turn_start() -> void:
	_tick_buffs_on_turn_start(player_manager)
	
	for enemy in enemy_system.get_alive_enemies():
		_tick_buffs_on_turn_start(enemy)

func _tick_buffs_on_turn_start(target) -> void:
	if target.has_method("get") and target.get("buff_manager"):
		var effects = target.buff_manager.tick_buffs("on_turn_start")
		for effect in effects:
			_apply_tick_effect(target, effect)

func _apply_tick_effect(target, effect: Dictionary) -> void:
	var effect_type = effect.get("type", "")
	var value = effect.get("value", 0)
	var stacks = effect.get("stacks", 1)
	
	match effect_type:
		"damage":
			if target is PlayerManager:
				target.take_damage(value * stacks)
			elif target is EnemyUnit:
				target.take_damage(value * stacks)
		"heal":
			if target is PlayerManager:
				target.heal(value * stacks)
			elif target is EnemyUnit:
				target.heal(value * stacks)

func play_card(card: CardData, target = null) -> bool:
	if not state_machine.is_player_turn():
		return false
	
	var target_to_use = target
	if card.target_type == "self":
		target_to_use = player_manager
	elif card.target_type == "single_enemy" and target == null:
		pending_card = card
		return false
	
	if card.target_type == "single_enemy" and target_to_use == null:
		return false
	
	state_machine.change_state(StateMachine.BattleState.RESOLVING)
	
	effect_resolver.resolve_effects(card.effects, player_manager, target_to_use)
	card_system.play_card(card, target_to_use)
	_update_player_ui()
	
	await get_tree().create_timer(0.3).timeout
	
	if not state_machine.is_battle_active():
		return true
	
	if not _check_battle_end_state():
		state_machine.change_state(StateMachine.BattleState.PLAYER_TURN)
	
	return true

func end_player_turn() -> void:
	if not state_machine.is_player_turn():
		return
	
	sync_player_stats_to_gamedata()
	state_machine.change_state(StateMachine.BattleState.ENEMY_TURN)

func _on_card_played(card: CardData, _target) -> void:
	if ui_controller.is_card_select_active():
		return
	ui_controller.remove_card_from_hand(card)

func _on_hand_changed(hand: Array) -> void:
	ui_controller.update_hand_display(hand)

func _on_deck_count_changed(draw_count: int, discard_count: int) -> void:
	ui_controller.update_deck_info(draw_count, discard_count)

func _on_enemy_died(_enemy: EnemyUnit) -> void:
	ui_controller.update_enemy_display(enemy_system.get_alive_enemies())

func _on_enemy_damaged(enemy: EnemyUnit, amount: int) -> void:
	ui_controller.update_single_enemy(enemy)
	ui_controller.show_damage_number(enemy, amount)

func _on_all_enemies_defeated() -> void:
	if state_machine.is_battle_active():
		state_machine.change_state(StateMachine.BattleState.VICTORY)

func _on_player_hp_changed(current: int, _maximum: int) -> void:
	_update_player_ui()
	if GameData:
		GameData.player_current_hp = current

func _on_player_block_changed(_amount: int) -> void:
	_update_player_ui()

func _on_player_died() -> void:
	if state_machine.is_battle_active():
		state_machine.change_state(StateMachine.BattleState.DEFEAT)

func _on_counter_damage(amount: int) -> void:
	var target = player_manager.selected_target
	if target == null or not target.is_alive():
		var alive_enemies = enemy_system.get_alive_enemies()
		if alive_enemies.size() > 0:
			target = alive_enemies[0]
	if target and target.is_alive():
		var actual = target.take_damage(amount)
		ui_controller.update_single_enemy(target)
		ui_controller.show_damage_number(target, actual)
		ui_controller.show_state_message("招架反击! 造成 %d 伤害" % actual, 1.2)

func _update_player_ui() -> void:
	ui_controller.update_player_display(player_manager.current_hp, player_manager.max_hp, player_manager.block)
	ui_controller.update_player_stats_info(player_manager)
	ui_controller.update_player_buff_bar(player_manager)

func _update_initial_ui() -> void:
	ui_controller.update_enemy_display(enemy_system.get_all_enemies())
	_update_player_ui()
	ui_controller.update_deck_info(card_system.get_draw_pile_count(), card_system.get_discard_pile_count())

func _on_ui_card_clicked(card: CardData, card_node: Control) -> void:
	if card == null:
		return
	
	if ui_controller.is_card_select_active():
		return

func _on_ui_card_released(card: CardData, card_node: Control) -> void:
	pass

func _on_ui_card_played(card: CardData, target) -> void:
	if card == null:
		return
	var card_node = ui_controller.get_card_node(card) if ui_controller else null
	play_card_with_animation(card, target, card_node)

func _on_ui_card_cancelled(card: CardData) -> void:
	if pending_card == card:
		pending_card = null
		pending_card_node = null
	
	ui_controller.clear_target_highlights()

func _on_ui_card_dropped(card: CardData, target) -> void:
	if card == null:
		return
	
	var card_node = ui_controller.get_card_node(card) if ui_controller else null
	
	if target == null:
		if card_node and card_node.has_method("reset_position"):
			card_node.reset_position()
		return
	
	if card.target_type == "single_enemy" and target is EnemyUnit:
		play_card_with_animation(card, target, card_node)
	elif card.target_type == "single_ally" and target is PlayerManager:
		play_card_with_animation(card, target, card_node)
	else:
		if card_node and card_node.has_method("reset_position"):
			card_node.reset_position()

func play_card_with_animation(card: CardData, target, card_node: Control) -> void:
	if card_node:
		if target:
			ui_controller.play_card_animation(card, card_node, target)
		else:
			var target_pos = Vector2(400, 200)
			if card_node.has_method("play_play_animation"):
				card_node.play_play_animation(target_pos)
		await get_tree().create_timer(0.15).timeout
	
	play_card(card, target)

func _on_ui_enemy_selected(enemy: EnemyUnit) -> void:
	player_manager.selected_target = enemy
	if pending_card != null:
		var card_node = pending_card_node
		if card_node and card_node.has_method("cancel_target_mode"):
			card_node.cancel_target_mode()
		play_card_with_animation(pending_card, enemy, card_node)
		pending_card = null
		pending_card_node = null
		ui_controller.clear_target_highlights()

func _on_ui_end_turn_clicked() -> void:
	end_player_turn()

func get_tree():
	return Engine.get_main_loop()
