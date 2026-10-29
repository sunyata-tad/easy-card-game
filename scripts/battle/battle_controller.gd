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
var rules: BattleRules

var pending_card: CardData = null
var is_first_turn: bool = true
var is_discard_phase: bool = false
var use_new_flow: bool = true   ## B4: 使用同时出牌新流程
var is_turn_ready: bool = false  ## 回合准备是否完成（投骰+敌人意图）


signal battle_ended(victory: bool)
signal turn_changed(is_player_turn: bool)
signal discard_phase_started(cards_to_discard: int)

func _init():
	_initialize_systems()
	_connect_signals()

func _initialize_systems() -> void:
	rules = BattleRules.new()
	state_machine = StateMachine.new()
	turn_manager = TurnManager.new()
	card_system = CardSystem.new()
	card_system.max_hand_size = rules.max_hand_size
	enemy_system = EnemySystem.new()
	player_manager = PlayerManager.new(rules.initial_max_hp)
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
	effect_resolver.healing_done.connect(_on_healing_done)
	effect_resolver.block_gained.connect(_on_block_gained)
	enemy_system.all_enemies_defeated.connect(_on_all_enemies_defeated)
	card_system.deck_exhausted.connect(_on_deck_exhausted)
	player_manager.hp_changed.connect(_on_player_hp_changed)
	player_manager.block_changed.connect(_on_player_block_changed)
	player_manager.player_died.connect(_on_player_died)
	player_manager.counter_damage.connect(_on_counter_damage)
	player_manager.player_damaged.connect(_on_player_damaged)

func _on_player_damaged(amount: int) -> void:
	if ui_controller:
		ui_controller.flash_player_area(amount)

func setup_battle(root_node: Control, initial_deck: Array = [], enemies: Array = []) -> void:
	ui_controller = UIController.new(root_node)
	ui_controller.battle_controller = self
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
		var e = enemy_database.get_enemy("腐化法师")
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

	_on_battle_init()
	state_machine.change_state(StateMachine.BattleState.DRAW_PHASE)

func _connect_ui_signals() -> void:
	ui_controller.card_clicked.connect(_on_ui_card_clicked)

	ui_controller.card_cancelled.connect(_on_ui_card_cancelled)
	ui_controller.card_dropped.connect(_on_ui_card_dropped)
	ui_controller.card_played.connect(_on_ui_card_played)
	ui_controller.enemy_selected.connect(_on_ui_enemy_selected)
	ui_controller.end_turn_clicked.connect(_on_ui_end_turn_clicked)


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
		StateMachine.BattleState.TURN_PREPARE: _on_turn_prepare_phase()
		StateMachine.BattleState.ENEMY_SELECT: _on_enemy_select_phase()
		StateMachine.BattleState.PLAYER_SELECT: _on_player_select_phase()
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
	if not is_first_turn:
		player_manager.regen_energy()
		# 新流程：敌人也恢复能量
		if use_new_flow:
			for enemy in enemy_system.get_alive_enemies():
				enemy.regen_energy()
	player_manager.buff_manager.remove_at_turn_end()
	effect_resolver.clear_all_temp_hooks(player_manager)
	var draw_count = rules.initial_draw_count if is_first_turn else rules.turn_draw_count
	# 遗物"终末轮回"效果②生效后：每回合开始抽卡直到手卡≥10
	if player_manager.relic_manager and player_manager.relic_manager.is_awakened("immortal_cycle"):
		draw_count = maxi(card_system.max_hand_size - card_system.hand.size(), 0)
	# Innate 标签：第一回合优先将 Innate 牌从牌库抽到手牌（不占用抽牌数）
	if is_first_turn:
		var innate_cards: Array = []
		for i in range(card_system.draw_pile.size() - 1, -1, -1):
			if card_system.draw_pile[i].has_tag("Innate"):
				innate_cards.append(card_system.draw_pile.pop_at(i))
		for card in innate_cards:
			card_system.hand.append(card)
			card_system.card_drawn.emit(card)
		if innate_cards.size() > 0:
			card_system.hand_changed.emit(card_system.hand)
	is_first_turn = false
	# 正常规则：每回合开始必定抽 1 张（游戏王模式），即使手牌已达上限也会抽到 11 张；
	# 超出的部分由回合结束的弃牌阶段处理（弃牌降到 max_hand_size）。
	card_system.draw_cards(draw_count)
	turn_changed.emit(true)
	if use_new_flow:
		# 清除上回合的敌人意图显示
		if ui_controller:
			ui_controller.clear_all_enemy_intents()
		if not _check_battle_end_state():
			state_machine.change_state(StateMachine.BattleState.TURN_PREPARE)


