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
var battle_controller = null              ## 战斗控制器引用（由 setup_battle 注入，避免每次遍历场景树查找）
var screen_shake: Node = null             ## 屏幕震动器（由 battle.gd 注入）
var _player_flash_tween: Tween = null     ## 玩家受击闪红 tween（防止叠加）

## B4: 骰子UI（玩家）
var _dice_bar: HBoxContainer = null        ## 玩家骰子栏
var _dice_nodes: Array = []                ## 玩家骰子节点数组
var _dice_cards: Array = []                ## 骰子装载的卡牌数组
var _dice_speeds: Array = []               ## 骰子速度值数组
var _active_dice_index: int = -1           ## 当前激活的骰子索引（等待装载）
var _dice_tooltip: PanelContainer = null   ## 骰子悬浮浮框

## 敌人骰子栏 {enemy_idx: {"bar":Node, "nodes":Array, "cards":Array, "speeds":Array}}
var _enemy_dice_bars: Dictionary = {}

## UI 节点引用（从场景中查找获取）
var hand_container: Node       ## 手牌区域的容器节点
var enemy_container: Node      ## 敌人区域的容器节点
var player_area: Node          ## 玩家区域节点
var end_turn_button: Button    ## 结束回合按钮
var deck_info_node: Node       ## 牌堆信息节点
var state_display_label: Label = null  ## 状态提示文字（淡出效果）

var target_marker: Control = null      ## 目标标记 UI

## 玩家信息面板
var _player_stats_panel: HBoxContainer = null  ## 属性统计面板
var _player_buff_bar: HBoxContainer = null     ## buff 图标栏
var drag_arrow: DragArrow = null               ## 拖拽箭头

## 详细信息框（点击角色弹出，半透明，含完整属性+buff详情，可滚动）
var _detail_panel: PanelContainer = null

## 全局 buff 数据库缓存（从 JSON 加载一次，所有 UIController 实例共享）
static var _buff_db: Dictionary = {}

## 卡牌选择模式相关（用于"选择 X 张卡牌"类型的效果）
var _card_select_active: bool = false        ## 是否处于卡牌选择模式
var _card_select_min: int = 0               ## 最少选择数量
var _card_select_max: int = 1               ## 最多选择数量
var _card_selected_cards: Array = []        ## 已选中的卡牌列表
var _card_select_staging: Control = null    ## 选择模式 UI 容器
var _card_select_confirm_btn: Button = null ## 确认按钮
var _card_select_auto_confirm: bool = false ## 选中即确认（不显示确认按钮，用于弃牌攻击）
var _card_select_info_label: Label = null   ## 提示文字
var _card_select_callback: Callable = Callable()  ## 选择完成后的回调


## 拖拽状态
var is_dragging: bool = false             ## 是否正在拖拽
var dragging_card: CardData = null        ## 正在拖拽的卡牌
var drag_card_node: Control = null        ## 拖拽中卡牌的 UI 节点
var last_hand: Array = []                 ## 上一次的手牌列表（用于恢复布局）

## 手牌轮盘（扇形窗口）滚动状态
var _hand_scroll: int = 0                    ## 最左可见卡牌在手牌中的索引
var _hand_scroll_timer: Timer = null         ## 边缘悬浮滚动计时器
var _edge_left_hint: Label = null            ## 左边缘"还有更多"提示
var _edge_right_hint: Label = null           ## 右边缘提示
var _hand_drag_scroll_active: bool = false   ## 手牌区左键拖动滚动中
var _hand_drag_scroll_last_x: float = 0.0    ## 拖动滚动上次鼠标 x
var _hand_drag_scroll_accum: float = 0.0     ## 拖动滚动累积移动量

## 当前手牌 UI 节点映射 { CardData: Control }
var current_hand_cards: Dictionary = {}
## 当前敌人 UI 节点映射 { EnemyUnit: Control }
var current_enemy_nodes: Dictionary = {}
var selected_target = null          ## 当前选中的目标
var current_target_index: int = 0  ## 当前目标索引

## 交互信号
signal card_clicked(card: CardData, card_node: Control)  ## 卡牌被点击
signal card_cancelled(card: CardData)                    ## 卡牌操作取消
signal card_dropped(card: CardData, target)              ## 卡牌被拖放到目标上
signal card_played(card: CardData, target)               ## 卡牌被打出
signal enemy_selected(enemy: EnemyUnit)                  ## 敌人被选中
signal end_turn_clicked()                                ## 结束回合按钮被点击


## 构造函数：接收战斗场景的根节点，初始化所有 UI
func _init(root: Control):
	root_node = root
	_find_ui_nodes()
	_setup_signals()
	_load_card_scene()
	_setup_state_display()
	_setup_drag_arrow()

	_setup_target_marker()
	_setup_hand_scroll()

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


## 创建目标标记 UI（使用 target_marker.gd 脚本）
## set_script 动态给 Control 节点附加脚本（类似 Python 的运行时添加方法）
func _setup_target_marker() -> void:
	target_marker = Control.new()
	target_marker.name = "TargetMarker"
	target_marker.set_script(load("res://scripts/ui/target_marker.gd"))
	root_node.add_child(target_marker)


## 更新目标标记位置
func update_target_marker(enemy: EnemyUnit) -> void:
	if target_marker == null:
		return
	
	var enemy_node = current_enemy_nodes.get(enemy)
	if enemy_node:
		if target_marker.has_method("set_target"):
			target_marker.call("set_target", enemy_node)


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
	if hand_container:
		hand_container.gui_input.connect(_on_hand_area_input)
	enemy_container = root_node.get_node_or_null("Background/EnemyArea")
	player_area = root_node.get_node_or_null("Background/PlayerArea")
	end_turn_button = root_node.get_node_or_null("EndTurnButton")
	deck_info_node = root_node.get_node_or_null("DeckInfo")
	
	if player_area:
		player_area.gui_input.connect(_on_player_area_input)
		_create_player_info_panels()
	
	root_node.gui_input.connect(_on_root_input_close_detail)

func _setup_signals() -> void:
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
		UIStyle.attach_button_anim(end_turn_button)

func _load_card_scene() -> void:
	card_scene = load("res://scenes/Card.tscn")

func _get_hand_container_width() -> float:
	if hand_container:
		var w: float = hand_container.size.x
		if w > 0:
			return maxf(w, 200.0)
	return 800.0

## 建立手牌边缘滚动计时器与左右提示箭头
func _setup_hand_scroll() -> void:
	_hand_scroll_timer = Timer.new()
	_hand_scroll_timer.wait_time = 0.13
	_hand_scroll_timer.timeout.connect(_on_hand_scroll_tick)
	root_node.add_child(_hand_scroll_timer)
	_hand_scroll_timer.start()

	if hand_container:
		_edge_left_hint = _make_edge_hint("←")
		hand_container.add_child(_edge_left_hint)
		_edge_right_hint = _make_edge_hint("→")
		hand_container.add_child(_edge_right_hint)

