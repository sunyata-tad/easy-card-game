## Buff 管理器，负责 buff 的增减、钩子注册/注销、层数衰减等生命周期管理。
## 核心设计：每个 buff 通过 HookChain 在攻击计算的特定阶段插入数值修改逻辑。
## Godot 特色：
## - signal 是 Godot 的事件系统（类似 UnityEvent / Python 的信号机制），通过 .emit() 触发
## - match 是模式匹配语句（类似 Python 3.10+ 的 match-case / Java 的 switch）
## - 匿名函数 func(v, c): ... 直接作为回调传入（类似 Python 的 lambda / Java 的箭头函数）
## - const 的值在脚本加载时确定，不可变（类似 Java 的 static final / Python 的模块级常量）
class_name BuffManager

## 当前持有的所有 buff 列表
var buffs: Array = []
## 关联的钩子链，用于将 buff 效果注入攻击计算流程
var hook_chain: HookChain = null

## 钩子名称统一引用 HookRegistry（唯一来源，勿在此重复定义）
## 完整钩子列表（名字 + 注释）见 scripts/effects/hook_registry.gd

## buff 变化相关信号
signal buff_applied(buff: BuffData)   ## buff 被应用时触发
signal buff_removed(buff: BuffData)   ## buff 被移除时触发
signal buff_expired(buff: BuffData)   ## buff 到期时触发
signal buffs_changed()               ## 任何 buff 变化时触发

## 走持续时间叠加（而非层数叠加）的 buff 列表
## 这些 buff 重复施加时会延长持续时间而不是增加层数
var DURATION_STACK_BUFFS: Array = ["weak", "vulnerable"]

func _init(target_hook_chain: HookChain = null):
	hook_chain = target_hook_chain

## 生成钩子的唯一标识 ID，格式："buff_<buff_id>_<suffix>"
func _hook_id(buff_id: String, suffix: String = "") -> String:
	return "buff_" + buff_id + ("_" + suffix if suffix != "" else "")

## 根据 buff 类型在 HookChain 中注册对应的攻击计算回调
## 各个 buff 的计算阶段和公式在这里定义
func _register_buff_hook(buff: BuffData) -> void:
	if hook_chain == null: return
	match buff.id:
		"strength":
			# 力量：在加算阶段增加伤害，增加量 = 层数
			hook_chain.register(HookRegistry.HOOK_CALC_ADD, func(v, _c): return v + buff.stacks, 10, _hook_id("strength"))
		"dexterity":
			# 敏捷：在格挡计算阶段增加格挡值，增加量 = 层数
			hook_chain.register(HookRegistry.HOOK_CALC_BLOCK, func(v, _c): return v + buff.stacks, 10, _hook_id("dexterity"))
		"weak":
			# 虚弱：最终伤害 × 0.75，至少为 1
			hook_chain.register(HookRegistry.HOOK_CALC_FINAL, func(v, _c): return maxi(1, int(v * 0.75)), 20, _hook_id("weak"))
		"vulnerable":
			# 易伤：受到伤害 × 1.5，至少为 1
			hook_chain.register(HookRegistry.HOOK_ON_DAMAGE_TAKEN, func(v, _c): return maxi(1, int(v * 1.5)), 20, _hook_id("vulnerable"))
		"ignore_block":
			# 无视格挡：在攻击开始时设置上下文的 ignore_block 标记
			hook_chain.register(HookRegistry.HOOK_ON_ATTACK_START, func(v, c): c["ignore_block"] = true; return v, 50, _hook_id("ignore_block"))
		"counter_stance":
			# 反击架势：攻击命中时在上下文中记录反击伤害值
			hook_chain.register(HookRegistry.HOOK_ON_ATTACK_HIT, func(v, c): if v is int and v > 0: c["counter_damage"] = v; return v, 50, _hook_id("counter_stance"))
		"no_discard":
			# 本场不弃牌：在弃牌规则门阶段设置 block_discard 标记，阻止回合末弃牌与卡牌弃牌效果
			hook_chain.register(HookRegistry.HOOK_CHECK_DISCARD, func(v, c): c["block_discard"] = true; return v, 100, _hook_id("no_discard"))

## 注销指定 buff 在所有钩子阶段注册的回调
## 不知道 buff 注册了哪个阶段，所以一次性注销所有可能的阶段（多余的 unregister 会安全忽略）
func _unregister_buff_hook(buff_id: String) -> void:
	if hook_chain == null: return
	hook_chain.unregister(HookRegistry.HOOK_CALC_BASE, _hook_id(buff_id))
	hook_chain.unregister(HookRegistry.HOOK_CALC_ADD, _hook_id(buff_id))
	hook_chain.unregister(HookRegistry.HOOK_CALC_BLOCK, _hook_id(buff_id))
	hook_chain.unregister(HookRegistry.HOOK_CALC_MULT, _hook_id(buff_id))
	hook_chain.unregister(HookRegistry.HOOK_CALC_FINAL, _hook_id(buff_id))
	hook_chain.unregister(HookRegistry.HOOK_ON_DAMAGE_TAKEN, _hook_id(buff_id))
	hook_chain.unregister(HookRegistry.HOOK_ON_ATTACK_START, _hook_id(buff_id))
	hook_chain.unregister(HookRegistry.HOOK_ON_ATTACK_HIT, _hook_id(buff_id))
	hook_chain.unregister(HookRegistry.HOOK_CHECK_DISCARD, _hook_id(buff_id))

