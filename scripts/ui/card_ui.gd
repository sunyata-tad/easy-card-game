## 卡牌 UI 节点：显示单张卡牌的视觉效果（名称、类型、描述、颜色），并处理拖拽/点击/目标选择交互。
## Godot 特色：
## - extends Control 表示继承 UI 控件基类
## - @onready var x = $Path 在 _ready() 之前自动通过路径查找子节点赋值（类似 Unity 的 GetComponent + Awake）
## - _gui_input(event) 处理鼠标/键盘输入事件（类似 Unity 的 OnMouseDown + OnMouseUp）
## - _input(event) 处理全局输入事件（类似 Unity 的 Update 中检测 Input）
## - accept_event() 阻止事件继续向上传播
class_name CardUI
extends Control

## @onready: 在节点进入场景树时自动查找子节点并赋值
@onready var frame: Panel = $Frame
@onready var name_label: Label = $NameLabel
@onready var type_label: Label = $TypeLabel
@onready var desc_label: RichTextLabel = $DescLabel

var card_data: CardData               ## 关联的卡牌数据
var player_manager: PlayerManager     ## 玩家状态引用（用于动态计算伤害预览）
var is_hovered: bool = false          ## 鼠标是否悬停
var original_position: Vector2        ## 原始位置（用于放回手牌）
var original_scale: Vector2 = Vector2.ONE  ## 原始缩放
var original_rotation: float = 0.0   ## 原始旋转角度

## 拖拽状态
var is_dragging: bool = false         ## 是否正在拖拽
var drag_start_pos: Vector2           ## 拖拽起始位置
var is_pressed: bool = false          ## 是否被按下
var press_tween: Tween = null         ## 按下动画的 tween 对象
var mouse_inside: bool = true         ## 鼠标是否在卡牌区域内
var is_awaiting_target: bool = false  ## 是否在等待选择目标（需要目标的卡牌拖出手牌区后进入箭头瞄准模式）
var tooltip_panel: PanelContainer = null   ## 悬停提示面板
var tooltip_panels: Array = []             ## 多个关键词悬浮框列表

var drag_exited_hand: bool = false    ## 拖拽是否已离开手牌区域
var is_select_mode: bool = false      ## 是否处于选择模式
var is_playing_animation: bool = false ## 打出动画播放中（飞向中央/弃牌堆时阻止悬停干扰）
var is_selected: bool = false         ## 短按选中状态：放大悬停于原位，等待再次点击打出或拖动

## 目标选择交互参数
const DRAG_SPRING_FACTOR := 0.3      ## 小范围拖动弹簧系数（卡牌移动量/鼠标移动量）
const TARGET_TRIGGER_DIST := 60.0    ## 触发目标瞄准模式的拖动距离阈值
const SELECTED_SCALE := 1.35         ## 选中状态缩放
const SELECTED_UP_OFFSET := 50.0     ## 选中状态上移距离（像素）
var drag_start_global_pos: Vector2   ## 拖拽起始时卡牌的全局位置

## 交互信号
signal card_clicked(card: CardData)                              ## 卡牌被点击
signal drag_started(card: CardData, start_pos: Vector2)          ## 开始拖拽
signal drag_updated(card: CardData, current_pos: Vector2)        ## 拖拽中
signal drag_ended(card: CardData, end_pos: Vector2)              ## 拖拽结束
signal card_cancelled(card: CardData)                            ## 卡牌操作取消
signal target_mode_started(card: CardData)                       ## 进入目标选择模式
signal target_mode_ended(card: CardData)                         ## 退出目标选择模式
signal target_mode_paused(card: CardData)                        ## 目标瞄准模式暂停：鼠标回到手牌区，恢复为拖拽模式
signal card_play_requested(card: CardData)                       ## 请求直接打出（无需目标）

## 卡牌类型对应颜色（深色系，保证白色文字可读）
const CARD_BG_COLOR := Color(0.13, 0.14, 0.18, 1.0)   ## 卡面统一底色（深色）

## 当前正在交互的卡牌实例（按下/拖拽/选中/瞄准目标时设置）
## 其他卡牌在悬停时检查此变量，避免拖动中误放大其他卡牌
static var _interacting_card: CardUI = null

## 标记本卡牌为当前交互卡牌
func _set_interacting():
	_interacting_card = self

