## 战斗 UI 控制器：管理所有战斗界面的显示和交互（手牌布局、拖拽、目标选择、伤害数字、buff 显示等）。
## Godot 特色：
## - PackedScene 是可实例化的场景资源（类似 Unity 的 Prefab）
## - Control 是所有 UI 元素的基类，HBoxContainer / VBoxContainer 是布局容器
## - static var 是类级别变量（类似 Python 的类变量 / Java 的 static 字段），所有实例共享
## - create_tween() 创建动画插值对象，用于平滑过渡效果
## - %s % [args] 格式化字符串（类似 Python 的 %-format）
## - .call_deferred() 延迟到下一帧执行（确保节点树已就绪）
## - is_instance_valid(node) 检查节点是否仍有效（未被 queue_free 释放）
class_name UIController

var root_node: Control              ## 战斗场景的根节点
var card_scene: PackedScene         ## 卡牌 UI 场景（Card.tscn）
var player_manager: PlayerManager = null  ## 玩家状态引用

## UI 节点引用（从场景中查找获取）
var hand_container: Node       ## 手牌区域的容器节点
var enemy_container: Node      ## 敌人区域的容器节点
var player_area: Node          ## 玩家区域节点
var end_turn_button: Button    ## 结束回合按钮
var deck_info_node: Node       ## 牌堆信息节点
var state_display_label: Label = null  ## 状态提示文字（淡出效果）
var target_button: Button = null       ## 选择攻击目标按钮
var target_marker: Control = null      ## 目标标记 UI

## 玩家信息面板
var _player_stats_panel: HBoxContainer = null  ## 属性统计面板
var _player_buff_bar: HBoxContainer = null     ## buff 图标栏
var drag_arrow: DragArrow = null               ## 拖拽箭头

## 全局 buff 数据库缓存（从 JSON 加载一次，所有 UIController 实例共享）
static var _buff_db: Dictionary = {}

## 卡牌选择模式相关（用于"选择 X 张卡牌"类型的效果）
var _card_select_active: bool = false        ## 是否处于卡牌选择模式
var _card_select_min: int = 0               ## 最少选择数量
var _card_select_max: int = 1               ## 最多选择数量
var _card_selected_cards: Array = []        ## 已选中的卡牌列表
var _card_select_staging: Control = null    ## 选择模式 UI 容器
var _card_select_confirm_btn: Button = null ## 确认按钮
var _card_select_info_label: Label = null   ## 提示文字
var _card_select_callback: Callable = Callable()  ## 选择完成后的回调

signal card_select_confirmed(selected_cards: Array)  ## 卡牌选择已确认

## 拖拽状态
var is_dragging: bool = false             ## 是否正在拖拽
var dragging_card: CardData = null        ## 正在拖拽的卡牌
var drag_card_node: Control = null        ## 拖拽中卡牌的 UI 节点
var last_hand: Array = []                 ## 上一次的手牌列表（用于恢复布局）
var is_selecting_target: bool = false     ## 是否正在选择攻击目标

## 当前手牌 UI 节点映射 { CardData: Control }
var current_hand_cards: Dictionary = {}
## 当前敌人 UI 节点映射 { EnemyUnit: Control }
var current_enemy_nodes: Dictionary = {}
var selected_target = null          ## 当前选中的目标
var current_target_index: int = 0  ## 当前目标索引

## 交互信号
signal card_clicked(card: CardData, card_node: Control)  ## 卡牌被点击
signal card_released(card: CardData, card_node: Control) ## 卡牌被释放
signal card_cancelled(card: CardData)                    ## 卡牌操作取消
signal card_dropped(card: CardData, target)              ## 卡牌被拖放到目标上
signal card_played(card: CardData, target)               ## 卡牌被打出
signal enemy_selected(enemy: EnemyUnit)                  ## 敌人被选中
signal end_turn_clicked()                                ## 结束回合按钮被点击
signal attack_target_selected(enemy: EnemyUnit)          ## 攻击目标被选中
signal discard_attack_requested()                        ## 请求发起弃牌攻击（点击"攻击"按钮）

## 构造函数：接收战斗场景的根节点，初始化所有 UI
func _init(root: Control):
	root_node = root
	_find_ui_nodes()
	_setup_signals()
	_load_card_scene()
	_setup_state_display()
	_setup_drag_arrow()
	_setup_target_button()
	_setup_target_marker()

## 创建状态显示标签（用于浮动提示文字）
func _setup_state_display() -> void:
	state_display_label = Label.new()
	state_display_label.name = "StateDisplay"
	state_display_label.add_theme_font_size_override("font_size", 32)
	state_display_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	state_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_display_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_display_label.set_anchors_preset(Control.PRESET_CENTER)
	state_display_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	state_display_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	state_display_label.visible = false
	root_node.add_child(state_display_label)

## 创建拖拽箭头 UI
func _setup_drag_arrow() -> void:
	drag_arrow = DragArrow.new()
	drag_arrow.name = "DragArrow"
	root_node.add_child(drag_arrow)

## 创建攻击目标选择按钮（放在结束回合按钮上方）
func _setup_target_button() -> void:
	if end_turn_button == null:
		return
	
	target_button = Button.new()
	target_button.name = "TargetButton"
	target_button.text = "普通攻击"
	target_button.custom_minimum_size = Vector2(120, 40)
	
	var button_pos = end_turn_button.position
	target_button.position = Vector2(button_pos.x, button_pos.y - 50)
	
	target_button.pressed.connect(_on_target_button_pressed)
	root_node.add_child(target_button)

