## 效果解析器：将卡牌的 effect 字典翻译成实际的游戏操作（伤害/格挡/治疗/抽牌/buff等）。
## 这是卡牌效果系统的核心，所有卡牌效果的最终执行都经过这个类。
##
## ========== 可扩展架构说明 ==========
## 效果处理器采用"字典注册模式"：effect_type → 处理函数的映射表。
## - 内置效果在 _init() 中通过 _register_default_handlers() 注册
## - 新增效果只需写一个签名为 func(effect: Dictionary, source, target) -> Dictionary 的函数，
##   然后调用 register_effect_handler("新效果名", 处理函数) 即可，无需修改 resolve_effect()
## - 处理器可通过注册表互相调用，实现"复合效果"（如"先施加力量buff，再造成基于力量的伤害"）
##
## 旧版使用 match 硬编码分发，现已改为查表分发，向后兼容所有现有卡牌。
class_name EffectResolver

var card_database: CardDatabase         ## 卡牌数据库，用于根据卡牌 id 创建卡牌实例
var card_system: CardSystem = null      ## 卡牌系统引用，用于抽牌/弃牌/消耗等操作
var _temp_attack_boost: int = 0         ## 累积的临时攻击力加成
var _temp_hook_ids: Array = []          ## 临时钩子的 id 列表，用于清理

## 效果处理器注册表：{ "effect_type": Callable }
## Callable 签名为 func(effect: Dictionary, source, target) -> Dictionary
var _handlers: Dictionary = {}

signal effect_resolved(effect_type: int, result: Dictionary)  ## 效果结算完成
signal damage_dealt(target, amount: int)    ## 造成了伤害
signal block_gained(target, amount: int)    ## 获得了格挡
signal healing_done(target, amount: int)    ## 完成了治疗
signal cards_drawn(count: int)              ## 抽了牌
signal buff_applied(target, buff: BuffData) ## 施加了 buff

func _init():
	card_database = CardDatabase.new()
	_register_default_handlers()

## ========== 注册表管理 ==========

## 注册一个新的效果处理器
## @param effect_type: 效果类型字符串，在卡牌 JSON 中的 effect_type 字段使用
## @param handler: 处理函数，签名为 func(effect: Dictionary, source, target) -> Dictionary
##
## 示例：注册一个"对全体敌人施加易伤"的复合效果
##   resolver.register_effect_handler("aoe_vulnerable", func(e, s, t):
##       for enemy in enemy_system.get_alive_enemies():
##           resolver.resolve_effect({"effect_type": "apply_debuff", "buff_id": "vulnerable", "value": e.get("value", 1)}, s, enemy)
##       return {"success": true, "value": e.get("value", 0)})
func register_effect_handler(effect_type: String, handler: Callable) -> void:
	_handlers[effect_type] = handler

## 检查是否存在指定类型的效果处理器
func has_handler(effect_type: String) -> bool:
	return _handlers.has(effect_type)

## 获取所有已注册的效果类型列表
func get_registered_effect_types() -> Array:
	return _handlers.keys()

## 连续解析多个效果（一张卡牌可以有多个效果）
func resolve_effects(effects: Array, source, target = null) -> Array:
	var results: Array = []
	for e in effects:
		results.append(resolve_effect(e, source, target))
	return results

## 解析单个效果（核心分发逻辑）
## base_stat 字段允许效果值基于玩家属性（力量/敏捷）来计算
func resolve_effect(effect: Dictionary, source, target = null) -> Dictionary:
	var effect_type_str = effect.get("effect_type", "")
	var value = effect.get("value", 0)
	var result: Dictionary = {"success": false, "value": 0}

	# 如果效果配置了 base_stat，则从源单位获取对应属性并乘以 multiplier 加到 value 上
	# 例如 base_stat="strength" multiplier=1.0 表示"基于力量值的伤害"
	var base_stat = effect.get("base_stat", "")
	var multiplier = effect.get("multiplier", 1.0)
	if base_stat != "" and source is PlayerManager:
		var stat_value = 0
		if base_stat == "strength": stat_value = source.get_strength()
		elif base_stat == "dexterity": stat_value = source.get_dexterity()
		# 写回 effect 字典，确保闭包通过 effect.get("value") 能拿到修正后的值
		effect["value"] = value + int(stat_value * multiplier)

	# 查表分发：所有处理器统一签名为 func(effect: Dictionary, source, target) -> Dictionary
	if _handlers.has(effect_type_str):
		result = _handlers[effect_type_str].call(effect, source, target)
	else:
		push_warning("EffectResolver: Unknown effect type: " + effect_type_str)

	effect_resolved.emit(effect_type_str, result)
	return result

