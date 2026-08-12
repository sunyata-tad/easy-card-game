## 遗物管理器：持有玩家遗物，负责把"规则改变"绑定到战斗钩子 / 流程上。
## 遗物规则的挂载方式：
##  - 需要战斗上下文（敌人/状态机）的规则：通过注入 battle_controller 引用，注册到
##    玩家 HookChain 或由 BattleController 在对应流程中调用。
##  - 通用"觉醒型"遗物模式：第一次触发条件 → 锁血/存活 → 进入觉醒态（启用后续规则）。
class_name RelicManager
extends RefCounted

var player: PlayerManager        ## 所属玩家单位
var battle_controller = null     ## 战斗上下文（setup 时注入，供需要敌方/状态的规则使用）
var relics: Array = []           ## RelicData 列表
var _awakened: Array = []        ## 已觉醒的遗物 id
var _hooks_registered: bool = false

func _init(p: PlayerManager):
	player = p

func add_relic(relic: RelicData) -> void:
	# 不可重复遗物：已拥有则忽略（防重复获取 bug）；可重复遗物允许重复加入（占位遗物）
	if not relic.repeatable and has_relic(relic.id):
		return
	relics.append(relic)
	_register_hooks()

func has_relic(id: String) -> bool:
	for r in relics:
		if r.id == id:
			return true
	return false

func is_awakened(id: String) -> bool:
	return _awakened.has(id)

## 觉醒遗物：标记进入觉醒态（启用觉醒后规则）
func awaken(id: String) -> void:
	if not _awakened.has(id):
		_awakened.append(id)

## 一次性注册遗物钩子（挂在玩家 HookChain 上）
func _register_hooks() -> void:
	if _hooks_registered or player.hook_chain == null:
		return
	_hooks_registered = true
	# 死亡判定前：处理"第一次归0锁血 + 觉醒后不死/允许负数"
	player.hook_chain.register(HookRegistry.HOOK_ON_BEFORE_DEATH,
		_on_before_death, 10, "relic_before_death")
	# 受击：觉醒后"自己回合内"受到的伤害转移给全体敌方（每个敌人各承担完整伤害）
	player.hook_chain.register(HookRegistry.HOOK_ON_DAMAGE_TAKEN,
		_on_damage_taken_redirect, 30, "relic_damage_redirect")

## 死亡判定前钩子：处理"终末轮回"遗物（条件式逻辑，与文本严格一致）
## 条件式：当 X 时，触发 Y
##  ① 常驻：当生命值归零（≤0，即原死亡条件）时，不因此死亡（游戏底层机制：生命可为负数）
##  ② 触发一次：当第一次生命归零（≤0）时触发：失败条件改为卡组为空时抽卡；
##     每回合开始抽卡直到手卡≥10；自己回合受到的伤害由全体敌人承担
##  ③ 在触发过②的战斗中：生命值可维持为负数；战斗结束时生命设为上限的50%
func _on_before_death(v, ctx):
	if not has_relic("immortal_cycle"):
		return v
	if is_awakened("immortal_cycle"):
		# 效果③：已触发过② → 不因生命死亡，允许维持负数
		ctx["can_die"] = false
		ctx["allow_negative"] = true
	else:
		# 效果①+②：原死亡条件（生命归零，≤0）→ 不死亡，并触发效果②（设置新死亡条件）
		ctx["can_die"] = false
		ctx["allow_negative"] = true
		awaken("immortal_cycle")
	return v

## 受击钩子：效果②生效后，"自己回合内"受到的伤害 → 全体敌方各承担完整伤害
func _on_damage_taken_redirect(v, ctx):
	if not has_relic("immortal_cycle") or not is_awakened("immortal_cycle"):
		return v
	if battle_controller == null:
		return v
	var sm = battle_controller.state_machine
	if sm == null or not (sm.is_player_turn() or sm.is_resolving()):
		return v
	var alive = battle_controller.enemy_system.get_alive_enemies()
	if alive.is_empty():
		return v
	for e in alive:
		e.take_damage(v)
	# 玩家本体不再承受该伤害
	return 0
