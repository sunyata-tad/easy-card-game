## 游戏场景管理器：全局单例，负责场景切换（主菜单/地图/战斗/奖励/结束）和流程控制。
## Godot 特色：
## - enum 定义枚举类型
## - const SCENES := { key: "path" } 定义场景路径映射表（:= 是类型推断运算符）
## - get_tree().root 获取场景树的根节点
## - queue_free() 安全地删除节点（在本帧结束后释放）
## - signal 声明信号，.emit() 发射信号
extends Node

## 游戏场景枚举
enum GameScene {
	MAIN_MENU,         ## 主菜单
	CHARACTER_SELECT,  ## 角色选择
	CHARACTER_CREATION,## 角色创建
	MAP,               ## 地图
	BATTLE,            ## 战斗
	REWARD,            ## 奖励
	GAME_OVER          ## 游戏结束
}

## 场景路径映射表
const SCENES := {
	GameScene.MAIN_MENU: "res://scenes/start.tscn",
	GameScene.CHARACTER_SELECT: "res://scenes/CharacterSelectScreen.tscn",
	GameScene.CHARACTER_CREATION: "res://scenes/CharacterCreationScreen.tscn",
	GameScene.MAP: "res://scenes/MapScreen.tscn",
	GameScene.BATTLE: "res://scenes/BattleScene.tscn",
	GameScene.REWARD: "res://scenes/RewardScreen.tscn",
	GameScene.GAME_OVER: "res://scenes/GameOverScreen.tscn"
}

var current_scene: Node = null          ## 当前活跃的场景节点
var previous_scene_type: int = -1       ## 上一个场景类型
var current_scene_type: int = -1        ## 当前场景类型

signal scene_changed(scene_type: int)    ## 场景切换信号
signal battle_started()                 ## 战斗开始
signal battle_ended(victory: bool)       ## 战斗结束

func _ready():
	# 设置为始终运行模式，确保场景切换时不会被暂停
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root = get_tree().root
	# 获取根节点的最后一个子节点（即当前场景）
	current_scene = root.get_child(root.get_child_count() - 1)
	current_scene_type = GameScene.MAIN_MENU

## 核心场景切换方法
## @param scene_type: 目标场景类型
## @param data: 传递给新场景的数据字典
func change_scene(scene_type: int, data: Dictionary = {}) -> void:
	if not SCENES.has(scene_type):
		push_error("GameManager: Invalid scene type: %d" % scene_type)
		return

	previous_scene_type = current_scene_type
	current_scene_type = scene_type

	# 加载场景资源 → 实例化 → 替换当前场景
	var scene_path = SCENES[scene_type]
	var scene_resource = load(scene_path)
	var new_scene = scene_resource.instantiate()

	if current_scene:
		current_scene.queue_free()

	get_tree().root.add_child(new_scene)
	current_scene = new_scene

	# 如果传入了数据，通过 receive_data 方法传递
	if data.size() > 0:
		_notify_scene_data(new_scene, data)

	scene_changed.emit(scene_type)

## 通知新场景接收数据（调用 receive_data 方法）
## has_method("receive_data") 是 GDScript 的鸭子类型检查
func _notify_scene_data(scene: Node, data: Dictionary) -> void:
	if scene.has_method("receive_data"):
		scene.receive_data(data)

## 快捷跳转方法
func go_to_main_menu() -> void:
	change_scene(GameScene.MAIN_MENU)

func go_to_character_select() -> void:
	change_scene(GameScene.CHARACTER_SELECT)

func go_to_character_creation() -> void:
	change_scene(GameScene.CHARACTER_CREATION)

## 跳转到无尽地图模式
## @param map_state: 可选，恢复地图状态（用于继续游戏）
func go_to_endless_map(map_state: Dictionary = {}) -> void:
	var data: Dictionary = {"map_id": "endless", "endless_mode": true}
	if not map_state.is_empty():
		data["map_state"] = map_state
	change_scene(GameScene.MAP, data)

## 测试地图：预设测试楼层（普通战斗、精英战斗、测试台），不使用存档
## 测试牌组：20 张蓄势（每张抽 2 张），用于触发手牌超上限，测试弃牌阶段
func go_to_test_map() -> void:
	GameData.initialize_new_run()
	GameData.player_strength = 5
	GameData.player_dexterity = 5
	var card_db = CardDatabase.new()
	GameData.player_deck = card_db.create_deck([
		{"card_id": "蓄势", "count": 20}
	])
	var data: Dictionary = {"map_id": "test", "test_mode": true}
	change_scene(GameScene.MAP, data)

## 测试战斗：创建一个测试假人敌人，用预设牌组进入战斗（保留兼容）
func go_to_test_battle() -> void:
	var enemy_db = EnemyDatabase.new()
	var enemy = enemy_db.get_enemy("test_dummy")
	if enemy:
		GameData.initialize_new_run()
		GameData.player_strength = 5
		GameData.player_dexterity = 5
		var card_db = CardDatabase.new()
		GameData.player_deck = card_db.create_deck([
			{"card_id": "蓄势", "count": 20}
		])
		start_battle([enemy])

func go_to_map(map_id: String = "test_map", map_state: Dictionary = {}) -> void:
	var data: Dictionary = {"map_id": map_id}
	if not map_state.is_empty():
		data["map_state"] = map_state
	change_scene(GameScene.MAP, data)

## 开始战斗（传入敌人列表）
func start_battle(enemies: Array = []) -> void:
	var data = {"enemies": enemies}
	change_scene(GameScene.BATTLE, data)
	battle_started.emit()

## 战斗结束处理
func end_battle(victory: bool, battle_stats: Dictionary = {}) -> void:
	battle_ended.emit(victory)
	if victory:
		go_to_reward(battle_stats)
	else:
		var stats = GameData.get_battle_stats() if GameData else {}
		stats.victory = false
		go_to_game_over(stats)

func go_to_reward(battle_stats: Dictionary = {}) -> void:
	var data: Dictionary = {"battle_stats": battle_stats}
	change_scene(GameScene.REWARD, data)

func go_to_game_over(stats: Dictionary = {}) -> void:
	var data = {"stats": stats}
	change_scene(GameScene.GAME_OVER, data)

func restart_game() -> void:
	go_to_main_menu()

func get_current_scene_type() -> int:
	return current_scene_type

func is_in_battle() -> bool:
	return current_scene_type == GameScene.BATTLE