## 清除本卡牌的交互标记（仅当本卡牌是当前交互卡牌时才清除）
func _clear_interacting():
	if _interacting_card == self:
		_interacting_card = null

## Godot 生命周期：节点进入场景树时调用
func _ready():
	original_position = position
	_setup_signals()

## 连接鼠标进出信号
func _setup_signals():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## 根据 CardData 设置卡牌显示内容
func setup(card: CardData, pm: PlayerManager = null):
	card_data = card
	player_manager = pm
	
	var name_lbl = get_node_or_null("NameLabel")
	var type_lbl = get_node_or_null("TypeLabel")
	var desc_lbl = get_node_or_null("DescLabel")
	
	if name_lbl:
		name_lbl.text = card.name
	
	if type_lbl:
		type_lbl.text = _get_type_text(card.type)
	
	if desc_lbl:
		desc_lbl.text = _get_display_text()
	
	var cost_lbl = get_node_or_null("CostLabel")
	if cost_lbl:
		cost_lbl.text = str(card.cost)
		cost_lbl.visible = true
	var cost_bg = get_node_or_null("CostBg")
	if cost_bg:
		cost_bg.visible = true
	
	# 根据稀有度设置卡面（底色/边框/底角色带/角标）
	_set_card_color(card.rarity)
	_set_rarity(card.rarity)
	_set_frame_art(card.rarity)
	
	# 加载卡牌美术
	var art_rect = get_node_or_null("ArtRect")
	if art_rect:
		if card.art != "":
			var tex = load(card.art)
			if tex:
				art_rect.texture = tex
				art_rect.visible = true
			else:
				art_rect.visible = false
		else:
			art_rect.visible = false
	
	size = Vector2(160, 210)
	pivot_offset = Vector2(size.x / 2.0, size.y)  # 以底边中点为轴：扇形旋转与悬浮放大都更自然
	original_position = position
	original_scale = Vector2(0.72, 0.72)
	scale = original_scale

## 获取卡牌描述文字（如果效果涉及玩家属性则动态计算显示值）
func _get_display_text() -> String:
	if card_data == null:
		return ""
	
	for effect in card_data.effects:
		var effect_type = effect.get("effect_type", "")
		var value = effect.get("value", 0)
		
		if effect_type == "temp_damage_boost":
			return "本回合伤害+%d" % value
		
		if effect_type == "damage_boost":
			return "伤害永久+%d" % value
		
		var base_stat = effect.get("base_stat", "")
		var multiplier = effect.get("multiplier", 1.0)
		
		# 基于属性计算效果值（如"基于力量造成伤害"）
		if base_stat != "" and player_manager:
			var stat_value = 0
			if base_stat == "strength":
				stat_value = player_manager.get_strength()
			elif base_stat == "dexterity":
				stat_value = player_manager.get_dexterity()
			
			var final_value = int(stat_value * multiplier)
			
			if effect_type == "damage":
				return "造成 %d 点伤害" % final_value
			elif effect_type == "block":
				return "获得 %d 点护甲" % final_value
	
	return card_data.get_description_text()

## 设置卡面样式：统一深色底 + 稀有度边框色 + 稀有度色光晕
func _set_card_color(rarity: String) -> void:
	var frm := get_node_or_null("Frame") as Panel
	if frm == null:
		return
	var base: StyleBoxFlat = frm.get_theme_stylebox("panel") as StyleBoxFlat
	if base == null:
		return
	var rarity_color := _get_rarity_color(rarity)
	var sb := base.duplicate() as StyleBoxFlat
	sb.bg_color = CARD_BG_COLOR
	sb.border_color = rarity_color
	sb.shadow_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.55)
	frm.add_theme_stylebox_override("panel", sb)

## 设置底部稀有度区域（底角色带 + 角标文字）
func _set_rarity(rarity: String) -> void:
	var band := get_node_or_null("RarityBand") as Panel
	if band:
		var band_base: StyleBoxFlat = band.get_theme_stylebox("panel") as StyleBoxFlat
		if band_base:
			var sb := band_base.duplicate() as StyleBoxFlat
			sb.bg_color = _get_rarity_color(rarity)
			band.add_theme_stylebox_override("panel", sb)
	var lbl := get_node_or_null("RarityLabel") as Label
	if lbl == null:
		return
	lbl.text = _get_rarity_text(rarity)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))