## 创建目标标记 UI（使用 target_marker.gd 脚本）
## set_script 动态给 Control 节点附加脚本（类似 Python 的运行时添加方法）
func _setup_target_marker() -> void:
	target_marker = Control.new()
	target_marker.name = "TargetMarker"
	target_marker.set_script(load("res://scripts/ui/target_marker.gd"))
	root_node.add_child(target_marker)

## 点击"攻击"按钮：发起弃牌攻击；若已在选目标阶段则取消
func _on_target_button_pressed() -> void:
	if _card_select_active:
		return
	if is_selecting_target:
		cancel_target_selection()
	else:
		discard_attack_requested.emit()

## 进入目标选择模式
func start_target_selection() -> void:
	is_selecting_target = true
	highlight_all_enemies()
	drag_arrow.show_arrow()
	
	if target_button:
		target_button.text = "取消选择"
	
	show_state_message("请选择攻击目标", 1.0)

## 取消目标选择模式
func cancel_target_selection() -> void:
	is_selecting_target = false
	clear_target_highlights()
	drag_arrow.hide_arrow()
	
	if target_button:
		target_button.text = "普通攻击"
	
	show_state_message("已取消", 0.5)

## 高亮所有敌人
func highlight_all_enemies() -> void:
	for enemy in current_enemy_nodes:
		var enemy_node = current_enemy_nodes[enemy]
		if enemy_node.has_method("set_highlight_for_target"):
			enemy_node.set_highlight_for_target(true)

## 确认选择攻击目标
func select_attack_target(enemy: EnemyUnit) -> void:
	if not is_selecting_target:
		return
	
	var index = 0
	var enemies = current_enemy_nodes.keys()
	for i in range(enemies.size()):
		if enemies[i] == enemy:
			index = i
			break
	
	current_target_index = index
	if player_manager:
		player_manager.set_selected_target(index)
	
	is_selecting_target = false
	clear_target_highlights()
	drag_arrow.hide_arrow()
	
	if target_button:
		target_button.text = "普通攻击"
	
	update_target_marker(enemy)
	attack_target_selected.emit(enemy)
	show_state_message("已选择目标", 0.5)

## 更新目标标记位置
func update_target_marker(enemy: EnemyUnit) -> void:
	if target_marker == null:
		return
	
	var enemy_node = current_enemy_nodes.get(enemy)
	if enemy_node:
		if target_marker.has_method("set_target"):
			target_marker.call("set_target", enemy_node)

## 清除目标标记
func clear_target_marker() -> void:
	if target_marker and target_marker.has_method("clear"):
		target_marker.call("clear")

var _state_tween: Tween = null

func show_state_message(message: String, duration: float = 1.0) -> void:
	if state_display_label == null:
		return
	
	if _state_tween and _state_tween.is_valid():
		_state_tween.kill()
	
	state_display_label.text = message
	state_display_label.visible = true
	state_display_label.modulate = Color(1, 1, 1, 0)
	
	var fade_in = 0.2
	var stay = duration
	var fade_out = 0.3
	
	_state_tween = root_node.create_tween()
	_state_tween.tween_property(state_display_label, "modulate:a", 1.0, fade_in)
	_state_tween.tween_interval(stay)
	_state_tween.tween_property(state_display_label, "modulate:a", 0.0, fade_out)
	_state_tween.tween_callback(func(): state_display_label.visible = false)

func show_turn_banner(text: String) -> void:
	var banner = Label.new()
	banner.text = text
	banner.add_theme_font_size_override("font_size", 36)
	banner.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.z_index = 200
	banner.modulate = Color(1, 1, 1, 0)
	root_node.add_child(banner)
	
	var tween = root_node.create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.3)
	tween.tween_interval(0.5)
	tween.tween_property(banner, "modulate:a", 0.0, 0.3)
	tween.tween_callback(banner.queue_free)

func _find_ui_nodes() -> void:
	hand_container = root_node.get_node_or_null("Background/HandArea")
	enemy_container = root_node.get_node_or_null("Background/EnemyArea")
	player_area = root_node.get_node_or_null("Background/PlayerArea")
	end_turn_button = root_node.get_node_or_null("EndTurnButton")
	deck_info_node = root_node.get_node_or_null("DeckInfo")
	
	if player_area:
		player_area.gui_input.connect(_on_player_area_input)
		_create_player_info_panels()

func _setup_signals() -> void:
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)

func _load_card_scene() -> void:
	card_scene = load("res://scenes/Card.tscn")