func _make_edge_hint(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 0.9))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 60
	lbl.visible = false
	return lbl

## 定时检测鼠标是否悬浮在手牌区左右边缘，若是则滚动窗口（轮盘旋转）
func _on_hand_area_input(event: InputEvent) -> void:
	if last_hand.size() <= HandLayoutPresets.MAX_VISIBLE:
		return
	if _card_select_active or is_dragging:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_hand_drag_scroll_active = true
				_hand_drag_scroll_last_x = mb.global_position.x
				_hand_drag_scroll_accum = 0.0
			else:
				_hand_drag_scroll_active = false
	elif event is InputEventMouseMotion and _hand_drag_scroll_active:
		var mm := event as InputEventMouseMotion
		var dx: float = mm.global_position.x - _hand_drag_scroll_last_x
		_hand_drag_scroll_last_x = mm.global_position.x
		_hand_drag_scroll_accum += dx
		var threshold := 60.0
		while absf(_hand_drag_scroll_accum) >= threshold:
			if _hand_drag_scroll_accum > 0:
				_scroll_hand(-1)
				_hand_drag_scroll_accum -= threshold
			else:
				_scroll_hand(1)
				_hand_drag_scroll_accum += threshold

func _on_hand_scroll_tick() -> void:
	if last_hand.size() <= HandLayoutPresets.MAX_VISIBLE:
		return
	if _card_select_active or is_dragging:
		return
	if hand_container == null or not (hand_container is Control):
		return
	var hc := hand_container as Control
	var rect: Rect2 = hc.get_global_rect()
	var mouse: Vector2 = hc.get_global_mouse_position()
	if not rect.has_point(mouse):
		return
	var edge: float = rect.size.x * 0.16
	if mouse.x < rect.position.x + edge:
		_scroll_hand(-1)
	elif mouse.x > rect.position.x + rect.size.x - edge:
		_scroll_hand(1)

func _scroll_hand(dir: int) -> void:
	if last_hand.is_empty():
		return
	_hand_scroll = wrapi(_hand_scroll + dir, 0, last_hand.size())
	update_hand_display(last_hand)

func _update_hand_edge_hints(hand_size: int, visible_count: int) -> void:
	var can_scroll := hand_size > visible_count
	if _edge_left_hint:
		_edge_left_hint.visible = can_scroll
		if can_scroll and hand_container:
			_edge_left_hint.position = Vector2(6, hand_container.size.y / 2.0 - 20)
			_edge_left_hint.size = Vector2(32, 40)
	if _edge_right_hint:
		_edge_right_hint.visible = can_scroll
		if can_scroll and hand_container:
			_edge_right_hint.position = Vector2(hand_container.size.x - 38, hand_container.size.y / 2.0 - 20)
			_edge_right_hint.size = Vector2(32, 40)

func update_hand_display(hand: Array) -> void:
	last_hand = hand.duplicate()
	var newly_created: Array = []
	var hand_size := hand.size()
	if hand_size == 0:
		_clear_hand()
		_update_hand_edge_hints(0, 0)
		return

	var container_width := _get_hand_container_width()
	var visible_count := mini(hand_size, HandLayoutPresets.MAX_VISIBLE)
	_hand_scroll = wrapi(_hand_scroll, 0, hand_size)

	# 移除已不在手牌的卡牌节点
	for card in current_hand_cards.keys():
		if not hand.has(card):
			var node = current_hand_cards[card]
			node.queue_free()
			current_hand_cards.erase(card)

	# 计算可见槽位：card -> 槽位下标（窗口外的卡牌不在此表中）
	var slot_of := {}
	for i in range(visible_count):
		var card = hand[(_hand_scroll + i) % hand_size]
		slot_of[card] = i

	for i in range(hand_size):
		var card = hand[i]
		var card_node = current_hand_cards.get(card)
		if card_node == null:
			card_node = _create_card_node(card)
			if card_node == null:
				continue
			hand_container.add_child(card_node)
			current_hand_cards[card] = card_node
			newly_created.append(card)
			_setup_card_interaction(card_node, card)

		# 卡牌选择模式中已选中的卡保持在屏幕中央，不参与扇形重排
		if _card_select_active and card in _card_selected_cards:
			card_node.visible = true
			continue

		# 窗口外（隐藏）的卡牌
		if not slot_of.has(card):
			card_node.visible = false
			continue

		card_node.visible = true
		var slot := int(slot_of[card])
		var layout := HandLayoutPresets.get_card_position(slot, visible_count, container_width)

		# 拖拽中 / 选目标中 / 悬停 / 选中的卡牌保持原状，不参与重排
		if (card_node.has_method("is_in_target_mode") and card_node.is_in_target_mode()) \
			or (card_node.has_method("is_dragging_card") and card_node.is_dragging_card()) \
			or (card_node.has_method("is_hovered_card") and card_node.is_hovered_card()) \
			or (card_node.has_method("is_selected_card") and card_node.is_selected_card()):
			continue

		# 首次创建的卡牌直接就位，已存在的卡牌用 tween 平滑移动
		if card in newly_created:
			card_node.position = layout.position
			card_node.rotation_degrees = layout.rotation
		else:
			var tween = card_node.create_tween()
			tween.set_parallel(true)
			tween.tween_property(card_node, "position", layout.position, 0.18).set_ease(Tween.EASE_OUT)
			tween.tween_property(card_node, "rotation_degrees", layout.rotation, 0.18).set_ease(Tween.EASE_OUT)
		card_node.modulate.a = 1.0
		if card_node.has_method("set_original_position"):
			card_node.call("set_original_position", layout.position)
		if "original_rotation" in card_node:
			card_node.original_rotation = layout.rotation
		if "original_scale" in card_node:
			card_node.original_scale = Vector2(0.72, 0.72)

	_update_hand_edge_hints(hand_size, visible_count)

func _clear_hand() -> void:
	for card_node in current_hand_cards.values():
		card_node.queue_free()
	current_hand_cards.clear()

func _create_card_node(card: CardData) -> Control:
	if card_scene == null:
		return null
	
	var card_node = card_scene.instantiate() as Control
	if card_node and card_node.has_method("setup"):
		card_node.setup(card, player_manager)
		card_node.card_clicked.connect(_on_card_ui_clicked)
	return card_node

