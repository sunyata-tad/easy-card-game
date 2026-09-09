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
@onready var desc_label: Label = $DescLabel

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
var drag_exited_hand: bool = false    ## 拖拽是否已离开手牌区域
var is_select_mode: bool = false      ## 是否处于选择模式
var is_playing_animation: bool = false ## 打出动画播放中（飞向中央/弃牌堆时阻止悬停干扰）
var is_selected: bool = false         ## 短按选中状态：放大悬停于原位，等待再次点击打出或拖动

## 交互信号
signal card_clicked(card: CardData)                              ## 卡牌被点击
## [未连接] 鼠标进入卡牌通知。若已连接接收方，请删除此标记注释。
signal card_hovered(card: CardData)                              ## 鼠标进入
## [未连接] 鼠标离开卡牌通知。若已连接接收方，请删除此标记注释。
signal card_unhovered(card: CardData)                            ## 鼠标离开
signal drag_started(card: CardData, start_pos: Vector2)          ## 开始拖拽
signal drag_updated(card: CardData, current_pos: Vector2)        ## 拖拽中
signal drag_ended(card: CardData, end_pos: Vector2)              ## 拖拽结束
signal card_released(card: CardData)                             ## 卡牌释放
signal card_cancelled(card: CardData)                            ## 卡牌操作取消
signal target_mode_started(card: CardData)                       ## 进入目标选择模式
signal target_mode_ended(card: CardData)                         ## 退出目标选择模式
signal target_mode_paused(card: CardData)                        ## 目标瞄准模式暂停：鼠标回到手牌区，恢复为拖拽模式
signal card_play_requested(card: CardData)                       ## 请求直接打出（无需目标）

## 卡牌类型对应颜色（深色系，保证白色文字可读）
const CARD_BG_COLOR := Color(0.13, 0.14, 0.18, 1.0)   ## 卡面统一底色（深色）

## buff 数据库缓存（从 data/buffs.json 加载，用于悬浮显示卡牌附带的 buff 详情）
static var _buff_db: Dictionary = {}

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

## 收集卡牌效果中的 buff/debuff 效果（用于悬浮提示）
func _get_buff_effects() -> Array:
	var buffs: Array = []
	if card_data == null:
		return buffs
	for effect in card_data.effects:
		var et: String = effect.get("effect_type", "")
		if et == "apply_buff" or et == "apply_debuff":
			var bid: String = effect.get("buff_id", effect.get("buff_type", ""))
			if bid != "":
				buffs.append({"id": bid, "stacks": effect.get("value", effect.get("stacks", 1))})
	return buffs

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
	
	# 根据稀有度设置卡面（底色/边框/底角色带/角标）
	_set_card_color(card.rarity)
	_set_rarity(card.rarity)
	
	size = Vector2(140, 180)
	pivot_offset = Vector2(size.x / 2.0, size.y)  # 以底边中点为轴：扇形旋转与悬浮放大都更自然
	original_position = position
	original_scale = scale

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

	var target_scale = Vector2(1.55, 1.55) if hover else original_scale
	var target_rotation = 0.0 if hover else original_rotation
	var target_modulate = Color(1.05, 1.05, 1.0, 1.0) if hover else Color.WHITE

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", target_scale, 0.12)
	tween.tween_property(self, "rotation_degrees", target_rotation, 0.12)
	tween.tween_property(self, "modulate", target_modulate, 0.12)

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
				# 需要目标的卡牌：区域内跟随鼠标，拖出区域回原位+箭头瞄准
				if _is_in_hand_area(global_mouse_pos):
					global_position = global_mouse_pos - size / 2
					drag_exited_hand = false
				else:
					_enter_target_aim_mode_from_drag()
			else:
				# 不需要目标：始终跟随鼠标（区域内外一致）
				global_position = global_mouse_pos - size / 2
				drag_exited_hand = not _is_in_hand_area(global_mouse_pos)
			drag_updated.emit(card_data, global_mouse_pos)
		elif is_awaiting_target:
			# 目标瞄准模式：鼠标回到手牌区域 → 恢复为拖拽模式（卡牌跟随鼠标）
			if _is_in_hand_area(global_mouse_pos):
				_exit_target_aim_to_drag(global_mouse_pos)
			else:
				drag_updated.emit(card_data, global_mouse_pos)

## 鼠标释放统一处理（全局，由 _input 调用）
func _handle_mouse_release():
	if is_awaiting_target:
		# 目标瞄准模式释放：检查鼠标是否指向目标
		var end_pos = get_global_mouse_position()
		is_awaiting_target = false
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

## 进入选中状态：保持放大悬停于原位，等待再次点击打出或拖动
func _enter_selected_state():
	is_selected = true
	z_index = 50
	_set_interacting()

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
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "position", original_position, 0.12)
	press_tween.tween_property(self, "scale", Vector2(1.55, 1.55), 0.12)
	press_tween.tween_property(self, "rotation_degrees", 0.0, 0.12)
	
	# 通知 ui_controller 显示箭头、高亮目标
	target_mode_started.emit(card_data)