## 加载稀有度对应的卡框 PNG（叠加在最上层，中心透明不遮挡内容）
func _set_frame_art(rarity: String) -> void:
	var frame_path := "res://art_assets/frames/frame_basic.png"
	match rarity:
		"uncommon":
			frame_path = "res://art_assets/frames/frame_uncommon.png"
		"rare":
			frame_path = "res://art_assets/frames/frame_rare.png"
		"epic":
			frame_path = "res://art_assets/frames/frame_epic.png"

	var frame_rect := get_node_or_null("FrameArt") as TextureRect
	if frame_rect:
		var tex = load(frame_path)
		if tex:
			frame_rect.texture = tex
			frame_rect.visible = true
		else:
			frame_rect.visible = false
	if rarity != "basic":
		var gem := get_node_or_null("RarityGem") as Panel
		if gem:
			var gem_style := StyleBoxFlat.new()
			gem_style.bg_color = _get_rarity_color(rarity)
			gem_style.set_corner_radius_all(7)
			gem_style.border_width_left = 1
			gem_style.border_width_top = 1
			gem_style.border_width_right = 1
			gem_style.border_width_bottom = 1
			gem_style.border_color = Color(1, 1, 1, 0.8)
			gem.add_theme_stylebox_override("panel", gem_style)
			gem.visible = true
	else:
		var gem := get_node_or_null("RarityGem") as Panel
		if gem:
			gem.visible = false

func _get_type_text(type: String) -> String:
	match type:
		"attack": return "攻击"
		"skill": return "技能"
		"power": return "能力"
		_: return ""

## 鼠标悬停动画：放大卡牌本体（便于阅读效果）+ 摆正 + 轻微高亮
func _animate_hover(hover: bool):
	# 按下中/目标选择中/选择模式中/打出动画播放中/选中状态中跳过悬停动画
	if is_pressed or is_awaiting_target or is_select_mode or is_playing_animation or is_selected:
		return

	if hover:
		z_index = 50
	else:
		z_index = 0

	var target_scale = Vector2(1.3, 1.3) if hover else original_scale
	var target_rotation = 0.0 if hover else original_rotation
	var target_modulate = Color(1.05, 1.05, 1.0, 1.0) if hover else Color.WHITE

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", target_scale, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", target_rotation, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", target_modulate, 0.12).set_ease(Tween.EASE_OUT)

## 处理此节点范围内的鼠标输入事件（类似 Unity UI 的 OnPointerDown/Up）
## 新交互逻辑（更丝滑的拖拽体验）：
## 1. 左键按下 → 卡牌放大至 1.55（看清文本），记录起始位置
## 2. 鼠标移动超过 10px → 进入拖拽模式（卡牌跟随鼠标）
## 3. 短按（未拖拽）释放 → 进入选中状态（保持放大），再次点击打出
## 4. 拖拽中释放：
##    - 不需要目标 + 拖出手牌区 → 打出
##    - 不需要目标 + 仍在手牌区 → 回原位取消
##    - 需要目标 + 仍在手牌区 → 回原位取消
## 5. 需要目标的卡牌拖出手牌区 → 自动回原位保持放大 + 显示箭头瞄准
## 6. 选中状态下再次点击：不需要目标直接打出，需要目标进入箭头瞄准
## 7. 右键 → 取消当前操作
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if card_data:
					if is_selected:
						# 选中状态下再次点击 = 打出
						is_selected = false
						if _needs_target():
							_enter_target_aim_mode()
						else:
							card_play_requested.emit(card_data)
					elif is_awaiting_target:
						cancel_target_mode()
					elif is_select_mode:
						is_pressed = true
						mouse_inside = true
						drag_start_pos = get_global_mouse_position()
						_set_interacting()
					else:
						is_pressed = true
						mouse_inside = true
						drag_exited_hand = false
						drag_start_pos = get_global_mouse_position()
						_set_interacting()
						_animate_press_down()
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# 右键取消：取消目标选择/拖拽/选中
			if is_pressed or is_awaiting_target or is_selected:
				_cancel_press()
				card_cancelled.emit(card_data)
			accept_event()