func _setup_card_interaction(card_node: Control, card: CardData) -> void:
	if card_node.has_signal("drag_started"):
		card_node.drag_started.connect(_on_card_drag_started.bind(card_node))
		card_node.drag_updated.connect(_on_card_drag_updated)
		card_node.drag_ended.connect(_on_card_drag_ended)

	if card_node.has_signal("card_cancelled"):
		card_node.card_cancelled.connect(_on_card_cancelled)
	if card_node.has_signal("target_mode_started"):
		card_node.target_mode_started.connect(_on_target_mode_started)
	if card_node.has_signal("target_mode_ended"):
		card_node.target_mode_ended.connect(_on_target_mode_ended)
	if card_node.has_signal("target_mode_paused"):
		card_node.target_mode_paused.connect(_on_target_mode_paused)
	if card_node.has_signal("card_play_requested"):
		card_node.card_play_requested.connect(_on_card_play_requested)


func _on_card_ui_clicked(card: CardData) -> void:
	if _card_select_active:
		return
	card_clicked.emit(card, null)

func _on_card_play_requested(card: CardData) -> void:
	if _card_select_active:
		return
	_clear_drag_state()
	card_played.emit(card, null)

func update_enemy_display(enemies: Array) -> void:
	_clear_enemies()
	
	# 立即释放旧节点（用 free 而非 queue_free，避免同帧内 get_child 获取到即将释放的节点）
	for child in enemy_container.get_children():
		child.free()
	
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
	if not ResourceLoader.exists(enemy_scene_path):
		return null
	var enemy_node = load(enemy_scene_path).instantiate() as Control
	if enemy_node.has_method("setup"):
		enemy_node.setup(enemy, player_manager)
		enemy_node.enemy_selected.connect(_on_enemy_ui_selected)
	enemy_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	enemy_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return enemy_node

func _on_enemy_ui_selected(enemy: EnemyUnit) -> void:
	selected_target = enemy
	enemy_selected.emit(enemy)
	if is_dragging and dragging_card:
		if drag_card_node and drag_card_node.has_method("clear_interaction_state"):
			drag_card_node.clear_interaction_state()
		card_dropped.emit(dragging_card, enemy)
		_clear_drag_state()
	else:
		var node = current_enemy_nodes.get(enemy)
		if node and is_instance_valid(node):
			_open_enemy_detail(enemy, node)

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
		draw_label.text = "牌库: %d" % draw_count
	if discard_label:
		# 新流程只有手牌+牌库，隐藏弃牌堆显示
		discard_label.visible = false

func _create_player_info_panels() -> void:
	if player_area == null:
		return
	_player_buff_bar = HBoxContainer.new()
	_player_buff_bar.name = "PlayerBuffBar"
	_player_buff_bar.add_theme_constant_override("separation", 4)
	player_area.add_child(_player_buff_bar)

func _reposition_info_panel(panel: VBoxContainer) -> void:
	if player_area and is_instance_valid(panel):
		panel.size_flags_horizontal = Control.SIZE_FILL

func _position_bar_above(bar: HBoxContainer, target: Control) -> void:
	if not is_instance_valid(bar) or not is_instance_valid(target):
		return
	var t_rect = target.get_global_rect()
	var bar_w = bar.size.x if bar.size.x > 0 else bar.get_combined_minimum_size().x
	var bar_h = bar.size.y if bar.size.y > 0 else bar.get_combined_minimum_size().y
	bar.global_position = Vector2(t_rect.position.x + t_rect.size.x / 2.0 - bar_w / 2.0, t_rect.position.y - bar_h - 8)

## B4: 创建玩家骰子栏（按速度降序排列便于对比）
func create_dice_bar(slots: int, speeds: Array, unknown: bool = false) -> void:
	_dice_speeds = speeds.duplicate()
	_dice_speeds.sort()
	_dice_speeds.reverse()
	_dice_cards.clear()
	_dice_cards.resize(slots)
	_dice_nodes.clear()
	_active_dice_index = -1

	if _dice_bar and is_instance_valid(_dice_bar):
		_dice_bar.queue_free()
	_dice_bar = HBoxContainer.new()
	_dice_bar.name = "DiceBar"
	_dice_bar.add_theme_constant_override("separation", 4)
	for i in slots:
		var dice = _create_dice_node(i, _dice_speeds[i] if i < _dice_speeds.size() else 1, false, -1, unknown)
		_dice_nodes.append(dice)
		_dice_bar.add_child(dice)
	if player_area and is_instance_valid(player_area):
		player_area.add_child(_dice_bar)
		player_area.move_child(_dice_bar, 0)
		_dice_bar.z_index = 40

## 揭示玩家骰子速度（回合准备后调用，按速度降序排列）
func reveal_player_dice(speeds: Array = []) -> void:
	if speeds.size() > 0:
		_dice_speeds = speeds.duplicate()
		_dice_speeds.sort()
		_dice_speeds.reverse()
	for i in _dice_nodes.size():
		_set_dice_value(_dice_nodes[i], _dice_speeds[i] if i < _dice_speeds.size() else 1)

## 设置骰子显示的速度值
func _set_dice_value(node: Control, speed: int) -> void:
	if node is DiceHex:
		node.set_value("%d" % speed)
	elif node.has_node("DiceLabel"):
		node.get_node("DiceLabel").text = "%d" % speed

## B4: 创建敌人骰子栏
func create_enemy_dice_bar(enemy_idx: int, slots: int, speeds: Array, unknown: bool = false) -> void:
	var sorted_speeds = speeds.duplicate()
	sorted_speeds.sort()
	sorted_speeds.reverse()
	var bar = HBoxContainer.new()
	bar.name = "EnemyDiceBar_%d" % enemy_idx
	bar.add_theme_constant_override("separation", 8)
	var nodes: Array = []
	var cards: Array = []
	cards.resize(slots)
	for i in slots:
		var dice = _create_dice_node(i, sorted_speeds[i] if i < sorted_speeds.size() else 1, true, enemy_idx, unknown)
		nodes.append(dice)
		bar.add_child(dice)
	# 定位到对应敌人正上方
	root_node.add_child(bar)
	bar.z_index = 20
	if enemy_container and enemy_container.get_child_count() > enemy_idx:
		var enemy_node = enemy_container.get_child(enemy_idx)
		_position_bar_above.call_deferred(bar, enemy_node)
	_enemy_dice_bars[enemy_idx] = {"bar": bar, "nodes": nodes, "cards": cards, "speeds": sorted_speeds}

## B4: 创建单个骰子节点（六边形，只显示速度）
func _create_dice_node(index: int, speed: int, is_enemy: bool, enemy_idx: int, unknown: bool = false) -> DiceHex:
	var dice = DiceHex.new()
	dice.custom_minimum_size = Vector2(38, 42)
	dice.name = "Dice_%s_%d" % ["E" if is_enemy else "P", index]
	dice.dice_value = "?" if unknown else "%d" % speed
	dice.set_state_colors(false, false)
	dice.gui_input.connect(_on_dice_input.bind(index, is_enemy, enemy_idx))
	dice.mouse_entered.connect(_on_dice_hover.bind(index, is_enemy, enemy_idx))
	dice.mouse_exited.connect(_on_dice_unhover.bind(index, is_enemy, enemy_idx))
	return dice