func update_hand_display(hand: Array) -> void:
	last_hand = hand.duplicate()
	var hand_size = hand.size()
	if hand_size == 0:
		_clear_hand()
		return
	
	# 计算可用容器宽度（防止未就绪时算出负值）
	var container_width: float = 800.0
	if hand_container and hand_container.get_parent():
		var parent_width = hand_container.get_parent().size.x
		if parent_width > 0:
			container_width = maxf(parent_width - hand_container.position.x - 50.0, 100.0)
	
	# 先移除已不在手牌的卡牌节点
	for card in current_hand_cards.keys():
		if not hand.has(card):
			var node = current_hand_cards[card]
			node.queue_free()
			current_hand_cards.erase(card)
	
	# 确定性布局：按实际手牌数量一次性计算位置并立即生效，
	# 避免增量 tween 在连续 hand_changed（如抽 2 张只抽到 1 张）时产生位置残留/错乱
	for i in hand_size:
		var card = hand[i]
		var layout = HandLayoutPresets.get_card_position(i, hand_size, container_width)
		
		var card_node = current_hand_cards.get(card)
		if card_node == null:
			card_node = _create_card_node(card)
			if card_node == null:
				continue
			hand_container.add_child(card_node)
			current_hand_cards[card] = card_node
			_setup_card_interaction(card_node, card)
		
		# 拖拽中 / 选目标中的卡牌保持原状，不参与重排
		if (card_node.has_method("is_in_target_mode") and card_node.is_in_target_mode()) or (card_node.has_method("is_dragging_card") and card_node.is_dragging_card()):
			continue
		
		# 位置立即到位（不用增量 tween），并同步原始位置参考供动画还原
		card_node.position = layout.position
		card_node.rotation_degrees = layout.rotation
		card_node.modulate.a = 1.0
		if card_node.has_method("set_original_position"):
			card_node.call("set_original_position", layout.position)
		if "original_rotation" in card_node:
			card_node.original_rotation = layout.rotation

func _clear_hand() -> void:
	for card_node in current_hand_cards.values():
		card_node.queue_free()
	current_hand_cards.clear()

func _create_card_node(card: CardData) -> Control:
	if card_scene == null:
		return null
	
	var card_node = card_scene.instantiate() as Control
	
	if card_node.has_method("setup"):
		card_node.setup(card, player_manager)
		card_node.card_clicked.connect(_on_card_ui_clicked)
	else:
		var name_label = card_node.get_node_or_null("NameLabel")
		var desc_label = card_node.get_node_or_null("DescLabel")
		var type_label = card_node.get_node_or_null("TypeLabel")
		
		if name_label:
			name_label.text = card.name
		if desc_label:
			desc_label.text = card.get_description_text()
		if type_label:
			type_label.text = _get_type_text(card.type)
	
	return card_node

func _get_type_text(type: String) -> String:
	match type:
		"attack": return "攻击"
		"skill": return "技能"
		"power": return "能力"
		_: return ""

func _setup_card_interaction(card_node: Control, card: CardData) -> void:
	if card_node.has_signal("drag_started"):
		card_node.drag_started.connect(_on_card_drag_started.bind(card_node))
		card_node.drag_updated.connect(_on_card_drag_updated)
		card_node.drag_ended.connect(_on_card_drag_ended)
	if card_node.has_signal("card_released"):
		card_node.card_released.connect(_on_card_released.bind(card_node))
	if card_node.has_signal("card_cancelled"):
		card_node.card_cancelled.connect(_on_card_cancelled)
	if card_node.has_signal("target_mode_started"):
		card_node.target_mode_started.connect(_on_target_mode_started)
	if card_node.has_signal("target_mode_ended"):
		card_node.target_mode_ended.connect(_on_target_mode_ended)
	if card_node.has_signal("card_play_requested"):
		card_node.card_play_requested.connect(_on_card_play_requested)
	if not card_node.has_method("setup"):
		card_node.gui_input.connect(_on_card_gui_input.bind(card, card_node))

