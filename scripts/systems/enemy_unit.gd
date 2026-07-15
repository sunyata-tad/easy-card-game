## 敌方单位：代表战场上单个敌人的完整状态（血量、格挡、buff、意图等）。
## 每个 EnemyUnit 由 EnemyData 创建，拥有独立的 HookChain 和 BuffManager。
## Godot 特色：
## - EnemyUnit.new(enemy_data) 创建一个新实例并自动调用 _init(enemy_data) 构造函数
## - Dictionary 是键值对容器（类似 Python 的 dict / Java 的 Map）
class_name EnemyUnit

var data: EnemyData              ## 敌人配置数据（来自 JSON 的静态属性）
var current_hp: int              ## 当前血量
var max_hp: int                  ## 最大血量
var block: int = 0               ## 当前格挡值
var buff_manager: BuffManager    ## buff 管理器
var hook_chain: HookChain        ## 钩子链（处理伤害计算修正）
var is_dead: bool = false        ## 是否已死亡
var current_intent: Dictionary = {}  ## 当前意图，如 {"type": "attack", "damage": 10}

signal hp_changed(current: int, maximum: int)    ## 血量变化
signal block_changed(amount: int)                ## 格挡值变化
signal enemy_died()                              ## 敌人死亡
signal enemy_damaged(amount: int)                ## 敌人受到伤害（发出实际伤害值）
signal intent_changed(intent: Dictionary)        ## 意图变化

## 构造函数：从 EnemyData 创建敌人，初始化血量、HookChain、BuffManager
func _init(enemy_data: EnemyData):
	data = enemy_data
	max_hp = enemy_data.max_hp
	current_hp = max_hp
	# 每个敌人独立拥有钩子链和 buff 管理器
	hook_chain = HookChain.new()
	buff_manager = BuffManager.new(hook_chain)

## 受到伤害，返回实际造成的伤害值
## @param ignore_target_block: true 时无视格挡直接扣血
func take_damage(amount: int, ignore_target_block: bool = false) -> int:
	if amount <= 0 or is_dead:
		return 0
	
	# 先经过钩子链处理（如易伤 buff 会增加伤害）
	var actual_damage = int(hook_chain.trigger("on_damage_taken", amount, {}))
	
	# 格挡抵消伤害（除非被标记为无视格挡）
	if not ignore_target_block and block > 0:
		if block >= actual_damage:
			block -= actual_damage
			block_changed.emit(block)
			return 0
		else:
			actual_damage -= block
			block = 0
			block_changed.emit(block)
	
	# 扣除血量，不低于 0
	current_hp = maxi(current_hp - actual_damage, 0)
	hp_changed.emit(current_hp, max_hp)
	enemy_damaged.emit(actual_damage)
	
	if current_hp <= 0:
		is_dead = true
		clear_intent()
		enemy_died.emit()
	
	return actual_damage

## 获得格挡值
func gain_block(amount: int) -> void:
	if amount <= 0:
		return
	block += amount
	block_changed.emit(block)

## 回复血量，返回实际回复值
func heal(amount: int) -> int:
	if amount <= 0:
		return 0
	var old_hp = current_hp
	current_hp = mini(current_hp + amount, max_hp)
	var healed = current_hp - old_hp
	if healed > 0:
		hp_changed.emit(current_hp, max_hp)
	return healed

## 重置格挡值为 0
func reset_block() -> void:
	block = 0
	block_changed.emit(block)

## 设置敌人意图（决定下回合的行动）
func set_intent(intent: Dictionary) -> void:
	current_intent = intent
	intent_changed.emit(intent)

## 清除意图
func clear_intent() -> void:
	current_intent = {}
	intent_changed.emit({})

## 随机选择下一个意图（从 EnemyData.actions 中随机抽取）
func decide_next_intent() -> void:
	if data.actions.is_empty():
		clear_intent()
		return
	
	var action = data.actions.pick_random()
	set_intent(action)

func is_alive() -> bool:
	return not is_dead and current_hp > 0

func get_name() -> String:
	return data.name

## 给敌人施加 buff
func apply_buff(buff: BuffData) -> void:
	buff_manager.apply_buff(buff)