## 应用骰子样式（active=激活金色, filled=已装填正常色, 空=灰色）
func _apply_dice_style(panel: Control, active: bool, filled: bool = false) -> void:
	if panel is DiceHex:
		panel.set_state_colors(filled, active)


## B4: 骰子交互（左键激活/取消，右键卸载）
func _on_dice_input(event: InputEvent, index: int, is_enemy: bool, enemy_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if is_enemy:
			return
		var node = _dice_nodes[index]
		if _active_dice_index == index:
			# 取消激活
			_apply_dice_style(node, false, _dice_cards[index] != null)
			_active_dice_index = -1
		else:
			# 激活该骰子，显示对应手牌
			if _active_dice_index >= 0 and _active_dice_index < _dice_nodes.size():
				_apply_dice_style(_dice_nodes[_active_dice_index], false, _dice_cards[_active_dice_index] != null)
			_apply_dice_style(node, true, _dice_cards[index] != null)
			_active_dice_index = index
			if node is DiceHex:
				node.set_hover_scale(1.15)
			set_hand_visible(true)

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_unload_dice_card(index, is_enemy, enemy_idx)

## B4: 是否有激活的骰子（等待装载）
func has_active_dice() -> bool:
	return _active_dice_index >= 0 and _active_dice_index < _dice_cards.size()

## B4: 装载卡牌到骰子（由出牌流程调用，含飞入动画）
func load_card_to_dice(card: CardData, card_node = null) -> bool:
	if _active_dice_index < 0 or _active_dice_index >= _dice_cards.size():
		return false
	if _dice_cards[_active_dice_index] != null:
		return false
	var bc = _get_battle_controller()
	if bc and not bc.player_manager.can_afford(card.cost):
		show_state_message("能量不足", 0.8)
		if card_node and is_instance_valid(card_node):
			_shake_card(card_node)
		return false
	var dice_index = _active_dice_index
	_dice_cards[dice_index] = card
	# 从手牌移除
	if bc:
		bc.card_system.hand.erase(card)
	# 卡牌飞入骰子动画
	var dice_node = _dice_nodes[dice_index]
	if card_node and is_instance_valid(card_node) and dice_node:
		_fly_card_to_dice(card_node, dice_node, dice_index)
	else:
		_update_dice_display(dice_index, false, -1)
		if bc:
			update_hand_display(bc.card_system.get_hand())
	_apply_dice_style(_dice_nodes[dice_index], false)
	_active_dice_index = -1
	return true

## B4: 卡牌缩小飞入骰子动画
func _fly_card_to_dice(card_node: Control, dice_node: Control, dice_index: int) -> void:
	card_node.z_index = 100
	card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target_center = dice_node.global_position + dice_node.size / 2
	var tween = root_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_node, "global_position", target_center - card_node.size * 0.5, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card_node, "scale", Vector2(0.15, 0.15), 0.3)
	tween.tween_property(card_node, "modulate:a", 0.3, 0.3)
	tween.set_parallel(false)
	tween.tween_callback(func():
		if is_instance_valid(card_node):
			card_node.queue_free()
		_update_dice_display(dice_index, false, -1)
		var bc = _get_battle_controller()
		if bc:
			update_hand_display(bc.card_system.get_hand())
	)

## B4: 卸载骰子卡牌
func _unload_dice_card(index: int, is_enemy: bool, enemy_idx: int) -> void:
	if is_enemy:
		var bar_data = _enemy_dice_bars.get(enemy_idx)
		if bar_data and bar_data.cards[index] != null:
			bar_data.cards[index] = null
			_update_dice_display(index, true, enemy_idx)
		return
	if index < 0 or index >= _dice_cards.size():
		return
	var card: CardData = _dice_cards[index]
	if card == null:
		return
	# 卡牌回手牌
	var bc = _get_battle_controller()
	if bc:
		bc.card_system.add_to_hand(card)
		if bc.ui_controller:
			bc.ui_controller.update_hand_display(bc.card_system.get_hand())
	_dice_cards[index] = null
	_update_dice_display(index, false, -1)

## B4: 更新骰子显示（仅更新边框装填状态，卡牌悬浮时显示）
func _update_dice_display(index: int, is_enemy: bool, enemy_idx: int) -> void:
	var nodes: Array = []
	var cards: Array = []
	if is_enemy:
		var bar_data = _enemy_dice_bars.get(enemy_idx)
		if not bar_data:
			return
		nodes = bar_data.nodes
		cards = bar_data.cards
	else:
		nodes = _dice_nodes
		cards = _dice_cards
	if index >= nodes.size():
		return
	var card: CardData = cards[index]
	_apply_dice_style(nodes[index], false, card != null)

## B4: 敌方骰子装载卡牌（AI结算时调用，仅作显示）
func place_enemy_dice_card(enemy_idx: int, index: int, card: CardData) -> void:
	var bar_data = _enemy_dice_bars.get(enemy_idx)
	if not bar_data:
		return
	if index < 0 or index >= bar_data.cards.size():
		return
	bar_data.cards[index] = card
	_update_dice_display(index, true, enemy_idx)

## B4: 骰子悬浮——显示对应卡牌浮框 + 缩放反馈
func _on_dice_hover(index: int, is_enemy: bool, enemy_idx: int) -> void:
	var node: Control = null
	var card: CardData = null
	if is_enemy:
		var bar_data = _enemy_dice_bars.get(enemy_idx)
		if bar_data:
			if index < bar_data.nodes.size():
				node = bar_data.nodes[index]
			if index < bar_data.cards.size():
				card = bar_data.cards[index]
	else:
		if index < _dice_nodes.size():
			node = _dice_nodes[index]
		if index < _dice_cards.size():
			card = _dice_cards[index]
	if node is DiceHex:
		node.set_hover_scale(1.12)

## B4: 骰子取消悬浮
func _on_dice_unhover(index: int = -1, is_enemy: bool = false, enemy_idx: int = -1) -> void:
	var node: Control = null
	if is_enemy:
		var bar_data = _enemy_dice_bars.get(enemy_idx)
		if bar_data and index >= 0 and index < bar_data.nodes.size():
			node = bar_data.nodes[index]
	else:
		if index >= 0 and index < _dice_nodes.size():
			node = _dice_nodes[index]
	if node is DiceHex:
		node.set_hover_scale(1.0)