## 全局输入事件处理（用于跟踪鼠标移动与释放，即使鼠标离开卡牌区域也能检测）
## 新行为：
## - 鼠标释放（全局）→ 统一由 _handle_mouse_release 处理
## - 选中状态下点击非本卡牌 → 取消选中
## - 鼠标移动超过阈值 → 进入拖拽
## - 拖拽中：不需要目标跟随鼠标；需要目标区域内跟随、拖出区域回原位+箭头瞄准
func _input(event: InputEvent):
	if not (is_pressed or is_awaiting_target or is_selected):
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 选中状态下点击非本卡牌 → 取消选中
			if is_selected and not _is_mouse_on_card():
				_cancel_press()
		else:
			_handle_mouse_release()
		return
	
	if event is InputEventMouseMotion:
		var global_mouse_pos = get_global_mouse_position()
		
		# 选中状态下移动 > 阈值 → 进入拖拽
		if is_selected and not is_dragging:
			var distance = global_mouse_pos.distance_to(drag_start_pos)
			if distance > 10.0:
				is_selected = false
				is_pressed = true
				start_drag()
		
		# 按下状态下移动 > 阈值 → 进入拖拽
		if is_pressed and not is_dragging and not is_awaiting_target and not is_select_mode:
			var distance = global_mouse_pos.distance_to(drag_start_pos)
			if distance > 10.0:
				start_drag()
		
		if is_dragging:
			if _needs_target():
				# 需要目标：小范围弹簧拖动，超阈值进入选中+箭头模式
				var mouse_offset: Vector2 = global_mouse_pos - drag_start_pos
				if mouse_offset.length() < TARGET_TRIGGER_DIST:
					global_position = drag_start_global_pos + mouse_offset * DRAG_SPRING_FACTOR
					drag_exited_hand = false
				else:
					_enter_target_aim_mode_from_drag()
			else:
				# 不需要目标：始终跟随鼠标（区域内外一致）
				global_position = global_position.lerp(global_mouse_pos - size / 2, 0.75)
				drag_exited_hand = not _is_in_hand_area(global_mouse_pos)
			drag_updated.emit(card_data, global_mouse_pos)
		elif is_awaiting_target:
			# 目标瞄准模式：鼠标回到阈值内 → 恢复小范围拖动
			var aim_offset: Vector2 = global_mouse_pos - drag_start_pos
			if aim_offset.length() < TARGET_TRIGGER_DIST:
				_exit_target_aim_to_drag(global_mouse_pos)
			else:
				drag_updated.emit(card_data, global_mouse_pos)

## 鼠标释放统一处理（全局，由 _input 调用）
func _handle_mouse_release():
	if is_awaiting_target:
		# 目标瞄准模式释放：检查鼠标是否指向目标
		var end_pos = get_global_mouse_position()
		is_awaiting_target = false
		is_pressed = false
		is_dragging = false
		# 先发射 drag_ended 让 ui_controller 检查目标并决定打出/取消
		drag_ended.emit(card_data, end_pos)
		drag_updated.emit(card_data, end_pos)
		# 然后发射 target_mode_ended 清理箭头与高亮
		target_mode_ended.emit(card_data)
		_clear_interacting()
		return
	
	if not is_pressed:
		return
	
	is_pressed = false
	
	if is_select_mode:
		if mouse_inside:
			card_clicked.emit(card_data)
		_clear_interacting()
		return
	
	if is_dragging:
		if _needs_target():
			# 需要目标且拖拽中（仍在区域内）→ 回原位取消
			_cancel_press()
		elif drag_exited_hand:
			# 不需要目标且拖出手牌区 → 打出
			card_play_requested.emit(card_data)
			end_drag()
		else:
			# 不需要目标且仍在手牌区 → 回原位取消
			_cancel_press()
	else:
		# 短按（未拖拽）→ 进入选中状态（保持放大等待再次点击）
		if mouse_inside:
			_enter_selected_state()
		else:
			_cancel_press()

## 判断鼠标是否在本卡牌上（用于选中状态下点击非本卡牌取消选中）
func _is_mouse_on_card() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())