## 目标瞄准模式下鼠标回到手牌区域：恢复为拖拽模式
## 卡牌从原位移动向鼠标位置（回到正常拖拽状态），箭头消失
func _exit_target_aim_to_drag(mouse_pos: Vector2):
	is_awaiting_target = false
	is_dragging = true
	drag_exited_hand = false
	
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	z_index = 50
	# 卡牌从原位平滑移动到鼠标位置，保持放大 1.55
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "global_position", mouse_pos - size / 2, 0.1)
	press_tween.tween_property(self, "scale", Vector2(1.55, 1.55), 0.1)
	press_tween.tween_property(self, "rotation_degrees", 0.0, 0.1)
	
	# 通知 ui_controller 隐藏箭头、清除高亮（保持 is_dragging=true 不重排）
	target_mode_paused.emit(card_data)

func _on_mouse_entered():
	is_hovered = true
	mouse_inside = true
	# 如果其他卡牌正在交互（按下/拖拽/选中/瞄准），不播放悬停动画
	if _interacting_card != null and _interacting_card != self and is_instance_valid(_interacting_card):
		return
	_animate_hover(true)
	card_hovered.emit(card_data)
	_show_buff_tooltip()

func _on_mouse_exited():
	is_hovered = false
	mouse_inside = false
	# 如果其他卡牌正在交互，不播放悬停动画
	if _interacting_card != null and _interacting_card != self and is_instance_valid(_interacting_card):
		return
	_animate_hover(false)
	card_unhovered.emit(card_data)
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
	press_tween.tween_property(self, "scale", Vector2(1.55, 1.55), 0.12)
	press_tween.tween_property(self, "modulate", Color(1.1, 1.1, 1.0, 1.0), 0.12)
	press_tween.tween_property(self, "rotation_degrees", 0.0, 0.12)

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
	press_tween.tween_property(self, "scale", original_scale, 0.12)
	press_tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	press_tween.tween_property(self, "position", original_position, 0.12)
	press_tween.tween_property(self, "rotation_degrees", original_rotation, 0.12)

## 开始拖拽：发射信号，播放拖拽动画（放大至 1.55，不再飞向中央）
func start_drag():
	is_dragging = true
	drag_exited_hand = false
	drag_start_pos = get_global_mouse_position()
	_set_interacting()
	drag_started.emit(card_data, drag_start_pos)
	
	if press_tween and press_tween.is_valid():
		press_tween.kill()
	
	z_index = 50
	press_tween = create_tween()
	press_tween.set_parallel(true)
	press_tween.tween_property(self, "scale", Vector2(1.55, 1.55), 0.08)
	press_tween.tween_property(self, "rotation_degrees", 0.0, 0.08)
	press_tween.tween_property(self, "modulate", Color(1.1, 1.1, 1.0, 0.9), 0.08)

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
	tween.tween_property(self, "global_position", center, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.2)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2)
	await tween.finished

## 卡牌打出流程最后一步：飞向弃牌堆位置并淡出消散（由调用方编排时序）。
func fly_to_discard(target_center: Vector2) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_center - size / 2.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector2(0.6, 0.6), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	queue_free()

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
	_clear_interacting()
	
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
	z_index = 0

func is_dragging_card() -> bool:
	return is_dragging

func is_in_target_mode() -> bool:
	return is_awaiting_target

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
	tween.tween_property(self, "scale", original_scale, 0.12)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	tween.tween_property(self, "position", original_position, 0.12)
	tween.tween_property(self, "rotation_degrees", original_rotation, 0.12)

func set_original_position(pos: Vector2):
	original_position = pos

## 悬浮时在卡牌旁边显示 buff/debuff 详情（仅当卡牌附带 buff 效果时）
func _show_buff_tooltip() -> void:
	if card_data == null or is_dragging or is_awaiting_target or is_select_mode:
		return
	var buffs := _get_buff_effects()
	if buffs.is_empty():
		return
	_hide_buff_tooltip()

	# 先构建内容，确实有 buff 详情时才弹出
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	var any := false
	for b in buffs:
		var data := _get_buff_data(b.id)
		if data.is_empty():
			continue
		any = true
		var buff_name: String = data.get("name", b.id)
		var desc_template: String = data.get("description", "")
		var desc: String = desc_template.replace("{stacks}", str(b.stacks))
		var buff_color: Color = Color(data.get("color", "#B3B3B3"))

		var name_lbl := Label.new()
		name_lbl.text = "%s%s  ×%d" % [data.get("symbol", ""), buff_name, int(b.stacks)]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", buff_color)
		vbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = desc
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(180, 0)
		vbox.add_child(desc_lbl)

	if not any:
		return

	tooltip_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.96)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	style.border_color = Color(0.5, 0.5, 0.6, 1.0)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	tooltip_panel.add_theme_stylebox_override("panel", style)
	tooltip_panel.add_child(vbox)

	var canvas := get_tree().root
	canvas.add_child(tooltip_panel)

	var gp := global_position
	var ts := tooltip_panel.get_combined_minimum_size()
	var vp := get_viewport_rect().size
	# 显示在卡牌右侧（卡牌放大后向右延伸，用放大后的宽度偏移避开）
	var px := gp.x + size.x * 1.6 + 6
	if px + ts.x > vp.x:
		px = gp.x - ts.x - 14
	var py := gp.y + size.y * 0.35
	if py + ts.y > vp.y:
		py = vp.y - ts.y - 6
	tooltip_panel.position = Vector2(px, py)
	tooltip_panel.z_index = 120

func _hide_buff_tooltip() -> void:
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
