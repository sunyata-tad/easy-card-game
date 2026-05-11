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

signal battle_started()
signal battle_ended(victory: bool)
signal turn_changed(is_player_turn: bool)

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
	state_machine.state_changed.connect(_on_state_changed)
	state_machine.state_enter.connect(_on_state_enter)
	
	turn_manager.player_turn_start.connect(_on_player_turn_start)
	turn_manager.enemy_turn_start.connect(_on_enemy_turn_start)
	
	card_system.card_played.connect(_on_card_played)
	card_system.hand_changed.connect(_on_hand_changed)
	card_system.deck_count_changed.connect(_on_deck_count_changed)
	
	enemy_system.enemy_died.connect(_on_enemy_died)
	enemy_system.enemy_damaged.connect(_on_enemy_damaged)
	enemy_system.all_enemies_defeated.connect(_on_all_enemies_defeated)
	
	player_manager.hp_changed.connect(_on_player_hp_changed)
	player_manager.block_changed.connect(_on_player_block_changed)
	player_manager.player_died.connect(_on_player_died)

func setup_battle(root_node: Control, initial_deck: Array = [], enemies: Array = [], character_stats: Dictionary = {}) -> void:
	ui_controller = UIController.new(root_node)
	ui_controller.player_manager = player_manager
	_connect_ui_signals()
	
	if initial_deck.is_empty():
		initial_deck = card_database.load_starter_deck()
	
	card_system.initialize_deck(initial_deck)
	
	if character_stats.has("max_hp"):
		player_manager.max_hp = character_stats.max_hp
		player_manager.current_hp = character_stats.max_hp
	if character_stats.has("strength"):
		player_manager.strength = character_stats.strength
	if character_stats.has("dexterity"):
		player_manager.dexterity = character_stats.dexterity
	
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
	ui_controller.enemy_selected.connect(_on_ui_enemy_selected)
	ui_controller.end_turn_clicked.connect(_on_ui_end_turn_clicked)

func _on_state_changed(new_state: int, old_state: int) -> void:
	pass

func _on_state_enter(state: int) -> void:
	match state:
		StateMachine.BattleState.INIT:
			_on_battle_init()
		StateMachine.BattleState.DRAW_PHASE:
			_on_draw_phase()
		StateMachine.BattleState.PLAYER_TURN:
			_on_player_turn_phase()
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
	ui_controller.show_state_message("战斗开始!", 1.0)

func _on_draw_phase() -> void:
	card_system.draw_cards(5)
	ui_controller.show_state_message("回合开始", 0.6)
	turn_changed.emit(true)
	_decide_all_enemy_intents()
	
	if enemy_system.is_all_defeated():
		state_machine.change_state(StateMachine.BattleState.VICTORY)
	elif not player_manager.is_alive():
		state_machine.change_state(StateMachine.BattleState.DEFEAT)
	else:
		turn_manager.start_new_turn(true)
		state_machine.change_state(StateMachine.BattleState.PLAYER_TURN)

func _on_player_turn_phase() -> void:
	ui_controller.set_interactive(true)

func _on_enemy_turn_phase() -> void:
	ui_controller.set_interactive(false)
	ui_controller.show_state_message("敌人回合", 0.8)
	turn_manager.start_new_turn(false)
	turn_changed.emit(false)
	_execute_enemy_turns()

func _on_turn_end_phase() -> void:
	_process_turn_end_effects()
	turn_manager.end_current_turn()
	
	if enemy_system.is_all_defeated():
		state_machine.change_state(StateMachine.BattleState.VICTORY)
	elif not player_manager.is_alive():
		state_machine.change_state(StateMachine.BattleState.DEFEAT)
	else:
		state_machine.change_state(StateMachine.BattleState.DRAW_PHASE)

func _on_victory() -> void:
	battle_ended.emit(true)

func _on_defeat() -> void:
	battle_ended.emit(false)

func _process_turn_end_effects() -> void:
	player_manager.reset_block()
	enemy_system.reset_all_block()

func _decide_all_enemy_intents() -> void:
	for enemy in enemy_system.get_alive_enemies():
		enemy.decide_next_intent()

func _execute_enemy_turns() -> void:
	var alive_enemies = enemy_system.get_alive_enemies()
	
	for enemy in alive_enemies:
		_execute_single_enemy_turn(enemy)
	
	await get_tree().create_timer(0.5).timeout
	
	state_machine.change_state(StateMachine.BattleState.TURN_END)

func _execute_single_enemy_turn(enemy: EnemyUnit) -> void:
	if enemy.current_intent.is_empty():
		return
	
	_execute_enemy_action(enemy, enemy.current_intent)

func _execute_enemy_action(_enemy: EnemyUnit, action: Dictionary) -> void:
	var action_type = action.get("type", "")
	
	match action_type:
		"attack":
			var damage = action.get("damage", 5)
			player_manager.take_damage(damage)
			_update_player_ui()
		"defend":
			var block = action.get("block", 5)
			_enemy.gain_block(block)

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

func _on_enemy_turn_start() -> void:
	pass

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
	
	await get_tree().create_timer(0.3).timeout
	
	if not state_machine.is_battle_active():
		return true
	
	if enemy_system.is_all_defeated():
		state_machine.change_state(StateMachine.BattleState.VICTORY)
	elif not player_manager.is_alive():
		state_machine.change_state(StateMachine.BattleState.DEFEAT)
	else:
		state_machine.change_state(StateMachine.BattleState.PLAYER_TURN)
	
	return true

func end_player_turn() -> void:
	if not state_machine.is_player_turn():
		return
	
	ui_controller.show_state_message("回合结束", 0.5)
	card_system.discard_hand()
	state_machine.change_state(StateMachine.BattleState.ENEMY_TURN)

func _on_card_played(card: CardData, _target) -> void:
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

func _on_player_hp_changed(_current: int, _maximum: int) -> void:
	_update_player_ui()

func _on_player_block_changed(_amount: int) -> void:
	_update_player_ui()

func _on_player_died() -> void:
	if state_machine.is_battle_active():
		state_machine.change_state(StateMachine.BattleState.DEFEAT)

func _update_player_ui() -> void:
	ui_controller.update_player_display(player_manager.current_hp, player_manager.max_hp, player_manager.block)

func _update_initial_ui() -> void:
	ui_controller.update_enemy_display(enemy_system.get_all_enemies())
	_update_player_ui()
	ui_controller.update_deck_info(card_system.get_draw_pile_count(), card_system.get_discard_pile_count())

func _on_ui_card_clicked(card: CardData, card_node: Control) -> void:
	if card == null:
		return
	
	if card.target_type == "single_enemy":
		pending_card = card
		pending_card_node = card_node
	elif card.target_type == "self":
		play_card(card)
	else:
		play_card(card)

func _on_ui_enemy_selected(enemy: EnemyUnit) -> void:
	if pending_card != null:
		play_card(pending_card, enemy)
		pending_card = null
		pending_card_node = null

func _on_ui_end_turn_clicked() -> void:
	end_player_turn()

func get_tree():
	return Engine.get_main_loop()
