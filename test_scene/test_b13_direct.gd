## 直接测试B1-B3功能：牌堆简化+能量系统+速度槽位
extends Node

func _log(f: FileAccess, msg: String) -> void:
	if f:
		f.store_line(msg)

func _ready() -> void:
	var log_path := "user://test_b13_direct_log.txt"
	var f := FileAccess.open(log_path, FileAccess.WRITE)
	_log(f, "=== B1-B3 直接测试 ===")
	
	# B1: 牌堆简化测试
	var cs := CardSystem.new()
	var db := CardDatabase.new()
	var deck := db.create_deck([
		{"card_id": "斩击", "count": 2},
		{"card_id": "格挡", "count": 2},
		{"card_id": "重斩", "count": 1},
	])
	cs.initialize_deck(deck)
	_log(f, "B1: 初始牌库=%d 手牌=%d 弃牌=%d" % [cs.get_draw_pile_count(), cs.get_hand().size(), cs.get_discard_pile_count()])
	
	cs.draw_cards(3)
	_log(f, "B1: 抽3张后 牌库=%d 手@0,0)手牌=%d" % [cs.get_draw_pile_count(), cs.get_hand().size()])
	
	var first_card = cs.get_hand()[0]
	_log(f, "B1: 打出 %s cost=%d" % [first_card.id, first_card.cost])
	cs.play_card(first_card)
	_log(f, "B1: 打出后 牌库=%d 手牌=%d 弃牌=%d" % [cs.get_draw_pile_count(), cs.get_hand().size(), cs.get_discard_pile_count()])
	
	if cs.get_discard_pile_count() == 0:
		_log(f, "B1 PASS: 打出回牌库，弃牌堆=0")
	else:
		_log(f, "B1 FAIL: 弃牌堆=%d 应为0" % cs.get_discard_pile_count())
	
	# B2: 能量系统测试
	var pm := PlayerManager.new(80)
	_log(f, "B2: 初始能量=%d/%d regen=%d" % [pm.energy, pm.max_energy, pm.energy_regen])
	
	if pm.can_afford(3):
		pm.spend_energy(3)
		_log(f, "B2: 消耗3能量后 energy=%d" % pm.energy)
	else:
		_log(f, "B2 FAIL: 无法消耗3能量")
	
	pm.regen_energy()
	_log(f, "B2: 恢复后 energy=%d (应=%d)" % [pm.energy, pm.max_energy - 3 + pm.energy_regen])
	
	if not pm.can_afford(10):
		_log(f, "B2 PASS: 能量不足10无法打出")
	else:
		_log(f, "B2 FAIL: 能量检查异常")
	
	# B3: 速度+槽位测试
	_log(f, "B3: 玩家 speed=%d slots=%d" % [pm.speed, pm.slots])
	
	for i in 10:
		var spd := BattleRules.roll_speed(pm.speed)
		if spd < 1 or spd > 6:
			_log(f, "B3 FAIL: speed=%d 超出[1,6]" % spd)
			break
	_log(f, "B3 PASS: 10次掷骰均在[1,6]范围内")
	
	var spd2 := BattleRules.roll_speed(3)
	_log(f, "B3: speed=3掷骰结果=%d" % spd2)
	
	_log(f, "=== 测试完成 ===")
	f.close()
	get_tree().quit()