func _on_card_gui_input(event: InputEvent, card: CardData, card_node: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(card, card_node)

func _on_card_ui_clicked(card: CardData) -> void:
	if _card_select_active:
		return
	card_clicked.emit(card, null)

func _on_card_play_requested(card: CardData) -> void:
	if _card_select_active:
		return
	card_played.emit(card, null)

func update_enemy_display(enemies: Array) -> void:
	_clear_enemies()
	
	for child in enemy_container.get_children():
		child.queue_free()
	
	for enemy in enemies:
		var enemy_node = _create_enemy_node(enemy)
		if enemy_node:
			enemy_container.add_child(enemy_node)
			current_enemy_nodes[enemy] = enemy_node
	
	if current_target_index >= enemies.size():
		current_target_index = 0
	
	if enemies.size() > 0 and current_target_index < enemies.size():
		var target_enemy = enemies[current_target_index]
		update_target_marker(target_enemy)

func _clear_enemies() -> void:
	for enemy_node in current_enemy_nodes.values():
		enemy_node.queue_free()
	current_enemy_nodes.clear()

func _create_enemy_node(enemy: EnemyUnit) -> Control:
	var enemy_scene_path = "res://scenes/EnemyUI.tscn"
	var enemy_node: Control = null
	
	if ResourceLoader.exists(enemy_scene_path):
		var enemy_scene = load(enemy_scene_path)
		enemy_node = enemy_scene.instantiate() as Control
		
		if enemy_node.has_method("setup"):
			enemy_node.setup(enemy, player_manager)
			enemy_node.enemy_selected.connect(_on_enemy_ui_selected)
	else:
		enemy_node = Control.new()
		enemy_node.custom_minimum_size = Vector2(150, 200)
		
		var name_label = Label.new()
		name_label.text = enemy.get_name()
		name_label.position = Vector2(0, 0)
		enemy_node.add_child(name_label)
		
		var hp_label = Label.new()
		hp_label.name = "HPLabel"
		hp_label.text = "%d/%d" % [enemy.current_hp, enemy.max_hp]
		hp_label.position = Vector2(0, 30)
		enemy_node.add_child(hp_label)
		
		var hp_bar = ProgressBar.new()
		hp_bar.name = "HPBar"
		hp_bar.max_value = enemy.max_hp
		hp_bar.value = enemy.current_hp
		hp_bar.position = Vector2(0, 60)
		hp_bar.custom_minimum_size = Vector2(100, 20)
		enemy_node.add_child(hp_bar)
		
		enemy_node.gui_input.connect(_on_enemy_gui_input.bind(enemy))
	
	return enemy_node

func _on_enemy_ui_selected(enemy: EnemyUnit) -> void:
	selected_target = enemy
	enemy_selected.emit(enemy)
	
	if is_selecting_target:
		select_attack_target(enemy)
		return
	
	if is_dragging and dragging_card:
		card_dropped.emit(dragging_card, enemy)
		is_dragging = false
		drag_arrow.hide_arrow()
		clear_target_highlights()
		dragging_card = null
		drag_card_node = null

func _on_enemy_gui_input(event: InputEvent, enemy: EnemyUnit) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_target = enemy
		enemy_selected.emit(enemy)

func update_single_enemy(enemy: EnemyUnit) -> void:
	if current_enemy_nodes.has(enemy):
		var node = current_enemy_nodes[enemy]
		var hp_label = node.get_node_or_null("HPLabel")
		var hp_bar = node.get_node_or_null("HPBar")
		
		if hp_label:
			hp_label.text = "%d/%d" % [enemy.current_hp, enemy.max_hp]
		if hp_bar:
			hp_bar.value = enemy.current_hp
		
		if node.has_method("_update_buff_bar"):
			node._update_buff_bar()
		if node.has_method("_update_intent_display"):
			node._update_intent_display()

func update_all_enemy_intents() -> void:
	for enemy in current_enemy_nodes:
		var node = current_enemy_nodes[enemy]
		if node and is_instance_valid(node) and node.has_method("_update_intent_display"):
			node._update_intent_display()

func update_player_display(hp: int, max_hp: int, block: int) -> void:
	if player_area == null:
		return
	
	var hp_label = player_area.get_node_or_null("HPLabel")
	var hp_bar = player_area.get_node_or_null("HPBar")
	var block_label = player_area.get_node_or_null("BlockLabel")
	
	if hp_label:
		hp_label.text = "%d/%d" % [hp, max_hp]
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	if block_label:
		block_label.text = "护甲: %d" % block

func update_deck_info(draw_count: int, discard_count: int) -> void:
	if deck_info_node == null:
		return
	
	var draw_label = deck_info_node.get_node_or_null("DrawPile")
	var discard_label = deck_info_node.get_node_or_null("DiscardPile")
	
	if draw_label:
		draw_label.text = "抽牌堆: %d" % draw_count
	if discard_label:
		discard_label.text = "弃牌堆: %d" % discard_count

func _create_player_info_panels() -> void:
	if player_area == null:
		return
	
	var info_vbox = VBoxContainer.new()
	info_vbox.name = "PlayerInfoVBox"
	info_vbox.add_theme_constant_override("separation", 4)
	player_area.get_parent().add_child(info_vbox)
	
	_player_buff_bar = HBoxContainer.new()
	_player_buff_bar.name = "PlayerBuffBar"
	_player_buff_bar.add_theme_constant_override("separation", 4)
	info_vbox.add_child(_player_buff_bar)
	
	_player_stats_panel = HBoxContainer.new()
	_player_stats_panel.name = "PlayerStatsPanel"
	_player_stats_panel.add_theme_constant_override("separation", 8)
	info_vbox.add_child(_player_stats_panel)
	
	_reposition_info_panel.call_deferred(info_vbox)

func _reposition_info_panel(panel: VBoxContainer) -> void:
	if player_area and is_instance_valid(panel):
		var pa_rect = player_area.get_global_rect()
		panel.global_position = Vector2(pa_rect.position.x + pa_rect.size.x + 10, pa_rect.position.y)

func update_player_stats_info(pm: PlayerManager) -> void:
	if _player_stats_panel == null:
		return
	
	for child in _player_stats_panel.get_children():
		child.queue_free()
	
	var effective = pm.get_expected_attack_damage()
	
	var a_lbl = Label.new()
	a_lbl.text = "弃牌攻击:%d" % effective
	a_lbl.add_theme_font_size_override("font_size", 13)
	a_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_player_stats_panel.add_child(a_lbl)

func update_player_buff_bar(pm: PlayerManager) -> void:
	if _player_buff_bar == null:
		return
	
	for child in _player_buff_bar.get_children():
		child.queue_free()
	
	if not pm.buff_manager:
		return
	
	for buff in pm.buff_manager.buffs:
		var buff_info = _extract_buff_info(buff)
		if buff_info.is_empty():
			continue
		var lbl = _create_buff_label(buff_info)
		_player_buff_bar.add_child(lbl)

func _extract_buff_info(buff) -> Dictionary:
	var stacks: int = 1
	var duration: int = 0
	var buff_id: String = ""
	var buff_name: String = ""
	var buff_type: String = "buff"
	if buff is BuffData:
		stacks = buff.stacks
		duration = buff.duration
		buff_id = buff.id
		buff_name = buff.name
		buff_type = buff.buff_type
	elif buff is Dictionary:
		stacks = buff.get("stacks", 1)
		duration = buff.get("duration", 0)
		buff_id = buff.get("id", buff.get("buff_id", ""))
		buff_name = buff.get("name", "")
		buff_type = buff.get("buff_type", "buff")
	else:
		return {}
	return {"id": buff_id, "name": buff_name, "stacks": stacks, "duration": duration, "buff_type": buff_type}

var _buff_tooltip_panel: PanelContainer = null

const NO_STACK_BUFFS: Array = ["ignore_block", "counter_stance", "no_discard"]

func _create_buff_label(info: Dictionary) -> Control:
	var buff_id: String = info.get("id", "")
	var stacks: int = info.get("stacks", 1)
	var duration: int = info.get("duration", 0)
	
	var symbol = _get_buff_symbol(buff_id)
	var color = _get_buff_color(buff_id)
	var show_stacks = not NO_STACK_BUFFS.has(buff_id)
	
	var btn = Button.new()
	if show_stacks:
		btn.text = "%s%d" % [symbol, stacks]
	else:
		btn.text = symbol
	if duration > 0:
		btn.text += "(%d)" % duration
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color)
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 18)
	btn.focus_mode = Control.FOCUS_NONE
	
	var tooltip_text = _get_buff_tooltip(buff_id, stacks, duration)
	if not tooltip_text.is_empty():
		btn.mouse_entered.connect(_on_buff_label_hovered.bind(tooltip_text, btn))
		btn.mouse_exited.connect(_on_buff_label_unhovered)
	
	return btn

