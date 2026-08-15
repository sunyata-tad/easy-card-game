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
var is_first_turn: bool = true
var is_discard_phase: bool = false
var discard_attack_available: bool = true   ## 本回合是否还能使用弃牌攻击（基础：一回合一次）
var _is_discard_attack_aiming: bool = false ## 弃牌攻击：是否处于"已弃牌、等待选择攻击目标"阶段

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
	card_system.deck_exhausted.connect(_on_deck_exhausted)
	player_manager.hp_changed.connect(_on_player_hp_changed)
	player_manager.block_changed.connect(_on_player_block_changed)
	player_manager.player_died.connect(_on_player_died)
	player_manager.counter_damage.connect(_on_counter_damage)

func setup_battle(root_node: Control, initial_deck: Array = [], enemies: Array = []) -> void:
	ui_controller = UIController.new(root_node)
	ui_controller.player_manager = player_manager
	_connect_ui_signals()
	card_system.initialize_deck(initial_deck)
	effect_resolver.card_system = card_system
	effect_resolver.ui_controller = ui_controller
	player_manager.max_hp = GameData.player_max_hp
	player_manager.current_hp = GameData.player_current_hp
	player_manager.base_strength = GameData.player_strength
	player_manager.base_dexterity = GameData.player_dexterity
	# 加载遗物（规则改变来源）并注入战斗上下文
	_load_player_relics()
	for enemy_data in enemies:
		enemy_system.add_enemy(enemy_data)
	if enemies.is_empty():
		var e = enemy_database.get_enemy("test_dummy")
		if e:
			enemy_system.add_enemy(e)

## 从 GameData 加载玩家遗物（独立实例，直接加入），并注入战斗上下文
func _load_player_relics() -> void:
	if GameData:
		for relic in GameData.get_relics():
			if relic:
				player_manager.relic_manager.add_relic(relic)
	player_manager.relic_manager.battle_controller = self

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
	ui_controller.discard_attack_requested.connect(_on_discard_attack_requested)
	ui_controller.attack_target_selected.connect(_on_discard_attack_target_selected)

## 检查战斗是否结束（可被 HookChain 拦截修改）
## 通过 player_manager.hook_chain 的 HOOK_CHECK_BATTLE_END 钩子实现自定义结束条件
func _check_battle_end_state() -> bool:
	if not state_machine.is_battle_active():
		return true
	# 钩子上下文：允许外部修改结束判定逻辑
	var ctx: Dictionary = {"should_end": false, "result": "", "reason": ""}
	if enemy_system.is_all_defeated():
		ctx.should_end = true; ctx.result = "victory"; ctx.reason = "all_enemies_defeated"
	elif not player_manager.is_alive():
		ctx.should_end = true; ctx.result = "defeat"; ctx.reason = "player_dead"
	player_manager.hook_chain.trigger(HookRegistry.HOOK_CHECK_BATTLE_END, 0, ctx)
	if not ctx.should_end:
		return false
	if ctx.result == "victory":
		state_machine.change_state(StateMachine.BattleState.VICTORY)
	elif ctx.result == "defeat":
		state_machine.change_state(StateMachine.BattleState.DEFEAT)
	return true

func _on_state_enter(state: int) -> void:
	match state:
		StateMachine.BattleState.INIT: _on_battle_init()
		StateMachine.BattleState.DRAW_PHASE: _on_draw_phase()
		StateMachine.BattleState.PLAYER_TURN: _on_player_turn_phase()
		StateMachine.BattleState.RESOLVING: _on_resolving_phase()
		StateMachine.BattleState.ENEMY_TURN: _on_enemy_turn_phase()
		StateMachine.BattleState.TURN_END: _on_turn_end_phase()
		StateMachine.BattleState.VICTORY: _on_victory()
		StateMachine.BattleState.DEFEAT: _on_defeat()

func _on_battle_init() -> void:
	turn_manager.reset()
	is_first_turn = true
	is_discard_phase = false

