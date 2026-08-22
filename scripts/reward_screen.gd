## 战斗奖励场景脚本：挂载到 RewardScreen.tscn 的根 Control 节点上。
## 战斗胜利后显示战果统计，提供"返回地图"按钮。
extends Control

@onready var title_label: Label = $TitleLabel                         ## 标题
@onready var reward_container: VBoxContainer = $ScrollContainer/RewardContainer  ## 奖励内容容器

var _battle_stats: Dictionary = {}  ## 战斗统计数据（由 receive_data 传入）

func _ready():
	_setup_ui()

func receive_data(data: Dictionary) -> void:
	_battle_stats = data.get("battle_stats", {})
	_setup_ui()

func _setup_ui():
	if title_label:
		title_label.text = "战斗胜利!"

	if reward_container == null:
		return

	for child in reward_container.get_children():
		child.queue_free()

	var stats = GameData.get_battle_stats() if GameData else {}

	var stats_label = Label.new()
	stats_label.text = "战果统计"
	stats_label.add_theme_font_size_override("font_size", 16)
	reward_container.add_child(stats_label)

	var hp_info = Label.new()
	hp_info.text = "当前生命: %d / %d" % [stats.get("final_hp", 0), GameData.player_max_hp if GameData else 80]
	reward_container.add_child(hp_info)

	var battle_info = Label.new()
	battle_info.text = "累计胜场: %d" % stats.get("battles_won", 0)
	reward_container.add_child(battle_info)

	reward_container.add_child(HSeparator.new())

	var return_btn = Button.new()
	return_btn.text = "返回地图"
	return_btn.custom_minimum_size = Vector2(200, 40)
	return_btn.pressed.connect(_on_return_to_map)
	reward_container.add_child(return_btn)
	UIStyle.attach_button_anim(return_btn)

## 保存地图状态并返回地图
func _on_return_to_map():
	SaveManager.save_map_state()
	var cached_state = SaveManager.get_cached_map_state()
	GameManager.go_to_map("test_map", cached_state)