## 进入选中状态：上移+放大，等待再次点击打出或拖动
func _enter_selected_state():
	is_selected = true
	z_index = 50
	_set_interacting()
	
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	var selected_pos: Vector2 = original_position + Vector2(0, -SELECTED_UP_OFFSET)
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "position", selected_pos, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	press_tween.tween_property(self, "scale", Vector2(SELECTED_SCALE, SELECTED_SCALE), 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	press_tween.tween_property(self, "rotation_degrees", 0.0, 0.18).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(self, "modulate", Color(1.15, 1.08, 0.7, 1.0), 0.18).set_ease(Tween.EASE_OUT)

## 选中状态下再次点击进入目标瞄准模式（需要目标的卡牌）
func _enter_target_aim_mode():
	is_awaiting_target = true
	is_selected = false
	drag_start_pos = get_global_mouse_position()
	z_index = 50
	_set_interacting()
	target_mode_started.emit(card_data)

## 拖拽中拖出手牌区进入目标瞄准模式：卡牌回原位保持放大 + 显示箭头替代卡牌
func _enter_target_aim_mode_from_drag():
	is_dragging = false
	is_awaiting_target = true
	drag_exited_hand = true
	_set_interacting()

	if press_tween and press_tween.is_valid():
		press_tween.kill()

	z_index = 50
	# 选中状态：放大 + 摆正 + 上移
	var selected_pos: Vector2 = original_position + Vector2(0, -SELECTED_UP_OFFSET)
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "position", selected_pos, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	press_tween.tween_property(self, "scale", Vector2(SELECTED_SCALE, SELECTED_SCALE), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	press_tween.tween_property(self, "rotation_degrees", 0.0, 0.12).set_ease(Tween.EASE_OUT)

	# 通知 ui_controller 显示箭头、高亮目标
	target_mode_started.emit(card_data)

## 目标瞄准模式下鼠标回到阈值内：恢复小范围拖动
func _exit_target_aim_to_drag(mouse_pos: Vector2):
	is_awaiting_target = false
	is_dragging = true
	drag_exited_hand = false

	if press_tween and press_tween.is_valid():
		press_tween.kill()

	z_index = 50
	# 回到小范围拖动：卡牌移向弹簧位置
	var mouse_offset: Vector2 = mouse_pos - drag_start_pos
	var spring_pos: Vector2 = drag_start_global_pos + mouse_offset * DRAG_SPRING_FACTOR
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "global_position", spring_pos, 0.1).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.1).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(self, "rotation_degrees", 0.0, 0.1).set_ease(Tween.EASE_OUT)
	
	# 通知 ui_controller 隐藏箭头、清除高亮（保持 is_dragging=true 不重排）
	target_mode_paused.emit(card_data)

func _on_mouse_entered():
	is_hovered = true
	mouse_inside = true
	# 如果其他卡牌正在交互（按下/拖拽/选中/瞄准），不播放悬停动画
	if _interacting_card != null and _interacting_card != self and is_instance_valid(_interacting_card):
		return
	_animate_hover(true)

	_show_buff_tooltip()

func _on_mouse_exited():
	is_hovered = false
	mouse_inside = false
	# 如果其他卡牌正在交互，不播放悬停动画
	if _interacting_card != null and _interacting_card != self and is_instance_valid(_interacting_card):
		return
	_animate_hover(false)

	_hide_buff_tooltip()

## 判断卡牌是否需要选择目标（single_enemy 或 single_ally 类型）
func _needs_target() -> bool:
	if card_data == null:
		return false
	var target_type = card_data.target_type
	return target_type == "single_enemy" or target_type == "single_ally"