func _on_draw_phase() -> void:
	player_manager.reset_block()
	enemy_system.reset_all_block()
	player_manager.buff_manager.remove_at_turn_end()
	effect_resolver.clear_all_temp_hooks(player_manager)
	var draw_count = 5 if is_first_turn else 1
	# 遗物"终末轮回"效果②生效后：每回合开始抽卡直到手卡≥10
	if player_manager.relic_manager and player_manager.relic_manager.is_awakened("immortal_cycle"):
		draw_count = maxi(card_system.max_hand_size - card_system.hand.size(), 0)
	is_first_turn = false
	# 正常规则：每回合开始必定抽 1 张（游戏王模式），即使手牌已达上限也会抽到 11 张；
	# 超出的部分由回合结束的弃牌阶段处理（弃牌降到 max_hand_size）。
	card_system.draw_cards(draw_count)
	turn_changed.emit(true)
	_decide_all_enemy_intents()
	if not _check_battle_end_state():
		turn_manager.start_new_turn(true)
		state_machine.change_state(StateMachine.BattleState.PLAYER_TURN)

func _on_player_turn_phase() -> void:
	ui_controller.set_interactive(true)
	_update_player_ui()
	if state_machine.previous_state != StateMachine.BattleState.RESOLVING:
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
	var excess = card_system.hand.size() - card_system.max_hand_size
	var block_discard := false
	if excess > 0:
		# 弃牌规则门：HOOK_CHECK_DISCARD 钩子可阻止弃牌（如"本场不弃牌"能力卡）
		var ctx := {"block_discard": false}
		player_manager.hook_chain.trigger(HookRegistry.HOOK_CHECK_DISCARD, excess, ctx)
		block_discard = ctx.get("block_discard", false)
	if excess > 0 and not block_discard:
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
	if not state_machine.is_battle_active() or _check_battle_end_state():
		return
	state_machine.change_state(StateMachine.BattleState.DRAW_PHASE)

func confirm_discard_cards(cards_to_discard: Array) -> void:
	if not is_discard_phase:
		return
	for card in cards_to_discard:
		card_system.discard_specific_card(card)
	is_discard_phase = false
	discard_phase_ended.emit()
	var excess = card_system.hand.size() - card_system.max_hand_size
	if excess > 0:
		is_discard_phase = true
		discard_phase_started.emit(excess)
		return
	await _resolve_end_turn()

## ========== 弃牌攻击（主动攻击） ==========
## 玩家在回合中主动弃 1 张手牌 → 立刻用 get_strength() 走完整攻击链结算一次攻击。
## 基础限制：一回合一次（discard_attack_available）；未来可由"突破规则"卡修改。

## UI 触发：点击"普通攻击"按钮 → 进入"选择一张牌弃掉"步骤
func _on_discard_attack_requested() -> void:
	_is_discard_attack_aiming = false
	if not state_machine.is_player_turn():
		return
	# 无法攻击（已攻击过 / 效果导致不能攻击 / 额外攻击次数耗尽）→ 统一提示
	if not discard_attack_available:
		ui_controller.show_state_message("你已经攻击过了。", 1.0)
		return
	if card_system.hand.is_empty():
		ui_controller.show_state_message("没有手牌可以弃掉", 1.0)
		return
	ui_controller.enter_attack_card_select(
		"弃牌攻击：选择 1 张牌弃掉（本回合限 1 次）",
		_on_discard_attack_card_selected
	)

## 弃牌步骤完成：弃掉所选牌 → 立即结算（实时结算原则）→ 实时检测存活敌人 → 进入选目标
func _on_discard_attack_card_selected(cards: Array) -> void:
	if cards.is_empty():
		return
	# 弃牌 cost 完成后立即结算；弃牌可能触发效果杀死敌人
	card_system.discard_specific_card(cards[0])
	# 弃牌代价已支付，本次"弃牌攻击"名额消耗（防止取消后免费倾泻手牌）
	discard_attack_available = false
	_update_player_ui()
	# 实时检测存活目标（实时结算：弃牌效果可能已杀死部分/全部敌人）
	var alive = enemy_system.get_alive_enemies()
	if alive.is_empty():
		# 无存活目标，本次攻击作废；战斗是否结束交由结束判定
		_check_battle_end_state()
		return
	_is_discard_attack_aiming = true
	ui_controller.start_target_selection()

## 选目标完成：执行弃牌攻击（完整攻击链，伤害 = get_strength() = base_strength + 力量 buff）
func _on_discard_attack_target_selected(enemy: EnemyUnit) -> void:
	if not _is_discard_attack_aiming:
		return
	_is_discard_attack_aiming = false
	# 实时结算：目标可能在弃牌效果中已死亡，重新校验存活
	if not enemy.is_alive():
		var alive = enemy_system.get_alive_enemies()
		if alive.is_empty():
			_check_battle_end_state()
			return
		enemy = alive[0]
	_perform_attack(player_manager, enemy, 0)
	_update_player_ui()
	_check_battle_end_state()

