## 直接测试B4-B5：EnemyAI+速度排序结算
extends Node

func _log(f: FileAccess, msg: String) -> void:
	if f: f.store_line(msg)

func _ready() -> void:
	var f := FileAccess.open("user://test_b45_direct_log.txt", FileAccess.WRITE)
	_log(f, "=== B4-B5 直接测试 ===")
	var EnemyAIClass = load("res://scripts/battle/enemy_ai.gd")
	
	var enemy_db := EnemyDatabase.new()
	var ed := enemy_db.get_enemy("腐化法师")
	var enemy := EnemyUnit.new(ed)
	enemy.energy = 3
	enemy.max_energy = 3
	enemy.slots = 1
	enemy.speed = 1
	_log(f, "敌人: %s HP=%d energy=%d slots=%d speed=%d" % [ed.name, enemy.current_hp, enemy.energy, enemy.slots, enemy.speed])
	
	var db := CardDatabase.new()
	var deck := db.create_deck([
		{"card_id": "斩击", "count": 2}, {"card_id": "格挡", "count": 2},
		{"card_id": "重斩", "count": 1}, {"card_id": "铁壁", "count": 1},
		{"card_id": "攻守兼备", "count": 2}, {"card_id": "烈斩", "count": 1}
	])
	var cs := CardSystem.new()
	cs.initialize_deck(deck)
	cs.draw_cards(5)
	_log(f, "敌人手牌: %d" % cs.get_hand().size())
	for card in cs.get_hand():
		_log(f, "  %s cost=%d" % [card.name, card.cost])
	
	var pm := PlayerManager.new(80)
	var plays = EnemyAIClass.decide_plays(enemy, cs, pm, [enemy])
	_log(f, "AI决定出牌: %d张" % plays.size())
	for p in plays:
		_log(f, "  槽位%d: %s cost=%d" % [p.slot_index, p.card.name, p.card.cost])
	
	_log(f, "--- 速度排序测试 ---")
	var pending: Array = []
	for i in pm.slots:
		var spd := BattleRules.roll_speed(pm.speed)
		pending.append({"card": "玩家卡%d" % i, "speed": spd, "is_player": true, "slot_index": i, "enemy_index": 0})
	for i in enemy.slots:
		var spd := BattleRules.roll_speed(enemy.speed)
		pending.append({"card": "敌人卡%d" % i, "speed": spd, "is_player": false, "slot_index": i, "enemy_index": 0})
	_log(f, "排序前: %s" % str(pending))
	pending.sort_custom(func(a, b):
		if a.speed != b.speed: return a.speed > b.speed
		if a.is_player != b.is_player: return a.is_player
		if a.slot_index != b.slot_index: return a.slot_index < b.slot_index
		return a.enemy_index < b.enemy_index
	)
	_log(f, "排序后: %s" % str(pending))
	
	_log(f, "--- 能量系统测试 ---")
	_log(f, "玩家能量: %d/%d" % [pm.energy, pm.max_energy])
	pm.spend_energy(3)
	_log(f, "消耗3后: %d" % pm.energy)
	pm.regen_energy()
	_log(f, "恢复后: %d" % pm.energy)
	
	_log(f, "=== 测试完成 ===")
	f.close()
	get_tree().quit()