func _on_buff_label_hovered(text: String, source: Control) -> void:
	_hide_buff_tooltip()
	
	_buff_tooltip_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	style.border_color = Color(0.5, 0.5, 0.6, 1.0)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	_buff_tooltip_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	
	var lines = text.split("\n")
	for line in lines:
		var lbl = Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 13)
		if line == lines[0]:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		else:
			lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		vbox.add_child(lbl)
	
	_buff_tooltip_panel.add_child(vbox)
	
	var canvas = root_node.get_tree().root
	canvas.add_child(_buff_tooltip_panel)
	
	var gp = source.global_position
	var ts = _buff_tooltip_panel.get_combined_minimum_size()
	var vp_size = source.get_viewport_rect().size
	var px = gp.x + source.size.x + 6
	if px + ts.x > vp_size.x:
		px = gp.x - ts.x - 6
	var py = gp.y - 5
	if py + ts.y > vp_size.y:
		py = vp_size.y - ts.y - 5
	_buff_tooltip_panel.position = Vector2(px, py)
	_buff_tooltip_panel.z_index = 100

func _on_buff_label_unhovered() -> void:
	_hide_buff_tooltip()

func _hide_buff_tooltip() -> void:
	if _buff_tooltip_panel and is_instance_valid(_buff_tooltip_panel):
		_buff_tooltip_panel.queue_free()
	_buff_tooltip_panel = null

func _get_buff_tooltip(buff_id: String, stacks: int, duration: int) -> String:
	var desc = _get_buff_description(buff_id, stacks)
	if desc.is_empty():
		return ""
	var result = desc
	if duration > 0:
		result += "\n剩余 %d 回合" % duration
	elif duration == -1:
		result += "\n永久"
	return result

func _load_buff_db() -> void:
	if not _buff_db.is_empty():
		return
	var file = FileAccess.open("res://data/buffs.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json and json.has("buffs"):
			_buff_db = json["buffs"]
		file.close()

func _get_buff_data(buff_id: String) -> Dictionary:
	_load_buff_db()
	return _buff_db.get(buff_id, {})

func _get_buff_description(buff_id: String, stacks: int) -> String:
	var data = _get_buff_data(buff_id)
	if data.is_empty():
		return ""
	var name = data.get("name", buff_id)
	var desc_template = data.get("description", "")
	var desc = desc_template.replace("{stacks}", str(stacks))
	var buff_type = data.get("buff_type", "buff")
	var type_label = "[增益]" if buff_type == "buff" else "[减益]" if buff_type == "debuff" else ""
	return "%s %s\n%s" % [type_label, name, desc] if type_label != "" else "%s\n%s" % [name, desc]

func _get_buff_symbol(buff_id: String) -> String:
	var data = _get_buff_data(buff_id)
	return data.get("symbol", "●")

func _get_buff_color(buff_id: String) -> Color:
	var data = _get_buff_data(buff_id)
	var hex = data.get("color", "#B3B3B3")
	return Color(hex)

func show_damage_number(target, amount: int) -> void:
	if amount <= 0:
		return
	
	var target_node = null
	if target is EnemyUnit and current_enemy_nodes.has(target):
		target_node = current_enemy_nodes[target]
		if target_node.has_method("show_damage_number"):
			target_node.show_damage_number(amount)
			return
	elif target is PlayerManager and player_area:
		target_node = player_area
	
	var damage_label = Label.new()
	damage_label.text = "-%d" % amount
	damage_label.add_theme_color_override("font_color", Color.RED)
	damage_label.add_theme_font_size_override("font_size", 24)
	
	if target_node:
		target_node.add_child(damage_label)
		damage_label.position = Vector2(50, 0)
		
		var tween = root_node.create_tween()
		tween.tween_property(damage_label, "position:y", -20, 1.8)
		tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.3).set_delay(1.5)
		tween.tween_callback(damage_label.queue_free)

func remove_card_from_hand(card: CardData) -> void:
	if current_hand_cards.has(card):
		var node = current_hand_cards[card]
		node.queue_free()
		current_hand_cards.erase(card)

func set_interactive(enabled: bool) -> void:
	for card_node in current_hand_cards.values():
		card_node.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func _on_end_turn_pressed() -> void:
	end_turn_clicked.emit()