func _on_player_turn_phase() -> void:
	ui_controller.set_interactive(true)
	_update_player_ui()
	if state_machine.previous_state != StateMachine.BattleState.RESOLVING:
		ui_controller.show_turn_banner("你的回合")

func _on_resolving_phase() -> void:
	ui_controller.set_interactive(false)
	if use_new_flow:
		ui_controller.set_hand_visible(false)
		# 结算中：按钮灰色不可用
		ui_controller.show_end_turn_button("回合开始", false)

func _on_enemy_turn_phase() -> void:
	ui_controller.set_interactive(false)
	ui_controller.show_turn_banner("敌人回合")
	turn_manager.start_new_turn(false)
	turn_changed.emit(false)
	await _execute_enemy_turns()

## B4: 回合准备阶段——骰子速度未知(?)，等待玩家按下"回合准备"
func _on_turn_prepare_phase() -> void:
	is_turn_ready = false
	if ui_controller:
		ui_controller.set_interactive(false)
		ui_controller.set_hand_visible(false)
		ui_controller.create_dice_bar(player_manager.slots, _player_slot_speeds, true)
		ui_controller.update_energy_display(player_manager.energy, player_manager.max_energy)
		ui_controller.update_slots_display(player_manager.slots, _player_slot_speeds)
		ui_controller.show_end_turn_button("回合准备", true)

## 玩家按下"回合准备"——投骰+揭示速度+进入敌人选牌阶段
func on_turn_prepare_clicked() -> void:
	if not state_machine.is_turn_prepare():
		return
	_roll_all_speeds()
	if ui_controller:
		ui_controller.reveal_player_dice(_player_slot_speeds)
	state_machine.change_state(StateMachine.BattleState.ENEMY_SELECT)

## B4: 敌人选牌阶段——AI决定出牌，玩家可见
func _on_enemy_select_phase() -> void:
	_pending_plays.clear()
	_enemy_card_systems.clear()
	for enemy_idx in enemy_system.enemies.size():
		var enemy = enemy_system.enemies[enemy_idx]
		if enemy.is_dead:
			continue
		var enemy_cs = CardSystem.new()
		enemy_cs.initialize_deck(_get_enemy_deck(enemy))
		enemy_cs.draw_cards(5)
		_enemy_card_systems[enemy_idx] = enemy_cs
		var EnemyAIClass = load("res://scripts/battle/enemy_ai.gd")
		var plays = EnemyAIClass.decide_plays(enemy, enemy_cs, player_manager, enemy_system.enemies)
		var enemy_speeds: Array = _enemy_slot_speeds.get(enemy_idx, [])
		for play in plays:
			var s_idx: int = play.slot_index
			var spd: int = enemy_speeds[s_idx] if s_idx < enemy_speeds.size() else 1
			_add_pending_play(play.card, enemy, play.target, spd, false, s_idx, enemy_idx)
		if ui_controller:
			ui_controller.show_enemy_intent(enemy_idx, plays)
			# 创建敌人骰子栏并显示AI出的牌
			ui_controller.create_enemy_dice_bar(enemy_idx, enemy.slots, enemy_speeds)
			for play in plays:
				ui_controller.place_enemy_dice_card(enemy_idx, play.slot_index, play.card)
	if not _check_battle_end_state():
		state_machine.change_state(StateMachine.BattleState.PLAYER_SELECT)

## B4: 玩家选牌阶段——骰子已就绪，等待玩家装载卡牌
func _on_player_select_phase() -> void:
	if ui_controller:
		ui_controller.set_interactive(true)
		ui_controller.set_hand_visible(false)
		ui_controller.show_turn_banner("你的回合")
		ui_controller.reveal_player_dice()
		ui_controller.show_end_turn_button("回合开始", true)
	_update_player_ui()
	if ui_controller:
		ui_controller.update_energy_display(player_manager.energy, player_manager.max_energy)
		ui_controller.update_slots_display(player_manager.slots, _player_slot_speeds)

