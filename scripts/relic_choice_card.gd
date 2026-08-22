## 遗物三选一卡片：展示单件遗物并允许选择。
## 由 RelicRewardScreen 实例化后调用 setup(relic) 填充内容。
extends PanelContainer

signal picked(relic)

var _relic: RelicData = null

func _ready():
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)

## 填充遗物数据并连接选择按钮
func setup(relic: RelicData) -> void:
	_relic = relic
	$Margin/VBox/NameLabel.text = relic.name
	$Margin/VBox/DescLabel.text = relic.description
	if relic.flavor_text.is_empty():
		$Margin/VBox/FlavorLabel.visible = false
	else:
		$Margin/VBox/FlavorLabel.visible = true
		$Margin/VBox/FlavorLabel.text = "—— %s ——" % relic.flavor_text
	$Margin/VBox/PickButton.pressed.connect(_on_pick_pressed)
	UIStyle.attach_button_anim($Margin/VBox/PickButton)

func _on_pick_pressed() -> void:
	if _relic:
		picked.emit(_relic)

func _on_hover_enter() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.05, 1.05), 0.12)

func _on_hover_exit() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)
