## 战斗规则参数集（Layer 1 基础规则层）
## ----------------------------------------------------------------------------
## 集中所有可配置的战斗参数，替代此前散落在 BattleController / CardSystem /
## PlayerManager 中的硬编码值。默认值 = 原硬编码值，行为完全不变。
##
## 未来扩展：
## - 从 JSON 加载战斗特殊规则覆盖默认值：rules.from_json("res://data/battles/xxx.json")
## - 钩子链可修改这些参数：在关键决策点 trigger("modify_xxx", value, {})
## - 玩家规则修改：修改 BattleRules 的字段值即可实时生效
class_name BattleRules
extends RefCounted

## 战斗开始时抽牌数
var initial_draw_count: int = 5
## 每回合抽牌数
var turn_draw_count: int = 1
## 手牌上限
var max_hand_size: int = 10
## 初始血量
var initial_max_hp: int = 80
## 弃牌攻击每回合次数
var discard_attack_per_turn: int = 1
## 回合结束是否弃牌到手牌上限
var discard_to_max_at_end: bool = true

## 从 JSON 加载规则覆盖默认值
## JSON 格式：{"initial_draw_count": 3, "max_hand_size": 8, ...}
func from_json(path: String) -> BattleRules:
	if not FileAccess.file_exists(path):
		return self
	var text = FileAccess.get_file_as_string(path)
	var json = JSON.new()
	if json.parse(text) != OK:
		push_warning("BattleRules: 无法解析 %s" % path)
		return self
	var data = json.data
	if data is Dictionary:
		for key in data:
			if self.get(key) != null:
				self.set(key, data[key])
	return self

## 查询规则值（未来可在此接入钩子链做动态修改）
func query(rule_name: String) -> Variant:
	return self.get(rule_name)