## B4: 显示骰子卡牌浮框
func _show_dice_tooltip(card: CardData) -> void:
	_hide_dice_tooltip()
	_dice_tooltip = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.6, 0.8, 0.8)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	_dice_tooltip.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_dice_tooltip.add_child(vbox)
	var name_label = Label.new()
	name_label.text = "%s (cost %d)" % [card.name, card.cost]
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(name_label)
	var desc_label = Label.new()
	desc_label.text = card.description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(160, 0)
	vbox.add_child(desc_label)
	# 显示在鼠标附近（z_index 置顶避免被遮挡，边界自动翻转）
	var mouse_pos = root_node.get_viewport().get_mouse_position()
	root_node.add_child(_dice_tooltip)
	_dice_tooltip.z_index = 500
	var vp_size = root_node.get_viewport_rect().size
	var tsize = _dice_tooltip.get_combined_minimum_size()
	var pos = mouse_pos + Vector2(15, 15)
	if pos.x + tsize.x > vp_size.x:
		pos.x = mouse_pos.x - tsize.x - 15
	if pos.y + tsize.y > vp_size.y:
		pos.y = mouse_pos.y - tsize.y - 15
	_dice_tooltip.global_position = pos

## B4: 隐藏骰子浮框
func _hide_dice_tooltip() -> void:
	if _dice_tooltip and is_instance_valid(_dice_tooltip):
		_dice_tooltip.queue_free()
	_dice_tooltip = null

## B4: 卡牌能量不足反馈——红色闪烁+左右抖动
func _shake_card(card_node: Control) -> void:
	if not is_instance_valid(card_node):
		return
	var orig_pos = card_node.position
	var tw = card_node.create_tween()
	tw.tween_property(card_node, "modulate", Color(1.6, 0.3, 0.3, 1.0), 0.08)
	tw.tween_property(card_node, "modulate", Color(1, 1, 1, 1.0), 0.15)
	tw.parallel().tween_property(card_node, "position:x", orig_pos.x + 8, 0.04).set_trans(Tween.TRANS_SINE)
	tw.tween_property(card_node, "position:x", orig_pos.x - 8, 0.08).set_trans(Tween.TRANS_SINE)
	tw.tween_property(card_node, "position:x", orig_pos.x, 0.06).set_trans(Tween.TRANS_SINE)

## B4: 显示状态提示（简化）
func _show_state_hint(text: String) -> void:
	show_state_message(text, 1.0)

## B4: 获取玩家装载的出牌列表
func get_loaded_plays() -> Array:
	var plays: Array = []
	for i in _dice_cards.size():
		var card: CardData = _dice_cards[i]
		if card != null:
			var target = null
			var bc = _get_battle_controller()
			if bc:
				if card.target_type == "self":
					target = bc.player_manager
				elif card.target_type == "single_enemy":
					var enemies = bc.enemy_system.get_alive_enemies()
					target = enemies[0] if enemies.size() > 0 else null
			plays.append({"card": card, "target": target, "slot_index": i, "speed": _dice_speeds[i] if i < _dice_speeds.size() else 1})
	return plays

## B4: 清理骰子UI
func clear_dice_ui() -> void:
	if _dice_bar and is_instance_valid(_dice_bar):
		_dice_bar.queue_free()
	_dice_bar = null
	_dice_cards.clear()
	_dice_nodes.clear()
	_active_dice_index = -1
	for enemy_idx in _enemy_dice_bars.keys():
		var bar_data = _enemy_dice_bars[enemy_idx]
		if bar_data.bar and is_instance_valid(bar_data.bar):
			bar_data.bar.queue_free()
	_enemy_dice_bars.clear()
	_hide_dice_tooltip()

## B4: 获取BattleController（优先使用注入的引用，否则遍历场景树兜底查找）
func _get_battle_controller():
	if battle_controller and is_instance_valid(battle_controller):
		return battle_controller
	var root = root_node.get_tree().root
	for child in root.get_children():
		if child.name == "BattleScene":
			battle_controller = child.get("battle_controller")
			return battle_controller
	return null

func update_player_stats_info(pm: PlayerManager) -> void:
	if _player_stats_panel == null:
		return
	for child in _player_stats_panel.get_children():
		child.queue_free()

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
	btn.add_theme_font_size_override("font_size", 9)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color)
	btn.flat = true
	if UIStyle:
		UIStyle.strip_button_box(btn)
	btn.custom_minimum_size = Vector2(0, 10)
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

## 弹出飘字：kind = "damage"(红) / "heal"(绿) / "block"(蓝)
func show_damage_number(target, amount: int, kind: String = "damage") -> void:
	if amount <= 0:
		return

	# 受击屏幕震动（仅伤害类型，按 amount 分档强度）
	if kind == "damage" and screen_shake:
		var params := ImpactConfig.get_params(amount)
		screen_shake.shake(params.shake_amp, params.shake_dur)

	var target_node = null
	if target is EnemyUnit and current_enemy_nodes.has(target):
		target_node = current_enemy_nodes[target]
		if target_node.has_method("show_damage_number"):
			target_node.show_damage_number(amount, kind)
			return
	elif target is PlayerManager and player_area:
		target_node = player_area
	
	if target_node == null:
		return
	
	var text: String
	var color: Color
	match kind:
		"heal":
			text = "+%d" % amount
			color = Color(0.35, 0.9, 0.45)
		"block":
			text = "+%d" % amount
			color = Color(0.45, 0.75, 1.0)
		_:
			text = "-%d" % amount
			color = Color.RED
	
	var damage_label = Label.new()
	damage_label.text = text
	damage_label.add_theme_color_override("font_color", color)
	damage_label.add_theme_font_size_override("font_size", 24)
	
	target_node.add_child(damage_label)
	damage_label.position = Vector2(50, 0)

	ImpactConfig.apply_text_effect(damage_label, amount, root_node)
	var tween = root_node.create_tween()
	tween.tween_property(damage_label, "position:y", -20, 1.8)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.3).set_delay(1.5)
	tween.tween_callback(damage_label.queue_free)

## 玩家受击闪红：按伤害分档决定闪红强度，叠加在 player_area 上
func flash_player_area(amount: int) -> void:
	if player_area == null or not is_instance_valid(player_area):
		return
	if _player_flash_tween and _player_flash_tween.is_valid():
		_player_flash_tween.kill()
	var params := ImpactConfig.get_params(amount)
	var red_intensity := clampf((params.scale_peak - 1.0) * 2.0, 0.3, 1.0)
	var flash_color := Color(1.0 + red_intensity * 0.5, 1.0 - red_intensity * 0.7, 1.0 - red_intensity * 0.7)
	_player_flash_tween = player_area.create_tween()
	_player_flash_tween.tween_property(player_area, "modulate", flash_color, 0.05)
	_player_flash_tween.tween_property(player_area, "modulate", Color.WHITE, 0.15)

