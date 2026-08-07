## ============================================================================
## 钩子注册表（HookRegistry）
## ----------------------------------------------------------------------------
## 全项目唯一的钩子名称定义 + 文档来源（Single Source of Truth）。
## 目标：让效果的"调用"与"实现"清晰可查。复用旧效果时遵循标准流程：
##
##       调用钩子（trigger / register） → 实现效果（回调内写逻辑）
##
## 为什么需要它：
##   - 此前钩子名是散落在各文件的魔法字符串，拼错只在运行时静默失败
##   - 现在所有钩子名统一定义为常量，编辑器可补全、可跳转、可查错
##   - _HOOK_DOCS 提供"钩子列表（名字 + 注释）"，供查阅与调试
##
## 使用方式：
##   - 触发钩子：  unit.hook_chain.trigger(HookRegistry.HOOK_CALC_BASE, v, ctx)
##   - 注册回调：  unit.hook_chain.register(HookRegistry.HOOK_CALC_ADD, 回调, priority, id)
##   - 查阅列表：  HookRegistry.get_hook_docs()  /  HookRegistry.get_hook_desc("...")
##
## 新增一个钩子（或复用已有钩子实现新效果）的标准流程：
##   1. 先查 get_hook_docs() 确认钩子是否已存在（能复用就不新建）
##   2. 若不存在：在此定义常量 + 在 _HOOK_DOCS 补一条 {name, stage, value, desc, ctx}
##   3. 在效果实现处 register 回调（生效时机由 priority 决定，数值越小越先执行）
##   4. 在流程控制处 trigger 触发（值由前一个回调的返回值传入下一个）
##
## 完整调用规范文档：项目根目录 EFFECT_HOOKS.md
## ============================================================================
class_name HookRegistry

## ==================== 攻击链钩子（攻击发起方流程） ====================
## 攻击开始时触发。value=0；回调可写 ctx 标记以改变本次攻击行为
const HOOK_ON_ATTACK_START: String = "on_attack_start"
## 基础攻击力计算阶段。value=基础攻击力，回调返回修正后的攻击力
## （temp_damage_boost 临时力量钩子注入点）
const HOOK_CALC_BASE: String = "calc_attack_base"
## 攻击力倍率阶段。value=当前攻击力，回调返回 × 倍率后的值
const HOOK_CALC_MULT: String = "calc_attack_mult"
## 攻击力加算阶段。value=0（额外伤害从此累加），蓄力 _pending_stored 钩子注入点
const HOOK_CALC_ADD: String = "calc_attack_damage"
## 最终伤害倍率阶段。value=合并后的原始伤害，回调返回最终伤害（weak ×0.75 注入点）
const HOOK_CALC_FINAL: String = "calc_attack_final"
## 攻击命中时触发。value=最终伤害，回调可写 ctx（如 counter_damage 反击值）
const HOOK_ON_ATTACK_HIT: String = "on_attack_hit"
## 攻击结束时触发。value=0，用于收尾/清理
const HOOK_ON_ATTACK_END: String = "on_attack_end"

## ==================== 受击链钩子（防守方流程） ====================
## 格挡值计算阶段。value=基础格挡，回调返回修正后的格挡（dexterity 敏捷钩子注入点）
const HOOK_CALC_BLOCK: String = "calc_attack_block"
## 受到伤害时触发。value=伤害值，回调返回修正后的伤害（vulnerable 易伤 ×1.5 注入点）
const HOOK_ON_DAMAGE_TAKEN: String = "on_damage_taken"
## 死亡前触发。value=致死伤害，回调写 ctx["can_die"]=false 可阻止死亡（保 1 血）
const HOOK_ON_BEFORE_DEATH: String = "before_death"

## ==================== 规则门钩子（全局判定流程） ====================
## 弃牌规则门。value=需弃牌数；回调写 ctx["block_discard"]=true 阻止弃牌（no_discard 注入点）
const HOOK_CHECK_DISCARD: String = "check_discard"
## 战斗结束判定。value=0；回调可改写 ctx（should_end / result / reason）
const HOOK_CHECK_BATTLE_END: String = "check_battle_end"

