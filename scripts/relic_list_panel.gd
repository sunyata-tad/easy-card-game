## 通用"持有遗物"面板：可滚动的遗物列表 + 悬浮查看详细效果。
## 用于战斗内遗物弹窗、地图遗物查看等场景（适配任意数量的遗物）。
## 用法：实例化 RelicListPanel.tscn → add 到弹窗 → setup(relics)。
extends PanelContainer

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var list_container: VBoxContainer = $Margin/VBox/HBox/Scroll/List
@onready var detail_label: Label = $Margin/VBox/HBox/DetailLabel

## 直接填充 RelicData 数组
func setup(relics: Array) -> void:
	_clear_list()
	title_label.text = "持有遗物（%d）" % relics.size()
	if relics.is_empty():
		title_label.text = "持有遗物"
		detail_label.text = "当前没有遗物。"
		var empty := Label.new()
		empty.text = "（无）"
		empty.add_theme_color_override("font_color", Color(0.62, 0.62, 0.75))
		list_container.add_child(empty)
		return
	for relic in relics:
		var row := Button.new()
		row.text = relic.name
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.mouse_entered.connect(_on_hover.bind(relic))
		list_container.add_child(row)
	# 默认展示第一个
	_on_hover(relics[0])

func _clear_list() -> void:
	for child in list_container.get_children():
		list_container.remove_child(child)
		child.free()

func _on_hover(relic) -> void:
	if relic == null:
		return
	var flavor := ""
	if not relic.flavor_text.is_empty():
		flavor = "\n—— %s ——" % relic.flavor_text
	detail_label.text = "%s\n\n%s%s" % [relic.name, relic.description, flavor]