func _on_victory() -> void:
	# 遗物"终末轮回"效果③：触发过②的战斗，战斗结束时生命设为上限 50%
	if player_manager.relic_manager and player_manager.relic_manager.is_awakened("immortal_cycle"):
		player_manager.current_hp = int(round(player_manager.max_hp * 0.5))
		player_manager.hp_changed.emit(player_manager.current_hp, player_manager.max_hp)
	sync_player_stats_to_gamedata()
	battle_ended.emit(true)

func _on_defeat() -> void:
	sync_player_stats_to_gamedata()
	battle_ended.emit(false)

func sync_player_stats_to_gamedata() -> void:
	if GameData:
		GameData.player_current_hp = player_manager.current_hp
		GameData.player_max_hp = player_manager.max_hp
		GameData.player_strength = player_manager.base_strength
		GameData.player_dexterity = player_manager.base_dexterity

func _process_turn_end_effects() -> void:
	_tick_buffs_on_turn_end(player_manager)
	for enemy in enemy_system.get_alive_enemies():
		_tick_buffs_on_turn_end(enemy)
	_execute_player_auto_block()
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
	for enemy in enemy_system.get_alive_enemies():
		_execute_single_enemy_turn(enemy)
		if not player_manager.is_alive():
			break
		await get_tree().create_timer(0.3).timeout

## 回合结束阶段：玩家自动获取敏捷护甲（base_dexterity 自动护甲保留；攻击改为主动弃牌攻击）
func _execute_player_auto_block() -> void:
	var total_block = player_manager.get_total_block()
	if total_block > 0:
		player_manager.gain_block(total_block)
		_update_player_ui()

func _perform_attack(source, target, base_damage: int) -> void:
	if not source or not target:
		return
	var hc = source.hook_chain if source.hook_chain else null
	if source is PlayerManager and hc:
		var ctx: Dictionary = {}
		hc.trigger(HookRegistry.HOOK_ON_ATTACK_START, 0, ctx)
		var base = hc.trigger(HookRegistry.HOOK_CALC_BASE, source.base_strength, ctx)
		base = int(hc.trigger(HookRegistry.HOOK_CALC_MULT, int(base), ctx))
		var add = hc.trigger(HookRegistry.HOOK_CALC_ADD, 0, ctx)
		var raw = int(base) + int(add)
		var final_dmg = hc.trigger(HookRegistry.HOOK_CALC_FINAL, raw, ctx)
		hc.trigger(HookRegistry.HOOK_ON_ATTACK_HIT, final_dmg, {"hit_index": 0})
		if target is EnemyUnit:
			var actual = target.take_damage(final_dmg, ctx.get("ignore_block", false))
			ui_controller.update_single_enemy(target)
			ui_controller.show_damage_number(target, actual)
		elif target is PlayerManager:
			target.take_damage(final_dmg)
		hc.trigger(HookRegistry.HOOK_ON_ATTACK_END, 0, ctx)
		return
	if hc:
		var ctx: Dictionary = {}
		hc.trigger(HookRegistry.HOOK_ON_ATTACK_START, base_damage, ctx)
		var hit_value = hc.trigger(HookRegistry.HOOK_CALC_BASE, base_damage, ctx)
		hit_value = hc.trigger(HookRegistry.HOOK_CALC_MULT, hit_value, ctx)
		hit_value = hc.trigger(HookRegistry.HOOK_CALC_ADD, hit_value, ctx)
		hit_value = hc.trigger(HookRegistry.HOOK_CALC_FINAL, hit_value, ctx)
		hit_value = hc.trigger(HookRegistry.HOOK_ON_ATTACK_HIT, hit_value, {"hit_index": 0})
		if target is PlayerManager:
			var actual = target.take_damage(hit_value)
			ui_controller.show_damage_number(target, actual)
		hc.trigger(HookRegistry.HOOK_ON_ATTACK_END, 0, ctx)
		return
	var actual = target.take_damage(base_damage)
	ui_controller.show_damage_number(target, actual)

func _tick_buffs_on_turn_end(target) -> void:
	if target.has_method("get") and target.get("buff_manager"):
		for effect in target.buff_manager.tick_buffs("on_turn_end"):
			_apply_tick_effect(target, effect)

func _decide_all_enemy_intents() -> void:
	for enemy in enemy_system.get_alive_enemies():
		enemy.decide_next_intent()

func _execute_enemy_turns() -> void:
	await get_tree().create_timer(0.3).timeout
	state_machine.change_state(StateMachine.BattleState.TURN_END)

