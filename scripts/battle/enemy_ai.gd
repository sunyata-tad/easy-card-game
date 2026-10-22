## 敌人出牌AI：决定敌人每个槽位出什么牌
## 简单规则AI：根据策略标签选择出牌
class_name EnemyAI

## 为敌人决定每个槽位的出牌
## 返回数组：[{card, target, slot_index}, ...]
static func decide_plays(enemy: EnemyUnit, card_system: CardSystem, player_manager: PlayerManager, enemies: Array) -> Array:
	var plays: Array = []
	var hand = card_system.get_hand()
	if hand.is_empty():
		return plays
	var available_energy = enemy.energy
	var slots_used = 0
	for slot_index in enemy.slots:
		if slots_used >= enemy.slots:
			break
		var best_card = _pick_best_card(hand, enemy, available_energy, enemy.data)
		if best_card == null:
			break
		var target = _pick_target(best_card, enemy, player_manager, enemies)
		plays.append({"card": best_card, "target": target, "slot_index": slot_index})
		available_energy -= best_card.cost
		slots_used += 1
		hand.erase(best_card)
	return plays

## 根据AI策略选择最优卡牌
static func _pick_best_card(hand: Array, enemy: EnemyUnit, available_energy: int, enemy_data) -> CardData:
	var ai_type = "aggressive"
	if enemy_data and enemy_data is EnemyData:
		ai_type = enemy_data.ai_type if enemy_data.ai_type != "" else "aggressive"
	var affordable: Array = []
	for card in hand:
		if card.cost <= available_energy:
			affordable.append(card)
	if affordable.is_empty():
		return null
	match ai_type:
		"aggressive":
			return _pick_aggressive(affordable)
		"defensive":
			return _pick_defensive(affordable, enemy)
		_:
			return _pick_balanced(affordable, enemy)

## 激进策略：优先攻击牌，选伤害最高的
static func _pick_aggressive(cards: Array) -> CardData:
	var best = null
	var best_score = -1
	for card in cards:
		var score = _score_attack(card)
		if score > best_score:
			best_score = score
			best = card
	return best

## 防御策略：低血优先防御牌，高血可以攻击
static func _pick_defensive(cards: Array, enemy: EnemyUnit) -> CardData:
	var hp_ratio = float(enemy.current_hp) / float(enemy.max_hp)
	if hp_ratio < 0.5:
		var best = null
		var best_score = -1
		for card in cards:
			var score = _score_defense(card)
			if score > best_score:
				best_score = score
				best = card
		if best and best_score > 0:
			return best
	return _pick_balanced(cards, enemy)

## 均衡策略：根据当前状态选择
static func _pick_balanced(cards: Array, enemy: EnemyUnit) -> CardData:
	var hp_ratio = float(enemy.current_hp) / float(enemy.max_hp)
	if hp_ratio < 0.3:
		for card in cards:
			if _score_defense(card) > 0:
				return card
	var best = null
	var best_score = -1
	for card in cards:
		var score = _score_attack(card) + _score_defense(card)
		if score > best_score:
			best_score = score
			best = card
	return best if best else cards[0]

## 评估攻击价值
static func _score_attack(card: CardData) -> float:
	for effect in card.effects:
		if effect.get("effect_type") == "damage":
			return float(effect.get("value", 0))
		if effect.get("effect_type") == "damage_if_debuff":
			return float(effect.get("value", 0)) + float(effect.get("bonus_value", 0)) * 0.5
	return 0.0

## 评估防御价值
static func _score_defense(card: CardData) -> float:
	for effect in card.effects:
		if effect.get("effect_type") == "block":
			return float(effect.get("value", 0))
	return 0.0

## 选择目标
static func _pick_target(card: CardData, enemy: EnemyUnit, player_manager: PlayerManager, enemies: Array) -> Variant:
	if card.target_type == "self":
		return enemy
	if card.target_type == "single_enemy":
		return player_manager
	return player_manager