func _on_player_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_player_stats_popup()

func _show_player_stats_popup() -> void:
	if player_manager == null:
		return
	
	var popup = AcceptDialog.new()
	popup.title = "角色属性"
	
	var stats_text = "生命值: %d / %d\n" % [player_manager.current_hp, player_manager.max_hp]
	stats_text += "护甲: %d\n" % player_manager.block
	stats_text += "力量: %d\n" % player_manager.get_strength()
	stats_text += "敏捷: %d" % player_manager.get_dexterity()
	
	popup.dialog_text = stats_text
	root_node.add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(popup.queue_free)
	popup.close_requested.connect(popup.queue_free)

func highlight_valid_targets(card: CardData) -> void:
	clear_target_highlights()
	
	if card == null:
		return
	
	var target_type = card.target_type
	
	if target_type == "single_enemy":
		for enemy_node in current_enemy_nodes.values():
			if enemy_node.has_method("set_highlight_for_target"):
				enemy_node.set_highlight_for_target(true)
	elif target_type == "all_enemies":
		for enemy_node in current_enemy_nodes.values():
			if enemy_node.has_method("set_highlight_for_target"):
				enemy_node.set_highlight_for_target(true)

func clear_target_highlights() -> void:
	for enemy_node in current_enemy_nodes.values():
		if enemy_node.has_method("set_highlight_for_target"):
			enemy_node.set_highlight_for_target(false)
	
	if player_area and player_area.has_method("set_highlight_for_target"):
		player_area.set_highlight_for_target(false)

func play_card_animation(card: CardData, card_node: Control, target = null) -> void:
	if card_node == null:
		return
	
	var target_pos = Vector2(400, 300)
	
	if target and current_enemy_nodes.has(target):
		var enemy_node = current_enemy_nodes[target]
		target_pos = enemy_node.position + enemy_node.size / 2
	
	if card_node.has_method("play_play_animation"):
		card_node.play_play_animation(target_pos)

func _on_card_drag_started(card: CardData, start_pos: Vector2, card_node: Control) -> void:
	is_dragging = true
	dragging_card = card
	drag_card_node = card_node
	
	var needs_target = card.target_type == "single_enemy" or card.target_type == "single_ally"
	if needs_target:
		highlight_valid_targets(card)
		drag_arrow.show_arrow()
	else:
		clear_target_highlights()
		drag_arrow.hide_arrow()

func _on_card_drag_updated(card: CardData, current_pos: Vector2) -> void:
	if not is_dragging or drag_card_node == null:
		return
	
	var card_center = drag_card_node.global_position + drag_card_node.size / 2
	drag_arrow.set_points(card_center, current_pos)
	
	var hover_target = _get_target_at_position(current_pos)
	_update_hover_highlight(hover_target)

func _on_card_drag_ended(card: CardData, end_pos: Vector2) -> void:
	if not is_dragging:
		return
	
	var target = _get_target_at_position(end_pos)
	
	if target:
		card_dropped.emit(card, target)
		is_dragging = false
		drag_arrow.hide_arrow()
		clear_target_highlights()
		dragging_card = null
		drag_card_node = null
	elif dragging_card and not _card_select_active:
		var needs_target = dragging_card.target_type == "single_enemy" or dragging_card.target_type == "single_ally"
		if not needs_target:
			if drag_card_node and drag_card_node.drag_exited_hand:
				card_played.emit(card, null)
		if drag_card_node and drag_card_node.has_method("reset_position"):
			drag_card_node.reset_position()
		is_dragging = false
		drag_arrow.hide_arrow()
		clear_target_highlights()
		dragging_card = null
		drag_card_node = null
		ensure_cards_layout_state()
	else:
		if drag_card_node and drag_card_node.has_method("reset_position"):
			drag_card_node.reset_position()
		is_dragging = false
		drag_arrow.hide_arrow()
		clear_target_highlights()
		dragging_card = null
		drag_card_node = null
		ensure_cards_layout_state()

func _get_target_at_position(pos: Vector2):
	for enemy in current_enemy_nodes:
		var enemy_node = current_enemy_nodes[enemy]
		var rect = Rect2(enemy_node.global_position, enemy_node.size)
		if rect.has_point(pos):
			return enemy
	
	if player_area:
		var player_rect = Rect2(player_area.global_position, player_area.size)
		if player_rect.has_point(pos):
			return player_manager
	
	return null

func _update_hover_highlight(hover_target) -> void:
	for enemy in current_enemy_nodes:
		var enemy_node = current_enemy_nodes[enemy]
		if enemy_node.has_method("set_highlight_for_target"):
			enemy_node.set_highlight_for_target(enemy == hover_target)
	
	if player_area and player_area.has_method("set_highlight_for_target"):
		player_area.set_highlight_for_target(hover_target == player_manager)

func _on_card_released(card: CardData, card_node: Control) -> void:
	card_released.emit(card, card_node)

func _on_card_cancelled(card: CardData) -> void:
	if is_dragging:
		is_dragging = false
		drag_arrow.hide_arrow()
		clear_target_highlights()
		dragging_card = null
		drag_card_node = null
	
	card_cancelled.emit(card)
	ensure_cards_layout_state()

func _on_target_mode_started(card: CardData) -> void:
	is_dragging = true
	dragging_card = card
	drag_card_node = current_hand_cards.get(card)
	
	highlight_valid_targets(card)
	drag_arrow.show_arrow()