## ==================== 钩子文档列表（名字 + 注释） ====================
## 每条字段：name(钩子名) / stage(所属阶段) / value(传入值) / desc(注释) / ctx(可写上下文标记)
static var _HOOK_DOCS: Array = [
	{"name": HOOK_ON_ATTACK_START, "stage": "攻击链", "value": "0",
	 "desc": "攻击开始。可写 ctx 标记改变本次攻击（skip_attack 跳过攻击 / ignore_block 无视格挡）",
	 "ctx": "skip_attack, ignore_block"},
	{"name": HOOK_CALC_BASE, "stage": "攻击链", "value": "基础攻击力",
	 "desc": "基础攻击力计算，返回修正后的攻击力（临时力量钩子注入点）",
	 "ctx": "-"},
	{"name": HOOK_CALC_MULT, "stage": "攻击链", "value": "当前攻击力",
	 "desc": "攻击力倍率，返回 × 倍率后的值",
	 "ctx": "-"},
	{"name": HOOK_CALC_ADD, "stage": "攻击链", "value": "0",
	 "desc": "攻击力加算，额外伤害从此累加（蓄力钩子注入点）",
	 "ctx": "-"},
	{"name": HOOK_CALC_FINAL, "stage": "攻击链", "value": "原始伤害",
	 "desc": "最终伤害倍率，返回最终伤害（虚弱 ×0.75 注入点）",
	 "ctx": "-"},
	{"name": HOOK_ON_ATTACK_HIT, "stage": "攻击链", "value": "最终伤害",
	 "desc": "攻击命中，可写 ctx 记录反击等（反击架势注入点）",
	 "ctx": "counter_damage"},
	{"name": HOOK_ON_ATTACK_END, "stage": "攻击链", "value": "0",
	 "desc": "攻击结束，用于收尾/清理",
	 "ctx": "-"},
	{"name": HOOK_CALC_BLOCK, "stage": "受击链", "value": "基础格挡",
	 "desc": "格挡值计算，返回修正后的格挡（敏捷钩子注入点）",
	 "ctx": "-"},
	{"name": HOOK_ON_DAMAGE_TAKEN, "stage": "受击链", "value": "伤害值",
	 "desc": "受到伤害，返回修正后的伤害（易伤 ×1.5 注入点）",
	 "ctx": "source_type"},
	{"name": HOOK_ON_BEFORE_DEATH, "stage": "受击链", "value": "致死伤害",
	 "desc": "死亡前判定，写 ctx.can_die=false 可阻止死亡",
	 "ctx": "can_die"},
	{"name": HOOK_CHECK_DISCARD, "stage": "规则门", "value": "需弃牌数",
	 "desc": "弃牌规则门，写 ctx.block_discard=true 阻止弃牌（不弃注入点）",
	 "ctx": "block_discard"},
	{"name": HOOK_CHECK_BATTLE_END, "stage": "规则门", "value": "0",
	 "desc": "战斗结束判定，可改写结束条件与结果",
	 "ctx": "should_end, result, reason"},
]

## 获取钩子文档列表的深拷贝（含全部钩子名与注释）
static func get_hook_docs() -> Array:
	return _HOOK_DOCS.duplicate(true)

## 获取所有钩子名（仅名称数组）
static func get_hook_names() -> Array:
	var names: Array = []
	for doc in _HOOK_DOCS:
		names.append(doc.name)
	return names

## 判断钩子名是否为已注册/已文档化的钩子（用于 HookChain 调用前校验）
static func is_known_hook(hook_name: String) -> bool:
	for doc in _HOOK_DOCS:
		if doc.name == hook_name:
			return true
	return false

## 按名字获取钩子注释，未找到返回空字符串
static func get_hook_desc(hook_name: String) -> String:
	for doc in _HOOK_DOCS:
		if doc.name == hook_name:
			return doc.desc
	return ""
