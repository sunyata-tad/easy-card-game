extends Control

func _ready():
	size = Vector2(1152, 648)
	var scene = load("res://scenes/BattleScene.tscn")
	var battle = scene.instantiate()
	add_child(battle)
	await get_tree().create_timer(0.3).timeout

	if battle.has_method("receive_data"):
		battle.receive_data({"test_mode": true})

	await get_tree().create_timer(2.0).timeout

	var bc = battle.get("battle_controller")
	if bc:
		print("=== Battle State ===")
		print("hand size: ", bc.card_system.hand.size())
		print("is_first_turn: ", bc.is_first_turn)
		print("initial_draw_count: ", bc.rules.initial_draw_count)
		print("turn_draw_count: ", bc.rules.turn_draw_count)
		for i in range(bc.card_system.hand.size()):
			var c = bc.card_system.hand[i]
			print("  card[%d]: %s (cost=%d, tags=%s)" % [i, c.name, c.cost, c.tags])

	var hand_area = battle.get_node_or_null("Background/HandArea")
	if hand_area:
		print("=== HandArea ===")
		print("visible: ", hand_area.visible)
		print("modulate.a: ", hand_area.modulate.a)
		print("children: ", hand_area.get_child_count())

	var img = get_viewport().get_texture().get_image()
	if img:
		img.save_png("user://test_battle_start.png")
		print("Screenshot saved")

	await get_tree().create_timer(0.3).timeout
	get_tree().quit()