func _on_target_mode_ended(_card: CardData) -> void:
	is_dragging = false
	drag_arrow.hide_arrow()
	clear_target_highlights()
	dragging_card = null
	drag_card_node = null
	
	ensure_cards_layout_state()

func ensure_cards_layout_state() -> void:
	for card in current_hand_cards:
		var card_node = current_hand_cards[card]
		if card_node and card_node.has_method("restore_to_layout_state"):
			card_node.restore_to_layout_state()
	
	if last_hand.size() > 0:
		update_hand_display(last_hand)

## ========== 弃牌堆选择模式（用于"从墓地选择"类效果，如逆流） ==========
var _discard_select_panel: PanelContainer = null
var _discard_select_cards: Array = []
var _discard_select_selected: Array = []
var _discard_select_max: int = 3
var _discard_select_callback: Callable = Callable()

## 进入"从给定卡牌列表（弃牌堆）中选择"模式
func enter_discard_select_mode(prompt: String, cards: Array, max_count: int, callback: Callable) -> void:
	_discard_select_cards = cards
	_discard_select_selected.clear()
	_discard_select_max = max_count
	_discard_select_callback = callback
	_build_discard_select_ui(prompt)

func _build_discard_select_ui(prompt: String) -> void:
	_close_discard_select_ui()
	_discard_select_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.97)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	style.border_color = Color(0.5, 0.4, 0.25, 1)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	_discard_select_panel.add_theme_stylebox_override("panel", style)
	_discard_select_panel.set_anchors_preset(Control.PRESET_CENTER)
	_discard_select_panel.custom_minimum_size = Vector2(560, 400)
	_discard_select_panel.z_index = 300
	root_node.add_child(_discard_select_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_discard_select_panel.add_child(vbox)

	var title := Label.new()
	title.text = prompt
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	vbox.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for card in _discard_select_cards:
		var btn := Button.new()
		btn.text = "%s\n%s" % [card.name, card.get_description_text()]
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(250, 72)
		btn.add_theme_font_size_override("font_size", 13)
		btn.toggled.connect(_on_discard_select_toggled.bind(card, btn))
		grid.add_child(btn)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var confirm := Button.new()
	confirm.text = "确认"
	confirm.custom_minimum_size = Vector2(120, 36)
	confirm.pressed.connect(_on_discard_select_confirm)
	btn_row.add_child(confirm)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(120, 36)
	cancel.pressed.connect(_on_discard_select_cancel)
	btn_row.add_child(cancel)

func _on_discard_select_toggled(pressed: bool, card, btn: Button) -> void:
	if pressed:
		if _discard_select_selected.size() >= _discard_select_max:
			btn.set_pressed_no_signal(false)
			return
		_discard_select_selected.append(card)
	else:
		_discard_select_selected.erase(card)

func _on_discard_select_confirm() -> void:
	var cb = _discard_select_callback
	var selected = _discard_select_selected.duplicate()
	_close_discard_select_ui()
	if cb.is_valid():
		cb.call(selected)

func _on_discard_select_cancel() -> void:
	var cb = _discard_select_callback
	_close_discard_select_ui()
	if cb.is_valid():
		cb.call([])

func _close_discard_select_ui() -> void:
	if _discard_select_panel and is_instance_valid(_discard_select_panel):
		_discard_select_panel.queue_free()
	_discard_select_panel = null

func is_card_select_active() -> bool:
	return _card_select_active

func get_card_node(card: CardData) -> Control:
	return current_hand_cards.get(card)

func enter_card_select_mode(prompt: String, min_select: int, max_select: int, callback: Callable) -> void:
	_card_select_active = true
	_card_select_min = min_select
	_card_select_max = max_select
	_card_selected_cards.clear()
	_card_select_callback = callback
	
	var bar = HBoxContainer.new()
	bar.name = "CardSelectBar"
	bar.add_theme_constant_override("separation", 12)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 10
	bar.offset_bottom = 50
	root_node.add_child(bar)
	_card_select_staging = bar
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bg)
	
	var inner = HBoxContainer.new()
	inner.name = "InnerHBox"
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 12)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(inner)
	
	_card_select_info_label = Label.new()
	_card_select_info_label.text = prompt
	_card_select_info_label.add_theme_font_size_override("font_size", 16)
	_card_select_info_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	inner.add_child(_card_select_info_label)
	
	_card_select_confirm_btn = Button.new()
	_card_select_confirm_btn.text = "确认"
	_card_select_confirm_btn.custom_minimum_size = Vector2(100, 32)
	_card_select_confirm_btn.pressed.connect(_on_card_select_confirm)
	inner.add_child(_card_select_confirm_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.name = "CancelBtn"
	cancel_btn.text = "跳过"
	cancel_btn.custom_minimum_size = Vector2(100, 32)
	cancel_btn.pressed.connect(_on_card_select_cancel)
	inner.add_child(cancel_btn)
	
	_update_card_select_ui()
	
	if end_turn_button:
		end_turn_button.disabled = true
	
	for card in current_hand_cards:
		var card_node = current_hand_cards[card]
		if card_node:
			if card_node.has_signal("card_clicked") and not card_node.card_clicked.is_connected(_on_card_select_card_clicked):
				card_node.card_clicked.connect(_on_card_select_card_clicked)
			if card_node.has_method("set") and "is_select_mode" in card_node:
				card_node.is_select_mode = true
			card_node.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_card_select_gui_input(event: InputEvent, card: CardData) -> void:
	if not _card_select_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_card_selection(card)

func _on_card_select_card_clicked(card: CardData) -> void:
	if not _card_select_active:
		return
	_toggle_card_selection(card)

func _toggle_card_selection(card: CardData) -> void:
	if card in _card_selected_cards:
		_card_selected_cards.erase(card)
		_deselect_card(card)
	else:
		if _card_selected_cards.size() >= _card_select_max:
			return
		_card_selected_cards.append(card)
		_select_card(card)
	_update_card_select_ui()

func _select_card(card: CardData) -> void:
	var card_node = current_hand_cards.get(card)
	if card_node == null:
		return
	var vp_size = card_node.get_viewport_rect().size
	var parent = card_node.get_parent()
	var idx = _card_selected_cards.find(card)
	if idx < 0:
		idx = _card_selected_cards.size()
	var total = _card_selected_cards.size()
	var card_w = card_node.size.x
	var spacing = card_w + 20
	var total_width = max(total, 1) * spacing
	var offset_x = -total_width / 2.0 + idx * spacing + spacing / 2.0 - card_w / 2.0
	var center_x = vp_size.x / 2.0 + offset_x
	var center_y = vp_size.y / 2.0 - card_node.size.y / 2.0 - 50
	var center_local: Vector2
	if parent:
		center_local = Vector2(center_x - parent.global_position.x, center_y - parent.global_position.y)
	else:
		center_local = Vector2(center_x, center_y)
	var tween = card_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_node, "position", center_local, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_node, "modulate", Color(1, 0.7, 0.7, 1), 0.15)
	tween.tween_property(card_node, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(card_node, "rotation_degrees", 0.0, 0.15)
	tween.tween_property(card_node, "z_index", 50, 0.0)
	_reposition_selected_cards()

func _reposition_selected_cards() -> void:
	if _card_selected_cards.size() == 0:
		return
	var first_node = current_hand_cards.get(_card_selected_cards[0])
	if first_node == null:
		return
	var vp_size = first_node.get_viewport_rect().size
	var parent = first_node.get_parent()
	var total = _card_selected_cards.size()
	var card_w = first_node.size.x
	var spacing = card_w + 20
	var total_width = total * spacing
	var center_y = vp_size.y / 2.0 - first_node.size.y / 2.0 - 50
	
	for i in range(total):
		var card = _card_selected_cards[i]
		var card_node = current_hand_cards.get(card)
		if card_node == null:
			continue
		var offset_x = -total_width / 2.0 + i * spacing + spacing / 2.0 - card_node.size.x / 2.0
		var center_x = vp_size.x / 2.0 + offset_x
		var center_local: Vector2
		if parent:
			center_local = Vector2(center_x - parent.global_position.x, center_y - parent.global_position.y)
		else:
			center_local = Vector2(center_x, center_y)
		var tween = card_node.create_tween()
		tween.set_parallel(true)
		tween.tween_property(card_node, "position", center_local, 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(card_node, "rotation_degrees", 0.0, 0.1)

func _deselect_card(card: CardData) -> void:
	var card_node = current_hand_cards.get(card)
	if card_node == null:
		return
	var target_rotation = card_node.original_rotation if "original_rotation" in card_node else 0.0
	var tween = card_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_node, "position", card_node.original_position, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_node, "modulate", Color.WHITE, 0.15)
	tween.tween_property(card_node, "scale", card_node.original_scale, 0.15)
	tween.tween_property(card_node, "rotation_degrees", target_rotation, 0.15)
	tween.tween_property(card_node, "z_index", 0, 0.0)
	_reposition_selected_cards()

func _update_card_select_ui() -> void:
	if _card_select_info_label:
		var count = _card_selected_cards.size()
		_card_select_info_label.text = "已选 %d / %d（至少%d张）" % [count, _card_select_max, _card_select_min]
	
	if _card_select_confirm_btn:
		_card_select_confirm_btn.disabled = _card_selected_cards.size() < _card_select_min

func _on_card_select_confirm() -> void:
	if _card_selected_cards.size() < _card_select_min:
		return
	
	var selected = _card_selected_cards.duplicate()
	_exit_card_select_mode()
	
	if _card_select_callback.is_valid():
		_card_select_callback.call(selected)
	
	card_select_confirmed.emit(selected)

func _on_card_select_cancel() -> void:
	_card_selected_cards.clear()
	for card in current_hand_cards:
		_deselect_card(card)
	
	if _card_select_min == 0:
		_on_card_select_confirm()
	else:
		_exit_card_select_mode()

func _exit_card_select_mode() -> void:
	_card_select_active = false
	
	if end_turn_button:
		end_turn_button.disabled = false
	
	for card in current_hand_cards:
		var card_node = current_hand_cards[card]
		if card_node:
			if card_node.has_signal("card_clicked") and card_node.card_clicked.is_connected(_on_card_select_card_clicked):
				card_node.card_clicked.disconnect(_on_card_select_card_clicked)
			if card_node.has_method("set") and "is_select_mode" in card_node:
				card_node.is_select_mode = false
	
	if _card_select_staging and is_instance_valid(_card_select_staging):
		_card_select_staging.queue_free()
	_card_select_staging = null
	_card_select_confirm_btn = null
	_card_select_info_label = null
	_card_selected_cards.clear()