## 玩家按下"回合开始"——结算
func on_turn_start_clicked() -> void:
	if not state_machine.is_player_select():
		return
	confirm_player_plays()

## B4: 队列一张玩家卡牌（选牌阶段）
func _queue_player_card(card: CardData, target) -> void:
	# 检查槽位
	if _player_queued_plays.size() >= player_manager.slots:
		ui_controller.show_state_message("槽位已满", 1.0)
		return
	# 检查能量
	var queued_cost: int = 0
	for p in _player_queued_plays:
		queued_cost += p.card.cost
	if queued_cost + card.cost > player_manager.energy:
		ui_controller.show_state_message("能量不足", 0.8)
		var cn = ui_controller.current_hand_cards.get(card)
		if cn and is_instance_valid(cn):
			ui_controller._shake_card(cn)
		return
	# 检查是否已在队列中
	for p in _player_queued_plays:
		if p.card == card:
			return
	# 确定目标
	var target_to_use = target
	if card.target_type == "self":
		target_to_use = player_manager
	elif card.target_type == "single_enemy" and target == null:
		# 自动选择第一个存活敌人
		for e in enemy_system.get_alive_enemies():
			target_to_use = e
			break
		if target_to_use == null:
			return
	_player_queued_plays.append({"card": card, "target": target_to_use})
	# 更新UI
	_update_new_flow_hud()
	# 卡牌视觉反馈：上移表示已队列
	if ui_controller:
		var card_node = ui_controller.get_card_node(card)
		if card_node and card_node.has_method("set_queued"):
			card_node.set_queued(true)


## B4: 更新新流程HUD
func _update_new_flow_hud() -> void:
	if not ui_controller:
		return
	var remaining_energy = player_manager.energy
	for p in _player_queued_plays:
		remaining_energy -= p.card.cost
	var used_energy = player_manager.energy - remaining_energy
	ui_controller.update_energy_display(remaining_energy, player_manager.max_energy, used_energy)
	var used_slots = _player_queued_plays.size()
	ui_controller.update_slots_display(player_manager.slots - used_slots, _player_slot_speeds)
	# 显示队列信息
	var queue_text = "已选牌: %d/%d" % [used_slots, player_manager.slots]
	ui_controller.show_state_message(queue_text, 0.5)

## B4: 玩家确认出牌——收集玩家槽位出牌，进入结算
func confirm_player_plays(slot_plays: Array = []) -> void:
	# 未显式传入时从骰子UI获取装载的卡牌
	if slot_plays.is_empty() and ui_controller:
		slot_plays = ui_controller.get_loaded_plays()
	for play in slot_plays:
		var card: CardData = play.card
		var target = play.target
		var slot_index: int = play.get("slot_index", 0)
		var default_speed = _player_slot_speeds[slot_index] if slot_index < _player_slot_speeds.size() else 1
		var speed: int = play.get("speed", default_speed)
		_add_pending_play(card, player_manager, target, speed, true, slot_index)
		# 消耗玩家能量
		player_manager.spend_energy(card.cost)
	# 消耗敌人能量（AI选出的牌）
	for enemy_idx in _enemy_card_systems.size():
		var enemy = enemy_system.enemies[enemy_idx] if enemy_idx < enemy_system.enemies.size() else null
		if enemy == null or enemy.is_dead:
			continue
		for play in _pending_plays:
			if not play.is_player and play.enemy_index == enemy_idx:
				enemy.spend_energy(play.card.cost)
	# 清理骰子UI
	if ui_controller:
		ui_controller.clear_dice_ui()
	state_machine.change_state(StateMachine.BattleState.RESOLVING)
	await _resolve_all_plays()
	if not _check_battle_end_state():
		state_machine.change_state(StateMachine.BattleState.TURN_END)

## B4: 获取敌人卡组（basic卡组或自定义）
func _get_enemy_deck(_enemy: EnemyUnit) -> Array:
	var db = CardDatabase.new()
	return db.create_deck([
		{"card_id": "斩击", "count": 2},
		{"card_id": "格挡", "count": 2},
		{"card_id": "重斩", "count": 1},
		{"card_id": "铁壁", "count": 1},
		{"card_id": "攻守兼备", "count": 2},
		{"card_id": "烈斩", "count": 1}
	])