## 按下动画：放大至 1.55（看清文本），摆正，轻微高亮
func _animate_press_down():
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	z_index = 50
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	press_tween.tween_property(self, "modulate", Color(1.1, 1.1, 1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(self, "rotation_degrees", 0.0, 0.1).set_ease(Tween.EASE_OUT)

## 取消按下状态，恢复原始位置与缩放
func _cancel_press():
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	is_pressed = false
	is_dragging = false
	is_awaiting_target = false
	is_selected = false
	_clear_interacting()
	
	z_index = 0
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "scale", original_scale, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	press_tween.tween_property(self, "modulate", Color.WHITE, 0.2).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(self, "position", original_position, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	press_tween.tween_property(self, "rotation_degrees", original_rotation, 0.2).set_ease(Tween.EASE_OUT)

## 开始拖拽：发射信号，播放拖拽动画（放大至 1.55，不再飞向中央）
func start_drag():
	is_dragging = true
	drag_exited_hand = false
	drag_start_pos = get_global_mouse_position()
	drag_start_global_pos = global_position
	_set_interacting()
	drag_started.emit(card_data, drag_start_pos)
	
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	z_index = 50
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.08).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(self, "rotation_degrees", 0.0, 0.08).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(self, "modulate", Color(1.1, 1.1, 1.0, 0.9), 0.08).set_ease(Tween.EASE_OUT)

func _is_in_hand_area(pos: Vector2) -> bool:
	var parent = get_parent()
	if parent == null:
		return false
	var hand_rect = parent.get_global_rect()
	var vp_size = get_viewport_rect().size
	# 手牌判定矩形：从 HandArea 左上角到屏幕右下角
	# - 左侧角色区域（x < hand_rect.position.x）不判断（可能存在指向玩家的卡牌）
	# - 下方填满到屏幕底部（只有交互按钮，无目标，扩大拖动范围）
	var judge_rect := Rect2(
		hand_rect.position,
		Vector2(vp_size.x - hand_rect.position.x, vp_size.y - hand_rect.position.y)
	)
	return judge_rect.has_point(pos)
	
func end_drag():
	is_dragging = false
	drag_exited_hand = false
	_clear_interacting()
	var end_pos = get_global_mouse_position()
	drag_ended.emit(card_data, end_pos)
	drag_updated.emit(card_data, end_pos)

## 卡牌打出流程第一步：从手牌飞向屏幕中央（等待效果结算期间悬停于此）。
func fly_to_center() -> void:
	is_playing_animation = true
	var vp_size = get_viewport_rect().size
	var center = Vector2(vp_size.x / 2.0 - size.x / 2.0, vp_size.y / 2.0 - size.y / 2.0 - 50.0)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", center, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.18)
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.18)
	await tween.finished

## 卡牌打出流程最后一步：生成统一小卡牌占位图片，沿抛物线飞向弃牌堆并淡出消散。
func fly_to_discard(target_center: Vector2) -> void:
	var start_center: Vector2 = global_position + size / 2.0

	# 创建统一小卡牌占位图片（后续替换为正式图标）
	var mini_size := Vector2(50, 65)
	var mini_card := Panel.new()
	mini_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_card.z_index = 100
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.18, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.72, 0.72, 0.75, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	mini_card.add_theme_stylebox_override("panel", style)
	get_parent().add_child(mini_card)
	mini_card.size = mini_size
	mini_card.global_position = start_center - mini_size / 2.0

	# 原卡牌立即隐藏
	modulate.a = 0.0

	# 小卡牌沿抛物线飞向弃牌堆
	var fly_time: float = 0.4
	var arc_height: float = 120.0
	var tween = mini_card.create_tween()
	tween.set_parallel(true)
	tween.tween_method(_parabola_pos.bind(mini_card, start_center, target_center, arc_height), 0.0, 1.0, fly_time)
	tween.tween_property(mini_card, "modulate:a", 0.0, 0.15).set_delay(fly_time - 0.15)
	await tween.finished

	mini_card.queue_free()
	queue_free()

## 抛物线位置插值（供 fly_to_discard 的 tween_method 调用）：水平匀速，垂直叠加抛物线弧度
func _parabola_pos(t: float, node: Control, start: Vector2, end: Vector2, arc_h: float) -> void:
	var x: float = lerpf(start.x, end.x, t)
	var y: float = lerpf(start.y, end.y, t) - arc_h * 4.0 * t * (1.0 - t)
	node.global_position = Vector2(x, y) - node.size / 2.0

func reset_position():
	_hide_buff_tooltip()

	position = original_position
	scale = original_scale
	rotation_degrees = original_rotation
	is_dragging = false
	is_pressed = false
	is_awaiting_target = false
	is_playing_animation = false
	is_selected = false
	_is_queued = false
	_clear_interacting()
	
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	modulate = Color.WHITE
	z_index = 0

## B4: 设置/取消队列状态（新流程选牌阶段）
## 队列的卡牌上移20px并加蓝色边框
var _is_queued: bool = false
func set_queued(queued: bool) -> void:
	_is_queued = queued
	if queued:
		# 上移表示已队列
		position = original_position + Vector2(0, -25)
		modulate = Color(0.6, 0.8, 1.0, 1.0)  # 蓝色调
		z_index = 5
	else:
		position = original_position
		modulate = Color.WHITE
		z_index = 0

## 仅清理交互状态标志，不重置位置/缩放（打出动画接管位置时使用）
func clear_interaction_state():
	is_dragging = false
	is_pressed = false
	is_awaiting_target = false
	is_selected = false
	_clear_interacting()
	z_index = 0
	
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	modulate = Color.WHITE
	z_index = 0

func restore_to_layout_state():
	is_dragging = false
	is_pressed = false
	is_awaiting_target = false
	is_playing_animation = false
	is_selected = false
	_clear_interacting()
	
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	modulate = Color.WHITE
	scale = original_scale
	position = original_position
	rotation_degrees = original_rotation
	z_index = 0

func is_dragging_card() -> bool:
	return is_dragging

func is_in_target_mode() -> bool:
	return is_awaiting_target

func is_hovered_card() -> bool:
	return is_hovered

func is_selected_card() -> bool:
	return is_selected

## [未调用] 进入目标选择模式。若已实现调用方，请删除此标记注释。
func start_target_mode():
	is_awaiting_target = true
	is_selected = false
	drag_start_pos = get_global_mouse_position()
	z_index = 50
	_set_interacting()
	
	target_mode_started.emit(card_data)

func cancel_target_mode():
	is_awaiting_target = false
	is_selected = false
	_clear_interacting()
	target_mode_ended.emit(card_data)
	
	z_index = 0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", original_scale, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", original_position, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "rotation_degrees", original_rotation, 0.2).set_ease(Tween.EASE_OUT)

