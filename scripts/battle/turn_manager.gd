## 回合管理器：跟踪当前回合数和当前行动方（玩家/敌人），管理回合的开始与结束。
## 设计说明：只有玩家回合开始时回合计数才 +1（一对玩家+敌人回合只算 1 个完整回合）。
class_name TurnManager

var turn_count: int = 0        ## 当前回合数（只在玩家回合开始时递增）
var is_player_active: bool = true  ## 当前是否为玩家行动

signal turn_started(turn_number: int, is_player_turn: bool)  ## 新回合开始
signal turn_ended(turn_number: int)                          ## 当前阶段结束
signal player_turn_start()   ## 玩家回合开始
signal player_turn_end()     ## 玩家回合结束
signal enemy_turn_start()    ## 敌人回合开始
signal enemy_turn_end()      ## 敌人回合结束

## 重置回合数和状态
func reset() -> void:
	turn_count = 0
	is_player_active = true

## 开始新的行动阶段
## 只有玩家回合开始时回合数 +1（避免玩家+敌人都计数导致翻倍）
func start_new_turn(is_player: bool = true) -> void:
	if is_player:
		turn_count += 1
	is_player_active = is_player
	turn_started.emit(turn_count, is_player)
	
	if is_player:
		player_turn_start.emit()
	else:
		enemy_turn_start.emit()

## 结束当前行动阶段
func end_current_turn() -> void:
	turn_ended.emit(turn_count)
	
	if is_player_active:
		player_turn_end.emit()
	else:
		enemy_turn_end.emit()