func _on_turn_end_phase() -> void:
	# 新流程：无弃牌阶段，直接进入回合结束处理
	if use_new_flow:
		await _resolve_end_turn()
		return
	# 旧流程：Retain 标签检查 + 弃牌阶段
	# Retain 标签：有 Retain 的牌不计入弃牌数量
	var non_retain_count := 0
	for card in card_system.hand:
		if not card.has_tag("Retain"):
			non_retain_count += 1
	var excess = non_retain_count - card_system.max_hand_size
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

	await _process_turn_end_effects()
	turn_manager.end_current_turn()
	if not state_machine.is_battle_active() or _check_battle_end_state():
		return
	state_machine.change_state(StateMachine.BattleState.DRAW_PHASE)

## 弃牌：卡牌节点直接缩小飞向弃牌堆淡出（跳过"飞向中央悬停"），数据层同步弃置
func _discard_card_with_animation(card: CardData) -> void:
	var card_node = ui_controller.get_card_node(card) if ui_controller else null
	if card_node and ui_controller:
		ui_controller.detach_card_node(card)
	card_system.discard_specific_card(card)
	if card_node:
		var discard_pos = ui_controller.get_discard_pile_global_pos() if ui_controller else Vector2(120, card_node.get_viewport_rect().size.y - 288)
		card_node.fly_to_discard(discard_pos)  # 不 await：动画后台播放，不阻塞后续逻辑

func confirm_discard_cards(cards_to_discard: Array) -> void:
	if not is_discard_phase:
		return
	for card in cards_to_discard:
		_discard_card_with_animation(card)
	is_discard_phase = false

	var excess = card_system.hand.size() - card_system.max_hand_size
	if excess > 0:
		is_discard_phase = true
		discard_phase_started.emit(excess)
		return
	await _resolve_end_turn()

## ========== 弃牌攻击（主动攻击） ==========

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
	player_manager.buff_manager.decrease_durations()
	player_manager.buff_manager.remove_at_turn_end()
	for enemy in enemy_system.get_alive_enemies():
		enemy.buff_manager.decrease_durations()
		enemy.buff_manager.remove_at_turn_end()

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
			var actual = target.take_damage(final_dmg)
			ui_controller.show_damage_number(target, actual)
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

func _execute_enemy_turns() -> void:
	await get_tree().create_timer(0.3).timeout
	state_machine.change_state(StateMachine.BattleState.TURN_END)

func _on_player_turn_start() -> void:

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
	# 能量检查
	if not player_manager.can_afford(card.cost):
		ui_controller.show_state_message("能量不足，无法打出：%s" % card.name, 1.2)
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
	player_manager.spend_energy(card.cost)
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

## 治疗结算 → 绿色飘字
func _on_healing_done(target, amount: int) -> void:
	if ui_controller:
		ui_controller.show_damage_number(target, amount, "heal")

## 护甲获得结算 → 蓝色飘字
func _on_block_gained(target, amount: int) -> void:
	if ui_controller:
		ui_controller.show_damage_number(target, amount, "block")

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


func _update_initial_ui() -> void:
	ui_controller.update_enemy_display(enemy_system.get_all_enemies())
	_update_player_ui()
	ui_controller.update_deck_info(card_system.get_draw_pile_count(), card_system.get_discard_pile_count())

func _on_ui_card_clicked(card: CardData, card_node: Control) -> void:
	if card == null or ui_controller.is_card_select_active():
		return
	# 新流程：骰子激活时，点击手牌装载到骰子
	if use_new_flow and state_machine.is_player_select():
		if ui_controller.has_active_dice():
			ui_controller.load_card_to_dice(card, card_node)
			_update_new_flow_hud()
		return


func _on_ui_card_played(card: CardData, target) -> void:
	if card == null:
		return
	# 新流程：骰子激活时装载到骰子（而非旧队列）
	if use_new_flow and state_machine.is_player_select():
		if ui_controller.has_active_dice():
			var card_node = ui_controller.get_card_node(card)
			ui_controller.load_card_to_dice(card, card_node)
			_update_new_flow_hud()
		else:
			ui_controller.show_state_message("请先点击一个骰子再打出卡牌", 1.2)
		return
	var node = ui_controller.get_card_node(card) if ui_controller else null
	play_card_with_animation(card, target, node)

