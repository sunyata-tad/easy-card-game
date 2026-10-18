## 验证 CardInfoBox 数据加载无报错
extends Node

func _ready() -> void:
	print("[INFOBOX-TEST] 开始测试")
	GameData.initialize_new_run()
	var card_db := CardDatabase.new()
	var deck := card_db.create_deck([{"card_id": "必然杀", "count": 1}])
	if deck.is_empty():
		print("[INFOBOX-TEST] FAIL: 未创建卡牌")
		get_tree().quit(1)
		return
	_test_card(deck[0])
	deck = card_db.create_deck([{"card_id": "批命", "count": 1}])
	_test_card(deck[0])
	deck = card_db.create_deck([{"card_id": "薄葬", "count": 1}])
	_test_card(deck[0])

	print("[INFOBOX-TEST] 测试完成")
	get_tree().quit(0)

func _test_card(card: CardData) -> void:
	print("[INFOBOX-TEST] --- 卡牌: ", card.id, " tags=", card.tags)
	var has := CardInfoBox.has_info(card)
	print("[INFOBOX-TEST] has_info=", has)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	var ok := CardInfoBox.fill_info_container(vbox, card, 12)
	print("[INFOBOX-TEST] fill_info_container 返回=", ok, " 子节点数=", vbox.get_child_count())
	for i in vbox.get_child_count():
		var c = vbox.get_child(i)
		if c is RichTextLabel:
			print("[INFOBOX-TEST] 子[", i, "] text=", c.text)
	vbox.queue_free()