## 战斗状态机：管理战斗中所有状态的合法转换，确保状态流转符合规则。
## Godot 特色：
## - enum 定义枚举类型（类似 Python 的 IntEnum / Java 的 enum）
## - BattleState.XXX 引用枚举值，等价于整数常量
## - push_error() 向 Godot 调试输出打印错误信息
## - %s 格式化字符串（类似 Python 的 %-format）
## - x in array 判断元素是否在数组中
class_name StateMachine

## 战斗状态枚举
enum BattleState {
	INIT,         ## 初始化
	DRAW_PHASE,   ## 抽牌阶段
	PLAYER_TURN,  ## 玩家回合
	RESOLVING,    ## 结算中（卡牌效果正在处理）
	ENEMY_TURN,   ## 敌人回合
	TURN_END,     ## 回合结束
	VICTORY,      ## 战斗胜利
	DEFEAT        ## 战斗失败
}

var current_state: BattleState = BattleState.INIT     ## 当前状态
var previous_state: BattleState = BattleState.INIT    ## 上一个状态
var _valid_transitions: Dictionary = {}  ## 合法转换表：{ 当前状态: [允许的后继状态列表] }

signal state_changed(new_state: BattleState, old_state: BattleState)  ## 状态发生变化
signal state_enter(state: BattleState)   ## 进入某状态
signal state_exit(state: BattleState)    ## 退出某状态

func _init():
	_setup_valid_transitions()

## 构建状态转换规则表
## 未列出的转换会被 change_state() 拒绝，防止状态机出现非法跳转
func _setup_valid_transitions() -> void:
	_valid_transitions = {
		BattleState.INIT: [BattleState.DRAW_PHASE],
		BattleState.DRAW_PHASE: [BattleState.PLAYER_TURN, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.PLAYER_TURN: [BattleState.RESOLVING, BattleState.ENEMY_TURN, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.RESOLVING: [BattleState.PLAYER_TURN, BattleState.ENEMY_TURN, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.ENEMY_TURN: [BattleState.TURN_END, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.TURN_END: [BattleState.DRAW_PHASE, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.VICTORY: [],  ## 终态，不允许再转换
		BattleState.DEFEAT: []    ## 终态，不允许再转换
	}

## 尝试切换到新状态，非法转换会被拒绝
func change_state(new_state: BattleState) -> bool:
	if not is_transition_valid(new_state):
		push_error("StateMachine: Invalid transition from %s to %s" % [get_state_name(current_state), get_state_name(new_state)])
		return false
	
	previous_state = current_state
	state_exit.emit(current_state)
	current_state = new_state
	state_enter.emit(current_state)
	state_changed.emit(current_state, previous_state)
	return true

## 检查从当前状态到目标状态的转换是否合法
func is_transition_valid(new_state: BattleState) -> bool:
	if not _valid_transitions.has(current_state):
		return false
	return new_state in _valid_transitions[current_state]

## 获取状态枚举对应的字符串名（用于日志输出）
func get_state_name(state: BattleState) -> String:
	match state:
		BattleState.INIT: return "INIT"
		BattleState.DRAW_PHASE: return "DRAW_PHASE"
		BattleState.PLAYER_TURN: return "PLAYER_TURN"
		BattleState.RESOLVING: return "RESOLVING"
		BattleState.ENEMY_TURN: return "ENEMY_TURN"
		BattleState.TURN_END: return "TURN_END"
		BattleState.VICTORY: return "VICTORY"
		BattleState.DEFEAT: return "DEFEAT"
		_: return "UNKNOWN"  ## 通配符（match 中类似 default）

func is_player_turn() -> bool:
	return current_state == BattleState.PLAYER_TURN

func is_enemy_turn() -> bool:
	return current_state == BattleState.ENEMY_TURN

func is_resolving() -> bool:
	return current_state == BattleState.RESOLVING

## 战斗是否仍在进行中（非胜利/失败终态）
func is_battle_active() -> bool:
	return current_state not in [BattleState.VICTORY, BattleState.DEFEAT]