## 获取来源单位的 HookChain
func _get_hook_chain(source) -> HookChain:
	if source is PlayerManager: return source.hook_chain
	if source is EnemyUnit: return source.hook_chain
	return null

## 结算伤害效果
## 玩家攻击时经过完整的钩子链：基础 → 倍率 → 加算 → 最终倍率
## 钩子链上下文的 ignore_block 标记可以跳过目标的格挡
func _resolve_damage(base_damage: int, source, target) -> Dictionary:
	if target == null:
		return {"success": false, "value": 0}
	var hc = _get_hook_chain(source)
	
	# 玩家攻击：使用完整钩子链计算
	if source is PlayerManager and hc:
		var ctx: Dictionary = {}
		hc.trigger("on_attack_start", 0, ctx)
		var base = hc.trigger("calc_attack_base", source.base_strength, ctx)
		base = int(hc.trigger("calc_attack_mult", int(base), ctx))
		var add = hc.trigger("calc_attack_damage", 0, ctx)
		var raw = int(base) + int(add)
		source.damage_final_mult = 1.0
		var final_dmg = hc.trigger("calc_attack_final", raw, ctx)
		hc.trigger("on_attack_hit", final_dmg, {"hit_index": 0})
		if target is EnemyUnit:
			target.take_damage(final_dmg, ctx.get("ignore_block", false))
		elif target is PlayerManager:
			target.take_damage(final_dmg)
		hc.trigger("on_attack_end", 0, ctx)
		damage_dealt.emit(target, final_dmg)
		return {"success": true, "value": final_dmg, "target": target}
	
	# 非玩家单位但有 HookChain（如带 buff 的敌人）
	if hc:
		var total = base_damage
		var ctx: Dictionary = {}
		hc.trigger("on_attack_start", total, ctx)
		var hit_value = hc.trigger("calc_attack_base", total, ctx)
		hit_value = hc.trigger("calc_attack_mult", hit_value, ctx)
		hit_value = hc.trigger("calc_attack_damage", hit_value, ctx)
		hit_value = hc.trigger("calc_attack_final", hit_value, ctx)
		hc.trigger("on_attack_hit", hit_value, {"hit_index": 0})
		if target is PlayerManager: target.take_damage(hit_value)
		elif target is EnemyUnit: target.take_damage(hit_value)
		hc.trigger("on_attack_end", 0, ctx)
		damage_dealt.emit(target, hit_value)
		return {"success": true, "value": hit_value, "target": target}
	
	# 简单伤害：无钩子链，直接造成伤害
	if target is PlayerManager:
		var actual = target.take_damage(base_damage)
		damage_dealt.emit(target, actual)
		return {"success": true, "value": actual, "target": target}
	elif target is EnemyUnit:
		var actual = target.take_damage(base_damage)
		damage_dealt.emit(target, actual)
		return {"success": true, "value": actual, "target": target}
	return {"success": false, "value": 0}

## 结算格挡效果（目标获得格挡值，受 block_mult 倍率影响）
func _resolve_block(base_block: int, source, target) -> Dictionary:
	var block_mult: float = 1.0
	if target is PlayerManager: block_mult = target.buff_manager.get_mult("block")
	elif target is EnemyUnit: block_mult = target.buff_manager.get_mult("block")
	var final_block = int(base_block * block_mult)
	if final_block <= 0: return {"success": false, "value": 0}
	if target is PlayerManager: target.gain_block(final_block); block_gained.emit(target, final_block)
	elif target is EnemyUnit: target.gain_block(final_block); block_gained.emit(target, final_block)
	return {"success": true, "value": final_block, "target": target}

## 结算治疗效果
func _resolve_heal(base_heal: int, source, target) -> Dictionary:
	var heal_mult: float = 1.0
	if target is PlayerManager: heal_mult = target.buff_manager.get_mult("heal")
	var final_heal = int(base_heal * heal_mult)
	if target is PlayerManager: var actual = target.heal(final_heal); healing_done.emit(target, actual); return {"success": true, "value": actual, "target": target}
	elif target is EnemyUnit: var actual = target.heal(final_heal); healing_done.emit(target, actual); return {"success": true, "value": actual, "target": target}
	return {"success": false, "value": 0}