func remove_card_from_hand(card: CardData) -> void:
	if current_hand_cards.has(card):
		var node = current_hand_cards[card]
		node.queue_free()
		current_hand_cards.erase(card)

func set_interactive(enabled: bool) -> void:
	for card_node in current_hand_cards.values():
		card_node.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

## 控制手牌区显隐（点击骰子后才显示）— 带淡入淡出动效
var _hand_visible: bool = false
var _hand_tween: Tween = null
func set_hand_visible(visible: bool) -> void:
	if hand_container == null:
		return
	if _hand_visible == visible:
		return
	_hand_visible = visible
	if _hand_tween and _hand_tween.is_valid():
		_hand_tween.kill()
	if visible:
		hand_container.visible = true
		hand_container.modulate.a = 0.0
		_hand_tween = hand_container.create_tween()
		_hand_tween.tween_property(hand_container, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	else:
		hand_container.modulate.a = 1.0
		_hand_tween = hand_container.create_tween()
		_hand_tween.tween_property(hand_container, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
		_hand_tween.tween_callback(func(): hand_container.visible = false)

func _on_end_turn_pressed() -> void:
	end_turn_clicked.emit()

func _on_player_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var sprite = player_area.get_node_or_null("PlayerSprite")
		if sprite and sprite.get_global_rect().has_point(event.global_position):
			_open_player_detail()
			player_area.accept_event()

## 点击空白（穿透到根节点）时关闭详细信息框+隐藏手牌；操作（按钮/手牌/角色）不会到达此处
func _on_root_input_close_detail(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_detail_panel()
		if _hand_visible:
			set_hand_visible(false)

func _close_detail_panel() -> void:
	if _detail_panel and is_instance_valid(_detail_panel):
		_detail_panel.queue_free()
		_detail_panel = null

## 构建半透明可滚动的详细信息框，返回内容容器（VBox）
func _build_detail_panel() -> VBoxContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.1, 0.92)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.border_color = Color(0.5, 0.5, 0.65, 0.9)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(190, 220)
	scroll.size_flags_vertical = Control.SIZE_FILL
	panel.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 5)
	vbox.size_flags_horizontal = Control.SIZE_FILL
	scroll.add_child(vbox)
	
	_detail_panel = panel
	return vbox

func _add_detail_line(container: VBoxContainer, text: String, color: Color = Color(0.88, 0.88, 0.92), size: int = 13) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("outline_size", 2)
	container.add_child(lbl)

func _add_detail_sprite(container: VBoxContainer, texture: Texture2D, w: int = 80, h: int = 64) -> void:
	if texture == null:
		return
	var tex = TextureRect.new()
	tex.texture = texture
	tex.custom_minimum_size = Vector2(w, h)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.add_child(tex)

## 详情框内加血条+数字
func _add_detail_hp_bar(container: VBoxContainer, current: int, maximum: int) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(120, 14)
	bar.max_value = maximum
	bar.value = current
	bar.show_percentage = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.25, 0.25, 1)
	style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", style)
	hbox.add_child(bar)
	var lbl = Label.new()
	lbl.text = "%d / %d" % [current, maximum]
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	hbox.add_child(lbl)
	container.add_child(hbox)

## 详情框内加能量圆点+数字
func _add_detail_energy_dots(container: VBoxContainer, available: int, maximum: int, used: int = 0) -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	var dots = HBoxContainer.new()
	dots.add_theme_constant_override("separation", 4)
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	var unavailable = maxi(maximum - available - used, 0)
	for i in available:
		dots.add_child(_create_energy_dot("lit"))
	for i in used:
		dots.add_child(_create_energy_dot("used"))
	for i in unavailable:
		dots.add_child(_create_energy_dot("dark"))
	vbox.add_child(dots)
	var lbl = Label.new()
	lbl.text = "能量 %d / %d" % [available, maximum]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)
	container.add_child(vbox)

func _buff_detail_text(buff) -> String:
	var stacks := 1
	var duration := 0
	var buff_name := ""
	var buff_id := ""
	if buff is BuffData:
		stacks = buff.stacks
		duration = buff.duration
		buff_name = buff.name
		buff_id = buff.id
	elif buff is Dictionary:
		stacks = buff.get("stacks", 1)
		duration = buff.get("duration", 0)
		buff_name = buff.get("name", "")
		buff_id = buff.get("id", buff.get("buff_id", ""))
	else:
		return ""
	var line = buff_name if buff_name != "" else buff_id
	if stacks > 1:
		line += " x%d" % stacks
	if duration > 0:
		line += " (%d回合)" % duration
	elif duration == -1:
		line += " (永久)"
	return line

## 定位详情框固定在对应侧（玩家=左侧, 敌人=右侧），垂直居中
func _position_detail_panel(target: Control, side: String = "player") -> void:
	if _detail_panel == null:
		return
	_detail_panel.z_index = 300
	await root_node.get_tree().process_frame
	if not is_instance_valid(_detail_panel):
		return
	var ps = _detail_panel.size
	var vp = root_node.get_viewport_rect().size
	var px: float = 10.0 if side == "player" else vp.x - ps.x - 10.0
	var py: float = (vp.y - ps.y) / 2.0
	_detail_panel.global_position = Vector2(px, py)

func _open_player_detail() -> void:
	_close_detail_panel()
	if player_manager == null:
		return
	var content = _build_detail_panel()
	root_node.add_child(_detail_panel)
	_add_detail_line(content, "玩家", Color(1, 0.9, 0.5), 16)
	var sprite = player_area.get_node_or_null("PlayerSprite")
	if sprite:
		_add_detail_sprite(content, sprite.texture)
	_add_detail_hp_bar(content, player_manager.current_hp, player_manager.max_hp)
	_add_detail_line(content, "护甲: %d" % player_manager.block, Color(0.45, 0.75, 1.0))
	_add_detail_energy_dots(content, player_manager.energy, player_manager.max_energy)
	_add_detail_line(content, "槽位: %d" % player_manager.slots)
	_add_detail_line(content, "速度: %d" % player_manager.speed)
	if player_manager.has_method("get_strength"):
		_add_detail_line(content, "力量: %d" % player_manager.get_strength())
	if player_manager.has_method("get_dexterity"):
		_add_detail_line(content, "敏捷: %d" % player_manager.get_dexterity())
	if player_manager.buff_manager:
		_add_detail_line(content, "—— 增益/减益 ——", Color(0.75, 0.75, 0.82), 12)
		if player_manager.buff_manager.buffs.is_empty():
			_add_detail_line(content, "（无）", Color(0.6, 0.6, 0.6), 12)
		for buff in player_manager.buff_manager.buffs:
			var t = _buff_detail_text(buff)
			if t != "":
				_add_detail_line(content, t)
	_position_detail_panel(sprite, "player")