## 更新力量 buff 的钩子（层数变化时需要重建回调，因为回调闭包捕获了旧层数）
func _update_strength_hook(new_stacks: int) -> void:
	if hook_chain == null: return
	hook_chain.unregister(HookRegistry.HOOK_CALC_ADD, _hook_id("strength"))
	hook_chain.register(HookRegistry.HOOK_CALC_ADD, func(v, _c): return v + new_stacks, 10, _hook_id("strength"))

## 应用一个 buff 到当前单位
## 已有同类型 buff 时：DURATION_STACK_BUFFS 类型的叠加持续时间，其他类型叠加层数
func apply_buff(buff: BuffData) -> void:
	var existing = get_buff_by_id(buff.id)
	if existing != null:
		if DURATION_STACK_BUFFS.has(buff.id):
			# 虚弱/易伤类：叠加持续时间
			if buff.duration > 0: existing.duration += buff.duration
		else:
			# 力量/敏捷类：叠加层数，取较长持续时间
			existing.add_stacks(buff.stacks)
			if buff.duration > 0 and existing.duration < buff.duration: existing.duration = buff.duration
			# 层数变化后需要重建钩子（因为回调闭包捕获了旧的值）
			if buff.id == "strength": _update_strength_hook(existing.stacks)
	else:
		# 新的 buff：先深拷贝一份再存储，避免外部修改影响内部状态
		var new_buff = buff.duplicate(); buffs.append(new_buff); _register_buff_hook(new_buff)
	buff_applied.emit(buff); buffs_changed.emit()

## 移除指定 buff
func remove_buff(buff_id: String) -> void:
	var buff = get_buff_by_id(buff_id)
	if buff != null: _unregister_buff_hook(buff_id); buffs.erase(buff); buff_removed.emit(buff); buffs_changed.emit()

## 按 id 查找 buff，返回 BuffData 或 null
func get_buff_by_id(buff_id: String) -> BuffData:
	for buff in buffs: if buff.id == buff_id: return buff
	return null

## 获取所有 buff 的副本（防止外部直接修改内部数组）
func get_all_buffs() -> Array: return buffs.duplicate()

## 检查是否拥有指定 buff
func has_buff(buff_id: String) -> bool: return get_buff_by_id(buff_id) != null

## 计算所有 buff 对指定属性的固定值加成之和
## 例如 stat_name="block" 时读取 modifiers["block_add"]
func get_flat_add(stat_name: String) -> float:
	var total: float = 0.0
	for buff in buffs: if buff.modifiers.has(stat_name + "_add"): total += buff.modifiers[stat_name + "_add"]
	return total

## 计算所有 buff 对指定属性的倍率加成之积
## 例如 stat_name="damage" 时读取 modifiers["damage_mult"]
func get_mult(stat_name: String) -> float:
	var total: float = 1.0
	for buff in buffs: if buff.modifiers.has(stat_name + "_mult"): total *= buff.modifiers[stat_name + "_mult"]
	return total

## 触发指定时机的持续效果（tick），返回触发的效果列表
## @param timing: 触发时机，如 "on_turn_start"
func tick_buffs(timing: String) -> Array:
	var triggered: Array = []
	for buff in buffs:
		if buff.trigger_timing == timing and buff.tick_effect.size() > 0:
			var e = buff.tick_effect.duplicate(); e.buff_id = buff.id; e.stacks = buff.stacks; triggered.append(e)
	return triggered

## 回合结束时更新所有 buff 的持续时间和层数衰减
func decrease_durations() -> void:
	var expired: Array = []
	for buff in buffs:
		buff.decrease_duration()
		# 处理层数衰减：固定值衰减或百分比衰减
		if buff.stack_decay.has("on_turn_end"): buff.remove_stacks(buff.stack_decay["on_turn_end"])
		elif buff.stack_decay.has("on_turn_end_pct"): buff.remove_stacks(max(int(buff.stacks * buff.stack_decay["on_turn_end_pct"]), 1))
		if buff.is_expired(): expired.append(buff)
	for buff in expired: _unregister_buff_hook(buff.id); buffs.erase(buff); buff_expired.emit(buff)
	if expired.size() > 0: buffs_changed.emit()

## 在特定事件触发时衰减 buff 层数（如 "on_card_played"）
func decay_on_event(event: String) -> void:
	var expired: Array = []
	for buff in buffs:
		if buff.stack_decay.has(event): buff.remove_stacks(buff.stack_decay[event])
		if buff.is_expired(): expired.append(buff)
	for buff in expired: _unregister_buff_hook(buff.id); buffs.erase(buff); buff_expired.emit(buff)
	if expired.size() > 0: buffs_changed.emit()

## 清除所有 buff
func clear_all_buffs() -> void:
	for buff in buffs: _unregister_buff_hook(buff.id)
	buffs.clear(); buffs_changed.emit()

## 移除标记为"回合结束时移除"的 buff（trigger_timing == "on_turn_end_remove"）
func remove_at_turn_end() -> void:
	var to_remove: Array = []
	for buff in buffs: if buff.trigger_timing == "on_turn_end_remove": to_remove.append(buff)
	for buff in to_remove: _unregister_buff_hook(buff.id); buffs.erase(buff); buff_expired.emit(buff)
	if to_remove.size() > 0: buffs_changed.emit()
