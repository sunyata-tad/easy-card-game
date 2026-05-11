class_name TurnManager

var turn_count: int = 0
var is_player_active: bool = true

signal turn_started(turn_number: int, is_player_turn: bool)
signal turn_ended(turn_number: int)
signal player_turn_start()
signal player_turn_end()
signal enemy_turn_start()
signal enemy_turn_end()

func reset() -> void:
	turn_count = 0
	is_player_active = true

func start_new_turn(is_player: bool = true) -> void:
	if is_player:
		turn_count += 1
	is_player_active = is_player
	turn_started.emit(turn_count, is_player)
	
	if is_player:
		player_turn_start.emit()
	else:
		enemy_turn_start.emit()

func end_current_turn() -> void:
	turn_ended.emit(turn_count)
	
	if is_player_active:
		player_turn_end.emit()
	else:
		enemy_turn_end.emit()

func get_turn_count() -> int:
	return turn_count

func is_player_turn() -> bool:
	return is_player_active
