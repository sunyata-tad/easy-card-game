class_name StateMachine

enum BattleState {
	INIT,
	DRAW_PHASE,
	PLAYER_TURN,
	RESOLVING,
	ENEMY_TURN,
	TURN_END,
	VICTORY,
	DEFEAT
}

var current_state: BattleState = BattleState.INIT
var previous_state: BattleState = BattleState.INIT
var _valid_transitions: Dictionary = {}

signal state_changed(new_state: BattleState, old_state: BattleState)
signal state_enter(state: BattleState)
signal state_exit(state: BattleState)

func _init():
	_setup_valid_transitions()

func _setup_valid_transitions() -> void:
	_valid_transitions = {
		BattleState.INIT: [BattleState.DRAW_PHASE],
		BattleState.DRAW_PHASE: [BattleState.PLAYER_TURN, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.PLAYER_TURN: [BattleState.RESOLVING, BattleState.ENEMY_TURN, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.RESOLVING: [BattleState.PLAYER_TURN, BattleState.ENEMY_TURN, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.ENEMY_TURN: [BattleState.TURN_END, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.TURN_END: [BattleState.DRAW_PHASE, BattleState.VICTORY, BattleState.DEFEAT],
		BattleState.VICTORY: [],
		BattleState.DEFEAT: []
	}

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

func is_transition_valid(new_state: BattleState) -> bool:
	if not _valid_transitions.has(current_state):
		return false
	return new_state in _valid_transitions[current_state]

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
		_: return "UNKNOWN"

func is_player_turn() -> bool:
	return current_state == BattleState.PLAYER_TURN

func is_enemy_turn() -> bool:
	return current_state == BattleState.ENEMY_TURN

func is_resolving() -> bool:
	return current_state == BattleState.RESOLVING

func is_battle_active() -> bool:
	return current_state not in [BattleState.VICTORY, BattleState.DEFEAT]