func _open_enemy_detail(enemy: EnemyUnit, enemy_node: Control) -> void:
	_close_detail_panel()
	if enemy == null:
		return
	var content = _build_detail_panel()
	root_node.add_child(_detail_panel)
	_add_detail_line(content, enemy.get_name(), Color(1, 0.8, 0.5), 16)
	var esprite = enemy_node.get_node_or_null("EnemySprite")
	if esprite:
		_add_detail_sprite(content, esprite.texture, 100, 68)
	_add_detail_hp_bar(content, enemy.current_hp, enemy.max_hp)
	_add_detail_line(content, "护甲: %d" % enemy.block, Color(0.45, 0.75, 1.0))
	_add_detail_line(content, "速度: %d" % enemy.speed)
	if enemy.buff_manager:
		_add_detail_line(content, "—— 增益/减益 ——", Color(0.75, 0.75, 0.82), 12)
		if enemy.buff_manager.buffs.is_empty():
			_add_detail_line(content, "（无）", Color(0.6, 0.6, 0.6), 12)
		for buff in enemy.buff_manager.buffs:
			var t = _buff_detail_text(buff)
			if t != "":
				_add_detail_line(content, t)
	_position_detail_panel(enemy_node, "enemy")

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
	
	if target_marker and target_marker.has_method("clear"):
		target_marker.clear()

## 将卡牌节点从手牌映射中摘出（不释放），交给打出动画接管；避免 hand_changed 重排时释放它
func detach_card_node(card: CardData) -> Control:
	var node = current_hand_cards.get(card)
	if node:
		current_hand_cards.erase(card)
	return node

## 打出失败时把节点放回手牌映射，供后续重排恢复
func reattach_card_node(card: CardData, card_node: Control) -> void:
	current_hand_cards[card] = card_node

## 获取弃牌堆标签的屏幕中心位置（卡牌打出后飞向的终点）
func get_discard_pile_global_pos() -> Vector2:
	if deck_info_node:
		var discard = deck_info_node.get_node_or_null("DiscardPile")
		if discard:
			return discard.get_global_rect().get_center()
	# 兜底：屏幕左下角
	return Vector2(120, root_node.get_viewport_rect().size.y - 60)

func _on_card_drag_started(card: CardData, start_pos: Vector2, card_node: Control) -> void:
	is_dragging = true
	dragging_card = card
	drag_card_node = card_node
	# 新行为：箭头与目标高亮只在 target_mode_started（需要目标的卡牌拖出手牌区后）时显示
	# 拖拽开始时不显示箭头，让卡牌自由跟随鼠标
	clear_target_highlights()
	drag_arrow.hide_arrow()

func _on_card_drag_updated(card: CardData, current_pos: Vector2) -> void:
	if not is_dragging or drag_card_node == null:
		return
	# 只在目标瞄准模式（箭头已可见）时更新箭头与悬停高亮
	# 避免普通拖拽时 set_points 重新显示箭头
	if drag_arrow.is_visible:
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
		_clear_drag_state()
	elif dragging_card and not _card_select_active:
		var needs_target = dragging_card.target_type == "single_enemy" or dragging_card.target_type == "single_ally"
		if not needs_target and drag_card_node and drag_card_node.drag_exited_hand:
			card_played.emit(card, null)
		if drag_card_node and drag_card_node.has_method("reset_position"):
			drag_card_node.reset_position()
		_clear_drag_state()
		ensure_cards_layout_state()
	else:
		if drag_card_node and drag_card_node.has_method("reset_position"):
			drag_card_node.reset_position()
		_clear_drag_state()
		ensure_cards_layout_state()

## 统一清理拖拽状态：隐藏箭头、取消高亮、清空拖拽引用
func _clear_drag_state() -> void:
	is_dragging = false
	drag_arrow.hide_arrow()
	clear_target_highlights()
	dragging_card = null
	drag_card_node = null

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


func _on_card_cancelled(card: CardData) -> void:
	if is_dragging:
		_clear_drag_state()
	
	card_cancelled.emit(card)
	ensure_cards_layout_state()

func _on_target_mode_started(card: CardData) -> void:
	is_dragging = true
	dragging_card = card
	drag_card_node = current_hand_cards.get(card)
	
	highlight_valid_targets(card)
	drag_arrow.show_arrow()

func _on_target_mode_ended(_card: CardData) -> void:
	_clear_drag_state()
	ensure_cards_layout_state()

## 目标瞄准模式暂停：鼠标回到手牌区域，恢复为拖拽模式
## 隐藏箭头与高亮，但保持 is_dragging=true 和 dragging_card 不变（不重排手牌）
func _on_target_mode_paused(_card: CardData) -> void:
	drag_arrow.hide_arrow()
	clear_target_highlights()

func ensure_cards_layout_state() -> void:
	for card in current_hand_cards:
		var card_node = current_hand_cards[card]
		if card_node and card_node.has_method("restore_to_layout_state"):
			card_node.restore_to_layout_state()
	
	if last_hand.size() > 0:
		update_hand_display(last_hand)


func is_card_select_active() -> bool:
	return _card_select_active

func get_card_node(card: CardData) -> Control:
	return current_hand_cards.get(card)

func enter_card_select_mode(prompt: String, min_select: int, max_select: int, callback: Callable, show_cancel: bool = true, auto_confirm: bool = false) -> void:
	_card_select_active = true
	_card_select_min = min_select
	_card_select_max = max_select
	_card_selected_cards.clear()
	_card_select_callback = callback
	_card_select_auto_confirm = auto_confirm
	
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
	
	if not auto_confirm:
		_card_select_confirm_btn = Button.new()
		_card_select_confirm_btn.text = "确认"
		_card_select_confirm_btn.custom_minimum_size = Vector2(100, 32)
		_card_select_confirm_btn.pressed.connect(_on_card_select_confirm)
		inner.add_child(_card_select_confirm_btn)
		UIStyle.attach_button_anim(_card_select_confirm_btn)
	
	if show_cancel:
		var cancel_btn = Button.new()
		cancel_btn.name = "CancelBtn"
		cancel_btn.text = "跳过"
		cancel_btn.custom_minimum_size = Vector2(100, 32)
		cancel_btn.pressed.connect(_on_card_select_cancel)
		inner.add_child(cancel_btn)
		UIStyle.attach_button_anim(cancel_btn)
	
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
	# 选中即确认：达到最少选择数立即提交（弃牌攻击选中 1 张即弃）
	if _card_select_auto_confirm and _card_selected_cards.size() >= _card_select_min:
		_on_card_select_confirm()