func set_original_position(pos: Vector2):
	original_position = pos

## 悬浮时在卡牌旁边显示词条/buff解释 + buff/debuff 详情
## 每个关键词一个独立悬浮框，垂直堆叠在卡牌右侧
func _show_buff_tooltip() -> void:
	if card_data == null or is_dragging or is_awaiting_target or is_select_mode:
		return
	_hide_buff_tooltip()

	var infos = CardInfoBox.get_keyword_infos(card_data)
	if infos.is_empty():
		return

	var canvas := get_tree().root
	var gp := global_position
	var vp := get_viewport_rect().size

	var px := gp.x + size.x * 1.4 + 8
	var py_start := gp.y + size.y * 0.2
	var panel_width := 170

	for info in infos:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.06, 0.1, 0.96)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(8)
		style.border_color = Color(0.5, 0.5, 0.6, 1.0)
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_width_left = 1
		style.border_width_right = 1
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 2)
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(panel_width, 0)

		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.text = "[b]%s[/b]：%s" % [info.name, info.desc]
		rtl.add_theme_color_override("default_color", Color(0.85, 0.88, 0.92))
		rtl.add_theme_font_size_override("normal_font_size", 12)
		rtl.add_theme_font_size_override("bold_font_size", 12)
		panel.add_child(rtl)

		canvas.add_child(panel)
		tooltip_panels.append(panel)

	await get_tree().process_frame
	var py := py_start
	for panel in tooltip_panels:
		if not is_instance_valid(panel):
			continue
		var ts: Vector2 = panel.get_combined_minimum_size()
		if px + ts.x > vp.x:
			panel.position = Vector2(gp.x - panel_width - 14, py)
		else:
			panel.position = Vector2(px, py)
		if panel.position.y + ts.y > vp.y:
			panel.position.y = vp.y - ts.y - 6
		panel.z_index = 120
		py += ts.y + 4

func _hide_buff_tooltip() -> void:
	for panel in tooltip_panels:
		if panel and is_instance_valid(panel):
			panel.queue_free()
	tooltip_panels.clear()
	if tooltip_panel and is_instance_valid(tooltip_panel):
		tooltip_panel.queue_free()
	tooltip_panel = null


func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.72, 0.72, 0.75)
		"uncommon": return Color(0.3, 0.8, 0.5)
		"rare": return Color(0.35, 0.6, 1.0)
		"epic": return Color(0.7, 0.4, 0.95)
		_: return Color(0.7, 0.7, 0.7)

## 稀有度中文名（角标显示）
func _get_rarity_text(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"uncommon": return "罕见"
		"rare": return "稀有"
		"epic": return "史诗"
		_: return rarity