func _on_ui_card_cancelled(card: CardData) -> void:
	if pending_card == card:
		pending_card = null
	ui_controller.clear_target_highlights()

func _on_ui_card_dropped(card: CardData, target) -> void:
	if card == null:
		return
	# 打出时确保箭头与目标高亮彻底清理（防止箭头残留）
	if ui_controller:
		ui_controller.drag_arrow.hide_arrow()
		ui_controller.clear_target_highlights()
	var card_node = ui_controller.get_card_node(card) if ui_controller else null
	if target == null:
		if card_node and card_node.has_method("reset_position"):
			card_node.reset_position()
		return
	# 新流程：在PLAYER_SELECT阶段，装载到骰子
	if use_new_flow and state_machine.is_player_select():
		if ui_controller.has_active_dice():
			ui_controller.load_card_to_dice(card, card_node)
			_update_new_flow_hud()
		else:
			if card_node and card_node.has_method("reset_position"):
				card_node.reset_position()
			ui_controller.show_state_message("请先点击一个骰子再打出卡牌", 1.2)
		return
	if card.target_type == "single_enemy" and target is EnemyUnit:
		play_card_with_animation(card, target, card_node)
	elif card.target_type == "single_ally" and target is PlayerManager:
		play_card_with_animation(card, target, card_node)
	else:
		if card_node and card_node.has_method("reset_position"):
			card_node.reset_position()

func play_card_with_animation(card: CardData, target, card_node: Control) -> void:
	# 未显式传入节点时从手牌映射查找（如短按选目标后的 pending_card 流程）
	if card_node == null and ui_controller:
		card_node = ui_controller.get_card_node(card)
	# 从手牌映射摘出节点（不释放），避免结算触发的 hand_changed 重排释放它，节点改由动画接管
	if card_node and ui_controller:
		ui_controller.detach_card_node(card)
	# 第一步：飞向屏幕中央
	if card_node:
		await card_node.fly_to_center()
	# 第二步：结算效果（同步），卡牌悬停在中央；play_card 内部 await 0.3s 即悬停展示时间
	var played: bool = await play_card(card, target)
	if not played:
		# 打牌失败：节点放回手牌并恢复布局
		if card_node:
			if ui_controller:
				ui_controller.reattach_card_node(card, card_node)
			card_node.reset_position()
			ui_controller.ensure_cards_layout_state()
		return
	# 第三步：飞向弃牌堆并消散（弃牌堆计数已在 play_card 结算时同步更新）
	if card_node:
		var discard_pos: Vector2 = ui_controller.get_discard_pile_global_pos() if ui_controller else Vector2(120, card_node.get_viewport_rect().size.y - 288)
		await card_node.fly_to_discard(discard_pos)

func _on_ui_enemy_selected(enemy: EnemyUnit) -> void:
	player_manager.selected_target = enemy
	# 新流程：在PLAYER_SELECT阶段，如果有pending_card，将其队列
	if use_new_flow and state_machine.is_player_select() and pending_card != null:
		_queue_player_card(pending_card, enemy)
		pending_card = null
		ui_controller.clear_target_highlights()
		return
	if pending_card != null:
		play_card_with_animation(pending_card, enemy, null)
		pending_card = null
		ui_controller.clear_target_highlights()

func _on_ui_end_turn_clicked() -> void:
	# 新流程：回合准备阶段（按下"回合准备"→投骰+敌人意图）
	if use_new_flow and state_machine.is_turn_prepare():
		on_turn_prepare_clicked()
		return
	# 新流程：玩家选牌阶段（按下"回合开始"→结算）
	if use_new_flow and state_machine.is_player_select():
		on_turn_start_clicked()
		return
	end_player_turn()

func get_tree():
	return Engine.get_main_loop()
## ==========================================
## B4: 同时出牌+速度排序结算
## ==========================================

## 槽位出牌列表（每回合收集双方所有槽位的出牌）
var _pending_plays: Array = []

## 玩家已队列出牌（PLAYER_SELECT阶段）
var _player_queued_plays: Array = []

## 玩家槽位速度（回合开始掷骰分配）
var _player_slot_speeds: Array = []
## 敌人槽位速度：{enemy_index: [speed_per_slot]}
var _enemy_slot_speeds: Dictionary = {}
## 敌人卡组CardSystem：{enemy_index: CardSystem}
var _enemy_card_systems: Dictionary = {}

