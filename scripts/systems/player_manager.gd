## 玩家管理器：代表玩家角色在战斗中的所有状态（血量、格挡、属性、buff 等）。
## 与 EnemyUnit 结构对称，但多了"选择目标"和"存储伤害"等玩家特有机制。
## Godot 特色：
## - 信号参数类型声明（如 current: int, maximum: int）是可选但推荐的做法
## - int() / float() 是类型转换函数
class_name PlayerManager

var current_hp: int            ## 当前血量
var max_hp: int                ## 最大血量
var block: int = 0             ## 当前格挡值
var base_strength: int = 0     ## 基础力量（影响攻击力）
var base_dexterity: int = 0    ## 基础敏捷（影响格挡值）
var pending_stored_damage: int = 0  ## 待存储的伤害（用于"蓄力"机制：将本回合剩余伤害留到下回合）
var buff_manager: BuffManager  ## buff 管理器
var hook_chain: HookChain      ## 钩子链
var selected_target_index: int = 0   ## 选中敌人的索引
var is_dead: bool = false      ## 是否已死亡
var selected_target: EnemyUnit = null  ## 当前选中的敌人对象

signal hp_changed(current: int, maximum: int)    ## 血量变化
signal block_changed(amount: int)                ## 格挡值变化
signal player_died()                             ## 玩家死亡
signal player_damaged(amount: int)               ## 玩家受到伤害
signal player_healed(amount: int)                ## 玩家受到治疗
signal target_selected(index: int)               ## 选中目标变化
signal counter_damage(amount: int)               ## 反击伤害（由 counter_stance buff 触发）

func _init(initial_max_hp: int = 80):
	max_hp = initial_max_hp
	current_hp = max_hp
	hook_chain = HookChain.new()
	buff_manager = BuffManager.new(hook_chain)

## 获取当前力量值（基础力量 + 力量 buff 层数）
func get_strength() -> int:
	var buff = buff_manager.get_buff_by_id("strength")
	return base_strength + (buff.stacks if buff else 0)

## 获取当前敏捷值（基础敏捷 + 敏捷 buff 层数）
func get_dexterity() -> int:
	var buff = buff_manager.get_buff_by_id("dexterity")
	return base_dexterity + (buff.stacks if buff else 0)

## 获取待释放的存储伤害值
func get_stored_power() -> int:
	return pending_stored_damage

## 获取总伤害加成（基础力量 + 所有 buff 的 damage_add 修正值之和）
func get_total_damage() -> int:
	return base_strength + int(buff_manager.get_flat_add("damage"))

## 预估攻击伤害：按完整的钩子链流程计算一次（用于 UI 显示预览值）
## 流程：基础攻击力 → 倍率 → 加算 → 最终倍率
func get_expected_attack_damage() -> int:
	var v = hook_chain.trigger("calc_attack_base", base_strength, {})
	v = hook_chain.trigger("calc_attack_mult", int(v), {})
	v = hook_chain.trigger("calc_attack_damage", v, {})
	v = hook_chain.trigger("calc_attack_final", v, {})
	return int(v)

## 获取总格挡值（基础敏捷 + 所有 buff 的 block_add 修正值之和）
func get_total_block() -> int:
	return base_dexterity + int(buff_manager.get_flat_add("block"))

## 设置选中的敌人目标
func set_selected_target(index: int) -> void:
	selected_target_index = index
	target_selected.emit(index)

## 受到伤害，返回实际伤害值
## 拥有 counter_stance（反击架势）buff 时，被格挡的伤害会触发反击
func take_damage(amount: int) -> int:
	if is_dead or amount <= 0: return 0
	# 经过钩子链处理（如易伤会放大伤害）
	var actual_damage = int(hook_chain.trigger("on_damage_taken", amount, {"source_type": "enemy"}))
	if block > 0:
		if block >= actual_damage:
			var blocked = actual_damage; block -= actual_damage; block_changed.emit(block)
			# 反击架势：格挡的伤害值转为反击伤害
			if buff_manager.has_buff("counter_stance"): counter_damage.emit(blocked)
			return 0
		else:
			actual_damage -= block; block = 0; block_changed.emit(block)
	current_hp = maxi(current_hp - actual_damage, 0)
	hp_changed.emit(current_hp, max_hp); player_damaged.emit(actual_damage)
	if current_hp <= 0: is_dead = true; player_died.emit()
	return actual_damage

## 获得格挡值
func gain_block(amount: int) -> void:
	if amount <= 0: return
	block += amount; block_changed.emit(block)

## 回复血量，受 heal_mult 倍率加成，返回实际回复值
func heal(amount: int) -> int:
	if amount <= 0: return 0
	var heal_mult = buff_manager.get_mult("heal")
	var actual_heal = int(amount * heal_mult)
	var old_hp = current_hp
	current_hp = mini(current_hp + actual_heal, max_hp)
	var healed = current_hp - old_hp
	if healed > 0: hp_changed.emit(current_hp, max_hp); player_healed.emit(healed)
	return healed

func reset_block() -> void: block = 0; block_changed.emit(block)

## 设置最大血量（当前血量不会超过新的最大值）
func set_max_hp(value: int) -> void: max_hp = value; current_hp = mini(current_hp, max_hp); hp_changed.emit(current_hp, max_hp)

func is_alive() -> bool: return not is_dead and current_hp > 0

## 获取血量百分比（0.0 ~ 1.0）
func get_hp_percent() -> float: return float(current_hp) / float(max_hp)

## 给玩家施加 buff
func apply_buff(buff: BuffData) -> void: buff_manager.apply_buff(buff)