func _select_card(card: CardData) -> void:
	var card_node = current_hand_cards.get(card)
	if card_node == null:
		return
	# 位置由 _reposition_selected_cards 统一重排，这里只负责选中态的视觉反馈
	var tween = card_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_node, "modulate", Color(1, 0.88, 0.5, 1), 0.15)
	tween.tween_property(card_node, "scale", Vector2(1.1, 1.1), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
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
	var center_y = vp_size.y * 0.65 - first_node.size.y / 2.0
	
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
	tween.tween_property(card_node, "position", card_node.original_position, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card_node, "modulate", Color.WHITE, 0.2)
	tween.tween_property(card_node, "scale", card_node.original_scale, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card_node, "rotation_degrees", target_rotation, 0.2)
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
	_card_select_auto_confirm = false
	_card_select_info_label = null
	_card_selected_cards.clear()
## ==========================================
## B4: 新流程UI方法
## ==========================================


## 设置回合按钮文字和可用状态（新流程用）
func show_end_turn_button(text: String, enabled: bool) -> void:
	if end_turn_button:
		end_turn_button.text = text
		end_turn_button.disabled = not enabled

## B4: 卡牌结算动画——显示卡牌本体（卡图+名称+描述）+效果文字（敌我）
func show_resolve_animation(card: CardData, is_player: bool, effect_text: String) -> void:
	var container = PanelContainer.new()
	container.name = "ResolveCard"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.98)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.4, 0.8, 0.5, 0.95) if is_player else Color(0.9, 0.4, 0.4, 0.95)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	container.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	container.add_child(vbox)
	# 归属标签
	var side_lbl = Label.new()
	side_lbl.text = "我方出牌" if is_player else "敌方出牌"
	side_lbl.add_theme_font_size_override("font_size", 12)
	side_lbl.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6) if is_player else Color(0.95, 0.6, 0.6))
	side_lbl.horizontal_alignment = 1
	vbox.add_child(side_lbl)
	# 卡图
	var art_panel = PanelContainer.new()
	art_panel.custom_minimum_size = Vector2(150, 90)
	var astyle = StyleBoxFlat.new()
	astyle.bg_color = Color(0.05, 0.05, 0.08, 1)
	astyle.set_corner_radius_all(5)
	art_panel.clip_contents = true
	art_panel.add_theme_stylebox_override("panel", astyle)
	if card.art != "":
		var tex = TextureRect.new()
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var t = load(card.art)
		if t:
			tex.texture = t
		art_panel.add_child(tex)
	vbox.add_child(art_panel)
	# 名称+费用
	var name_lbl = Label.new()
	name_lbl.text = "%s  [%d费]" % [card.name, card.cost]
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	name_lbl.horizontal_alignment = 1
	vbox.add_child(name_lbl)
	# 描述
	var desc_lbl = Label.new()
	desc_lbl.text = card.description
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(170, 0)
	vbox.add_child(desc_lbl)
	# 效果文字（增益情况）
	var eff_lbl = Label.new()
	eff_lbl.text = "→ " + effect_text
	eff_lbl.add_theme_font_size_override("font_size", 14)
	eff_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6) if is_player else Color(1.0, 0.6, 0.5))
	eff_lbl.horizontal_alignment = 1
	vbox.add_child(eff_lbl)
	root_node.add_child(container)
	container.z_index = 500
	var vp = root_node.get_viewport_rect().size
	container.global_position = Vector2(vp.x * 0.5 - 100, 110) if is_player else Vector2(vp.x * 0.5 - 100, 360)
	container.modulate.a = 0.0
	container.pivot_offset = Vector2(100, 100)
	var tw = root_node.create_tween()
	tw.tween_property(container, "modulate:a", 1.0, 0.15)
	tw.tween_interval(0.9)
	tw.tween_property(container, "modulate:a", 0.0, 0.15)
	await tw.finished
	if is_instance_valid(container):
		container.queue_free()


## 显示敌人出牌意图（同时出牌模式下）
func show_enemy_intent(enemy_idx: int, plays: Array) -> void:
	# 在敌人区域显示意图
	var enemy_node = null
	if enemy_container and enemy_idx < enemy_container.get_child_count():
		enemy_node = enemy_container.get_child(enemy_idx)
	if enemy_node:
		# 查找或创建意图标签
		var intent_label = enemy_node.get_node_or_null("IntentLabel")
		if intent_label == null:
			intent_label = Label.new()
			intent_label.name = "IntentLabel"
			intent_label.add_theme_font_size_override("font_size", 14)
			intent_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
			intent_label.horizontal_alignment = 1
			# 放在敌人节点内部顶部（EnemySlot 高度220，顶部5px处）
			intent_label.position = Vector2(0, 5)
			intent_label.size = Vector2(160, 20)
			enemy_node.add_child(intent_label)
		var text = ""
		for play in plays:
			var card: CardData = play.card
			if text != "":
				text += " | "
			text += card.name
		intent_label.text = text
		intent_label.visible = true  ## 新流程：确保意图可见（_update_intent_display 可能设为 false）
	# 同时打印调试信息
	for play in plays:
		var card: CardData = play.card
		print("[UI] 敌人%d 槽位%d: %s (cost=%d)" % [enemy_idx, play.slot_index, card.name, card.cost])

## 清除所有敌人意图显示
func clear_all_enemy_intents() -> void:
	if enemy_container:
		for enemy_node in enemy_container.get_children():
			var intent_label = enemy_node.get_node_or_null("IntentLabel")
			if intent_label:
				intent_label.text = ""

## 更新能量显示（圆点UI：亮=可用, 灰=本回合已用, 暗=不可用）
func update_energy_display(available: int, maximum: int, used: int = 0) -> void:
	if player_area == null:
		return
	var dots_container = player_area.get_node_or_null("EnergyDots")
	if dots_container == null:
		return
	for child in dots_container.get_children():
		child.queue_free()
	var unavailable = maxi(maximum - available - used, 0)
	for i in available:
		dots_container.add_child(_create_energy_dot("lit"))
	for i in used:
		dots_container.add_child(_create_energy_dot("used"))
	for i in unavailable:
		dots_container.add_child(_create_energy_dot("dark"))

func _create_energy_dot(state: String) -> Control:
	var dot = Panel.new()
	var style = StyleBoxFlat.new()
	match state:
		"lit":
			style.bg_color = Color(0.95, 0.8, 0.3, 1.0)
			style.border_color = Color(1.0, 0.9, 0.5, 0.8)
		"used":
			style.bg_color = Color(0.4, 0.4, 0.45, 1.0)
		"dark":
			style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	style.set_corner_radius_all(3)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	dot.add_theme_stylebox_override("panel", style)
	dot.custom_minimum_size = Vector2(7, 7)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dot

## 更新槽位/速度显示（常态不显示，仅详细信息框使用）
func update_slots_display(slots: int, speeds: Array) -> void:
	pass
