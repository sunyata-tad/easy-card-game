## 游戏结束场景脚本：挂载到 GameOverScreen.tscn 的根 Control 节点上。
## 显示战斗统计（胜利场次、总伤害、使用卡牌数等），提供"重新开始"和"退出"按钮。
extends Control

var game_stats: Dictionary = {}  ## 由 receive_data 传入的战斗统计数据

@onready var title_label: Label = $TitleLabel          ## 标题（胜利/失败）
@onready var stats_label: Label = $StatsLabel          ## 统计数据文字
@onready var restart_button: Button = $RestartButton   ## 重新开始按钮
@onready var quit_button: Button = $QuitButton         ## 退出按钮

## 接收 GameManager.change_scene 传入的数据
func receive_data(data: Dictionary) -> void:
	game_stats = data.get("stats", {})

func _ready():
	_setup_ui()
	_connect_buttons()

func _connect_buttons():
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

## 根据传入的统计数据更新 UI 显示
func _setup_ui():
	if title_label:
		var is_victory = game_stats.get("victory", false)
		title_label.text = "游戏胜利!" if is_victory else "游戏结束"

	if stats_label:
		var stats_text = "游戏统计:\n"
		stats_text += "胜利场次: %d\n" % game_stats.get("battles_won", 0)
		stats_text += "总伤害: %d\n" % game_stats.get("total_damage", 0)
		stats_text += "使用卡牌: %d\n" % game_stats.get("cards_played", 0)
		stats_text += "最终HP: %d / %d" % [game_stats.get("final_hp", 0), game_stats.get("max_hp", 80)]
		stats_label.text = stats_text

## 重新开始：初始化新 run 并回到主菜单
func _on_restart_pressed() -> void:
	GameData.initialize_new_run()
	GameManager.go_to_main_menu()

func _on_quit_pressed() -> void:
	get_tree().quit()