## 永久攻击力提升（直接修改 base_strength）
func _resolve_damage_boost(value: int, source) -> Dictionary:
	if source is PlayerManager: source.base_strength += value; return {"success": true, "value": value}
	return {"success": false, "value": 0}

## 临时攻击力提升（通过 HookChain 实现，需要时可以清理）
func _resolve_temp_damage_boost(value: int, source) -> Dictionary:
	if source is PlayerManager:
		_temp_attack_boost += value
		var hook_id = "temp_atk_%d" % _temp_hook_ids.size()
		source.hook_chain.register("calc_attack_base", func(v, _c): return v + value, 5, hook_id)
		_temp_hook_ids.append(hook_id)
		return {"success": true, "value": value}
	return {"success": false, "value": 0}

## 跳过攻击：给玩家施加 skip_attack buff，持续到回合结束
func _resolve_skip_attack(_value: int, source) -> Dictionary:
	if source is PlayerManager and not source.buff_manager.has_buff("skip_attack"):
		var buff = BuffData.new({"id": "skip_attack", "name": "蓄势", "buff_type": "buff", "duration": 1, "stacks": 1, "trigger_timing": "on_turn_end_remove"})
		source.buff_manager.apply_buff(buff)
		return {"success": true, "value": 1}
	return {"success": false, "value": 0}

## 存储伤害：走前 3 步钩子管道计算 raw_damage，累加到 pending_stored_damage
## 用于"蓄力"机制：当前回合存储伤害，下回合额外释放
func _resolve_store_damage(source) -> Dictionary:
	if source is PlayerManager:
		var ctx: Dictionary = {}
		var v = source.base_strength
		v = source.hook_chain.trigger("calc_attack_base", v, ctx)
		v = int(source.hook_chain.trigger("calc_attack_mult", v, ctx))
		var add = source.hook_chain.trigger("calc_attack_damage", 0, ctx)
		var raw = v + add
		clear_temp_hooks(source)
		source.pending_stored_damage += raw
		return {"success": true, "value": raw, "stored_total": source.pending_stored_damage}
	return {"success": false, "value": 0}

## 无视格挡：施加 ignore_block buff，攻击时忽略目标的格挡值
func _resolve_ignore_block(source) -> Dictionary:
	if source is PlayerManager:
		var buff = BuffData.new({"id": "ignore_block", "name": "破甲", "buff_type": "buff", "duration": 1, "stacks": 1, "trigger_timing": "on_turn_end_remove"})
		source.buff_manager.apply_buff(buff)
		return {"success": true, "value": 1}
	return {"success": false, "value": 0}

## 反击架势：施加 counter_stance buff，格挡时对被格挡的伤害进行反击
func _resolve_counter_stance(source) -> Dictionary:
	if source is PlayerManager:
		var buff = BuffData.new({"id": "counter_stance", "name": "招架", "buff_type": "buff", "duration": 1, "stacks": 1, "trigger_timing": "on_turn_end_remove"})
		source.buff_manager.apply_buff(buff)
		return {"success": true, "value": 1}
	return {"success": false, "value": 0}

## 抽牌效果
func _resolve_draw(count: int, source) -> Dictionary:
	if card_system: var drawn = card_system.draw_cards(count); cards_drawn.emit(drawn.size()); return {"success": true, "value": drawn.size()}
	elif source.has_method("get") and source.get("card_system"): var cs = source.card_system; var drawn = cs.draw_cards(count); return {"success": true, "value": drawn.size()}
	return {"success": false, "value": 0}

## 从抽牌堆搜索并抽取指定 id 的卡牌
func _resolve_search_draw(effect: Dictionary, source) -> Dictionary:
	var cs = card_system
	if not cs and source.has_method("get") and source.get("card_system"): cs = source.card_system
	if cs: var card = cs.search_and_draw(effect.get("card_id", "")); return {"success": card != null, "value": 1} if card else {}
	return {"success": false, "value": 0}

## 从弃牌堆搜索并抽取指定 id 的卡牌到手牌
func _resolve_search_discard(effect: Dictionary, source) -> Dictionary:
	var cs = card_system
	if not cs and source.has_method("get") and source.get("card_system"): cs = source.card_system
	if cs: var card = cs.search_discard_and_draw(effect.get("card_id", "")); return {"success": card != null, "value": 1} if card else {}
	return {"success": false, "value": 0}

## 公开的施加 buff 接口
func apply_buff(effect: Dictionary, target) -> Dictionary:
	return _resolve_apply_buff(effect, target)