func _execute_single_enemy_turn(enemy: EnemyUnit) -> void:
	if not enemy.is_alive() or enemy.current_intent.is_empty() or not player_manager.is_alive():
		return
	# 迷惑：本回合无法行动（回合结束层数-1）
	if enemy.buff_manager and enemy.buff_manager.has_buff("stun"):
		ui_controller.show_state_message("%s 被迷惑，无法行动" % enemy.get_name(), 0.8)
		return
	_execute_enemy_action(enemy, enemy.current_intent)

func _execute_enemy_action(enemy: EnemyUnit, action: Dictionary) -> void:
	if not player_manager.is_alive():
		return
	match action.get("type", ""):
		"attack":
			_perform_attack(enemy, player_manager, action.get("damage", 5))
			_update_player_ui()
		"defend":
			var final_block = int(action.get("block", 5) * enemy.buff_manager.get_mult("block"))
			if final_block > 0:
				enemy.gain_block(final_block)
				ui_controller.update_single_enemy(enemy)
		"buff":
			effect_resolver.apply_buff({"buff_id": action.get("buff_id", ""), "value": action.get("stacks", 1)}, enemy)
			ui_controller.update_single_enemy(enemy)
		"debuff":
			effect_resolver.apply_buff({"buff_id": action.get("buff_id", ""), "value": action.get("stacks", 1)}, player_manager)
			_update_player_ui()

func _on_player_turn_start() -> void:
	discard_attack_available = true
	_tick_buffs_on_turn_start(player_manager)
	for enemy in enemy_system.get_alive_enemies():
		_tick_buffs_on_turn_start(enemy)

func _tick_buffs_on_turn_start(target) -> void:
	if target.has_method("get") and target.get("buff_manager"):
		for effect in target.buff_manager.tick_buffs("on_turn_start"):
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
	# 出牌条件检查（如逆流：生命低于最大10%才可打出）
	if not card.can_play(player_manager):
		ui_controller.show_state_message("条件不满足，无法打出：%s" % card.name, 1.2)
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
	if not ui_controller.is_card_select_active():
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

func _on_deck_exhausted() -> void:
	# 遗物"终末轮回"效果②生效后：失败条件改为"卡组为空时进行抽卡"
	if player_manager.relic_manager and player_manager.relic_manager.is_awakened("immortal_cycle"):
		if state_machine.is_battle_active():
			player_manager.die()

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
		for e in enemy_system.get_alive_enemies():
			target = e
			break
	if target and target.is_alive():
		var actual = target.take_damage(amount)
		ui_controller.update_single_enemy(target)
		ui_controller.show_damage_number(target, actual)
		ui_controller.show_state_message("招架反击! 造成 %d 伤害" % actual, 1.2)

func _update_player_ui() -> void:
	ui_controller.update_player_display(player_manager.current_hp, player_manager.max_hp, player_manager.block)
	ui_controller.update_player_stats_info(player_manager)
	ui_controller.update_player_buff_bar(player_manager)
	ui_controller.update_all_enemy_intents()

func _update_initial_ui() -> void:
	ui_controller.update_enemy_display(enemy_system.get_all_enemies())
	_update_player_ui()
	ui_controller.update_deck_info(card_system.get_draw_pile_count(), card_system.get_discard_pile_count())

func _on_ui_card_clicked(card: CardData, _card_node: Control) -> void:
	if card == null or ui_controller.is_card_select_active():
		return

func _on_ui_card_released(_card: CardData, _card_node: Control) -> void:
	pass

func _on_ui_card_played(card: CardData, target) -> void:
	if card == null:
		return
	var card_node = ui_controller.get_card_node(card) if ui_controller else null
	play_card_with_animation(card, target, card_node)

func _on_ui_card_cancelled(card: CardData) -> void:
	if pending_card == card:
		pending_card = null
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
			if card_node.has_method("play_play_animation"):
				card_node.play_play_animation(Vector2(400, 200))
		await get_tree().create_timer(0.15).timeout
	play_card(card, target)

func _on_ui_enemy_selected(enemy: EnemyUnit) -> void:
	player_manager.selected_target = enemy
	if pending_card != null:
		play_card_with_animation(pending_card, enemy, null)
		pending_card = null
		ui_controller.clear_target_highlights()

func _on_ui_end_turn_clicked() -> void:
	end_player_turn()

func get_tree():
	return Engine.get_main_loop()