## 回合开始时为所有槽位掷速度骰
func _roll_all_speeds() -> void:
	_player_slot_speeds.clear()
	for i in player_manager.slots:
		_player_slot_speeds.append(BattleRules.roll_speed(player_manager.speed))
	_enemy_slot_speeds.clear()
	for enemy_idx in enemy_system.enemies.size():
		var enemy = enemy_system.enemies[enemy_idx]
		if enemy.is_dead:
			continue
		var speeds: Array = []
		for i in enemy.slots:
			speeds.append(BattleRules.roll_speed(enemy.speed))
		_enemy_slot_speeds[enemy_idx] = speeds

## 添加一个槽位出牌到待结算列表
func _add_pending_play(card: CardData, source, target, speed: int, is_player: bool, slot_index: int, enemy_index: int = 0) -> void:
	_pending_plays.append({
		"card": card,
		"source": source,
		"target": target,
		"speed": speed,
		"is_player": is_player,
		"slot_index": slot_index,
		"enemy_index": enemy_index,
	})

## 速度排序结算：按速度↓排序，同速按规则排序，依次执行
func _resolve_all_plays() -> void:
	# 排序：速度↓ → 玩家优先 → 槽位索引↑ → 敌人索引↑
	_pending_plays.sort_custom(_compare_plays)
	# 依次执行
	for play in _pending_plays:
		if _check_battle_end_state():
			break
		var card: CardData = play.card
		var source = play.source
		var target = play.target
		# 检查source是否还存活
		if source is PlayerManager and source.is_dead:
			continue
		if source is EnemyUnit and source.is_dead:
			continue
		# 检查target是否还存活
		if target is EnemyUnit and target.is_dead:
			continue
		if target is PlayerManager and target.is_dead:
			continue
		# 卡牌结算动画（显示卡牌本体+效果，敌我）
		if ui_controller:
			await ui_controller.show_resolve_animation(card, source is PlayerManager, _get_effect_text(card))
		# 执行效果
		effect_resolver.resolve_effects(card.effects, source, target)
		# 打出的牌回牌库
		if source is PlayerManager:
			card_system.play_card(card, target)
		elif source is EnemyUnit:
			var e_idx: int = play.enemy_index
			var e_cs = _enemy_card_systems.get(e_idx)
			if e_cs:
				e_cs.play_card(card, target)
		# 更新UI
		if ui_controller:
			if source is PlayerManager:
				_update_player_ui()
			elif source is EnemyUnit:
				ui_controller.update_single_enemy(source)
	_update_player_ui()
	_pending_plays.clear()
	_enemy_card_systems.clear()

## 排序比较函数：速度↓ → 玩家优先 → 槽位↑ → 敌人索引↑
func _compare_plays(a: Dictionary, b: Dictionary) -> bool:
	# 速度高的在前
	if a.speed != b.speed:
		return a.speed > b.speed
	# 同速：玩家优先
	if a.is_player != b.is_player:
		return a.is_player
	# 同速同方：槽位索引小的在前
	if a.slot_index != b.slot_index:
		return a.slot_index < b.slot_index
	# 同速同方同槽位（敌人）：敌人索引小的在前（从左到右）
	return a.enemy_index < b.enemy_index
## B4: 生成卡牌效果文字（用于结算动画显示）
func _get_effect_text(card: CardData) -> String:
	var parts: Array = []
	for effect in card.effects:
		var et = effect.get("effect_type", "")
		match et:
			"damage":
				parts.append("伤害%d" % effect.get("value", 0))
			"damage_if_debuff":
				parts.append("伤害%d" % effect.get("value", 0))
			"block":
				parts.append("护甲%d" % effect.get("value", 0))
			"heal":
				parts.append("回复%d" % effect.get("value", 0))
			"apply_debuff", "apply_buff":
				parts.append("施加%s" % effect.get("buff_id", ""))
			"draw":
				parts.append("抽牌%d" % effect.get("value", 0))
			"pay_life":
				parts.append("支付生命%d" % effect.get("value", 0))
			_:
				pass
	return ", ".join(parts) if parts.size() > 0 else "生效"