## 施加 buff/debuff 效果（通过 buff_id 查找预设配置创建 BuffData）
func _resolve_apply_buff(effect: Dictionary, target) -> Dictionary:
	var buff_id = effect.get("buff_id", effect.get("buff_type", ""))
	var stacks = effect.get("stacks", effect.get("value", 1))
	if buff_id.is_empty(): return {"success": false, "value": 0}
	var buff_data = _create_buff_from_id(buff_id, stacks)
	if buff_data == null: return {"success": false, "value": 0}
	if target is PlayerManager: target.apply_buff(buff_data); buff_applied.emit(target, buff_data)
	elif target is EnemyUnit: target.apply_buff(buff_data); buff_applied.emit(target, buff_data)
	return {"success": true, "value": stacks, "buff": buff_data}

## 将指定卡牌加入手牌
func _resolve_add_card(effect: Dictionary, source) -> Dictionary:
	var card = card_database.get_card(effect.get("card_id", ""))
	if card == null: return {"success": false, "value": 0}
	if source.has_method("get") and source.get("card_system"): source.card_system.add_to_hand(card.duplicate()); return {"success": true, "value": 1}
	return {"success": false, "value": 0}

## 按标签从抽牌堆搜索并抽取卡牌
func _resolve_search_draw_by_tag(effect: Dictionary, source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"):
		var card = source.card_system.search_and_draw_by_tag(effect.get("target_tag", ""))
		return {"success": card != null, "value": 1}
	return {"success": false, "value": 0}

## 按标签从弃牌堆搜索并抽取卡牌
func _resolve_search_discard_by_tag(effect: Dictionary, source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"):
		var card = source.card_system.search_discard_and_draw_by_tag(effect.get("target_tag", ""))
		return {"success": card != null, "value": 1}
	return {"success": false, "value": 0}

## 随机消耗手牌
func _resolve_exhaust_random(count: int, source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"):
		var cs = source.card_system; var exhausted = 0
		for i in count: if cs.exhaust_random_hand_card(): exhausted += 1
		return {"success": exhausted > 0, "value": exhausted}
	return {"success": false, "value": 0}

## 随机弃置手牌
func _resolve_discard_random(count: int, source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"):
		var cs = source.card_system; var discarded = 0
		for i in count: if cs.discard_random_hand_card(): discarded += 1
		return {"success": discarded > 0, "value": discarded}
	return {"success": false, "value": 0}

## 清理所有临时攻击力钩子
func clear_temp_hooks(source) -> void:
	if source and source.hook_chain:
		for hook_id in _temp_hook_ids: source.hook_chain.unregister("calc_attack_base", hook_id)
	_temp_hook_ids.clear()
	_temp_attack_boost = 0

func clear_all_temp_hooks(source) -> void:
	clear_temp_hooks(source)

## 将弃牌堆洗牌后移回抽牌堆
func _resolve_shuffle_discard_to_draw(source) -> Dictionary:
	if source.has_method("get") and source.get("card_system"): source.card_system.manual_shuffle_discard_to_draw(); return {"success": true, "value": 1}
	return {"success": false, "value": 0}

## 根据 buff_id 创建 BuffData 实例
## 这是 buff 配置的硬编码版本（也可从 JSON 加载）
func _create_buff_from_id(buff_id: String, stacks: int = 1) -> BuffData:
	var configs = {
		"strength": {"id": "strength", "name": "力量", "buff_type": "buff", "duration": -1, "stacks": stacks},
		"dexterity": {"id": "dexterity", "name": "敏捷", "buff_type": "buff", "duration": -1, "stacks": stacks},
		"weak": {"id": "weak", "name": "虚弱", "buff_type": "debuff", "duration": 2, "stacks": stacks, "modifiers": {"damage_mult": 0.75}},
		"vulnerable": {"id": "vulnerable", "name": "易伤", "buff_type": "debuff", "duration": 2, "stacks": stacks, "modifiers": {"damage_taken_mult": 1.5}},
		"poison": {"id": "poison", "name": "中毒", "buff_type": "debuff", "duration": -1, "stacks": stacks, "trigger_timing": "on_turn_end", "tick_effect": {"type": "damage", "value": 1}},
		"regen": {"id": "regen", "name": "再生", "buff_type": "buff", "duration": -1, "stacks": stacks, "trigger_timing": "on_turn_start", "tick_effect": {"type": "heal", "value": 1}},
	}
	if configs.has(buff_id): return BuffData.new(configs[buff_id].duplicate(true))
	return null

## ========== 默认处理器注册 ==========
## 将所有内置效果注册到 _handlers 字典。
## 新增效果时只需在此函数中添加一行 register_effect_handler() 调用，无需修改 resolve_effect()。
##
## 处理器函数签名分两种：
## 1. 旧版（2-3参数）：func(value, source[, target]) -> Dictionary  — 仅接收 value 和 source/target
## 2. 新版（3+参数）：func(effect: Dictionary, source, target) -> Dictionary — 接收完整 effect 字典
##    新版推荐，因为可以读取 effect 中的任何自定义字段（如 buff_id、card_id、target_tag 等）
func _register_default_handlers() -> void:
	## 所有处理器通过闭包统一签名为 func(effect: Dictionary, source, target) -> Dictionary
	## 闭包内部负责从 effect 中提取 value，并用正确的参数数量调用旧版处理函数

	# === 战斗效果（value, source, target） ===
	register_effect_handler("damage", func(e, s, t): return _resolve_damage(e.get("value", 0), s, t))
	register_effect_handler("block",  func(e, s, t): return _resolve_block(e.get("value", 0), s, t))
	register_effect_handler("heal",   func(e, s, t): return _resolve_heal(e.get("value", 0), s, t))

	# === 攻击力提升（value, source） ===
	register_effect_handler("damage_boost",      func(e, s, _t): return _resolve_damage_boost(e.get("value", 0), s))
	register_effect_handler("temp_damage_boost", func(e, s, _t): return _resolve_temp_damage_boost(e.get("value", 0), s))

	# === 机制效果（value, source）或（source） ===
	register_effect_handler("skip_attack",    func(e, s, _t): return _resolve_skip_attack(e.get("value", 0), s))
	register_effect_handler("store_damage",   func(_e, s, _t): return _resolve_store_damage(s))
	register_effect_handler("ignore_block",   func(_e, s, _t): return _resolve_ignore_block(s))
	register_effect_handler("counter_stance", func(_e, s, _t): return _resolve_counter_stance(s))

	# === 卡牌操作（value, source）或（source） ===
	register_effect_handler("draw",          func(e, s, _t): return _resolve_draw(e.get("value", 0), s))
	register_effect_handler("shuffle_discard_to_draw", func(_e, s, _t): return _resolve_shuffle_discard_to_draw(s))

	# === 搜索/检索（effect, source）—— 原生即接收 effect 字典 ===
	register_effect_handler("search_draw",           func(e, s, _t): return _resolve_search_draw(e, s))
	register_effect_handler("search_discard",        func(e, s, _t): return _resolve_search_discard(e, s))
	register_effect_handler("search_draw_by_tag",    func(e, s, _t): return _resolve_search_draw_by_tag(e, s))
	register_effect_handler("search_discard_by_tag", func(e, s, _t): return _resolve_search_discard_by_tag(e, s))

	# === Buff/Debuff（effect, target） ===
	register_effect_handler("apply_buff",   func(e, _s, t): return _resolve_apply_buff(e, t))
	register_effect_handler("apply_debuff", func(e, _s, t): return _resolve_apply_buff(e, t))

	# === 手牌操作（value, source）或（effect, source） ===
	register_effect_handler("exhaust_random",  func(e, s, _t): return _resolve_exhaust_random(e.get("value", 0), s))
	register_effect_handler("discard_random",  func(e, s, _t): return _resolve_discard_random(e.get("value", 0), s))
	register_effect_handler("add_card_to_hand", func(e, s, _t): return _resolve_add_card(e, s))

	## ========== 扩展指南 ==========
	## 在此处添加你的自定义效果处理器，示例：
	##
	##   # 复合效果：对全体敌人造成伤害
	##   register_effect_handler("aoe_damage", func(effect: Dictionary, source, _target) -> Dictionary:
	##       var total = 0
	##       for enemy in source.get("enemy_system", {}).get_alive_enemies() if source.has_method("get"):
	##           pass  # 需要从外部传入 enemy_system 引用
	##       return {"success": false, "value": 0}
	##   )
	##
	##   # 基于当前格挡值造成伤害的反击
	##   register_effect_handler("block_bash", func(effect: Dictionary, source, target) -> Dictionary:
	##       if not (source is PlayerManager and target is EnemyUnit):
	##           return {"success": false, "value": 0}
	##       var block_damage = source.block
	##       return resolve_effect({"effect_type": "damage", "value": block_damage}, source, target)
	##   )
