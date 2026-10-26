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
	INIT,          ## 初始化
	DRAW_PHASE,    ## 抽牌阶段（抽牌+恢复能量）
	TURN_PREPARE,  ## 回合准备（骰子显示?，等待按下"回合准备"）
	ENEMY_SELECT,  ## 敌人选牌阶段（投骰+AI决定出牌，玩家可见）
	PLAYER_SELECT, ## 玩家选牌阶段（玩家装载骰子）
	RESOLVING,     ## 结算中（速度排序依次执行）
	TURN_END,      ## 回合结束
	VICTORY,       ## 战斗胜利
	DEFEAT,        ## 战斗失败
	## 旧状态（向后兼容）
	PLAYER_TURN,   ## 玩家回合（旧模式）
	ENEMY_TURN,    ## 敌人回合（旧模式）
}

var current_state: BattleState = BattleState.INIT     ## 当前状态
var previous_state: BattleState = BattleState.INIT    ## 上一个状态
var _valid_transitions: Dictionary = {}  ## 合法转换表：{ 当前状态: [允许的后继状态列表] }

signal state_enter(state: BattleState)   ## 进入某状态

func _init():
	_setup_valid_transitions()

## 构建状态转换规则表
## 未列出的转换会被 change_state() 拒绝，防止状态机出现非法跳转
func _setup_valid_transitions() -> void:
	_valid_transitions = {
		BattleState.INIT: [BattleState.DRAW_PHASE],
		BattleState.DRAW_PHASE: [BattleState.TURN_PREPARE, BattleState.PLAYER_TURN, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.TURN_PREPARE: [BattleState.ENEMY_SELECT, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.ENEMY_SELECT: [BattleState.PLAYER_SELECT, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.PLAYER_SELECT: [BattleState.RESOLVING, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.RESOLVING: [BattleState.TURN_END, BattleState.PLAYER_TURN, BattleState.ENEMY_TURN, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.TURN_END: [BattleState.DRAW_PHASE, BattleState.VICTORY, BattleState.DEFEAT],
		## 旧模式兼容
		BattleState.PLAYER_TURN: [BattleState.RESOLVING, BattleState.ENEMY_TURN, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.ENEMY_TURN: [BattleState.TURN_END, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.VICTORY: [],
		BattleState.DEFEAT: []
	}

## 尝试切换到新状态，非法转换会被拒绝
func change_state(new_state: BattleState) -> bool:
	if not is_transition_valid(new_state):
		push_error("StateMachine: Invalid transition from %s to %s" % [get_state_name(current_state), get_state_name(new_state)])
		return false
	
	previous_state = current_state
	current_state = new_state
	state_enter.emit(current_state)
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
		BattleState.TURN_PREPARE: return "TURN_PREPARE"
		BattleState.ENEMY_SELECT: return "ENEMY_SELECT"
		BattleState.PLAYER_SELECT: return "PLAYER_SELECT"
		BattleState.RESOLVING: return "RESOLVING"
		BattleState.TURN_END: return "TURN_END"
		BattleState.VICTORY: return "VICTORY"
		BattleState.DEFEAT: return "DEFEAT"
		BattleState.PLAYER_TURN: return "PLAYER_TURN"
		BattleState.ENEMY_TURN: return "ENEMY_TURN"
		_: return "UNKNOWN"

func is_player_turn() -> bool:
	return current_state == BattleState.PLAYER_TURN or current_state == BattleState.PLAYER_SELECT


func is_player_select() -> bool:
	return current_state == BattleState.PLAYER_SELECT

func is_turn_prepare() -> bool:
	return current_state == BattleState.TURN_PREPARE


func is_resolving() -> bool:
	return current_state == BattleState.RESOLVING

## 战斗是否仍在进行中（非胜利/失败终态）
func is_battle_active() -> bool:
	return current_state not in [BattleState.VICTORY, BattleState.DEFEAT]
