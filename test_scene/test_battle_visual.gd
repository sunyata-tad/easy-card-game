## 战斗可视化测试：直接启动战斗场景并截图
## 验证新流程UI是否正确显示（能量/槽位/速度/手牌/敌人意图）
extends Control

var _screenshot_path := "user://battle_screenshot.png"
var _phase := 0
var _elapsed := 0.0
var _battle_scene = null

func _ready() -> void:
	# 初始化游戏数据
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5
	GameData.player_max_hp = 80
	GameData.player_current_hp = 80
	CardPoolManager.unlock_all_cards()
	var card_db := CardDatabase.new()
	GameData.player_deck = card_db.create_deck([
		{"card_id": "斩击", "count": 2},
		{"card_id": "格挡", "count": 2},
		{"card_id": "重斩", "count": 1},
		{"card_id": "铁壁", "count": 1},
		{"card_id": "攻守兼备", "count": 2},
		{"card_id": "烈斩", "count": 1}
	])
	
	# 延迟加载战斗场景（避免add_child冲突）
	call_deferred("_setup_battle")

func _setup_battle() -> void:
	# 加载战斗场景
	_battle_scene = load("res://scenes/BattleScene.tscn").instantiate()
	get_tree().root.add_child(_battle_scene)
	
	# 获取敌人并启动战斗
	var enemy_db := EnemyDatabase.new()
	var enemy := enemy_db.get_enemy("腐化法师")
	
	# 延迟调用receive_data（等待场景树完成设置）
	call_deferred("_init_battle", enemy)

func _init_battle(enemy) -> void:
	if _battle_scene and is_instance_valid(_battle_scene):
		if _battle_scene.has_method("receive_data"):
			_battle_scene.receive_data({"enemies": [enemy], "test_mode": true})
		print("Battle scene loaded")
	_phase = 0

func _process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		0:  # 等待战斗初始化完成
			if _elapsed > 3.0:
				_take_screenshot()
				_phase = 1
				_elapsed = 0.0
		1:  # 等待一秒后退出
			if _elapsed > 2.0:
				print("Test complete")
				get_tree().quit()

func _take_screenshot() -> void:
	# 等待两帧确保渲染完成
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	if img:
		img.save_png(_screenshot_path)
		print("Screenshot saved to: " + _screenshot_path)
	else:
		print("ERROR: Failed to get viewport image")