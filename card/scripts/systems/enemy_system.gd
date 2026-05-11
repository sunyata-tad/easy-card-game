class_name EnemySystem

var enemies: Array = []

signal enemy_added(enemy: EnemyUnit)
signal enemy_removed(enemy: EnemyUnit)
signal enemy_damaged(enemy: EnemyUnit, amount: int)
signal enemy_died(enemy: EnemyUnit)
signal enemies_changed()
signal all_enemies_defeated()

func _init():
	pass

func add_enemy(enemy_data: EnemyData) -> EnemyUnit:
	var enemy = EnemyUnit.new(enemy_data)
	enemies.append(enemy)
	_connect_enemy_signals(enemy)
	enemy_added.emit(enemy)
	enemies_changed.emit()
	return enemy

func _connect_enemy_signals(enemy: EnemyUnit) -> void:
	enemy.enemy_died.connect(_on_enemy_died.bind(enemy))
	enemy.enemy_damaged.connect(_on_enemy_damaged.bind(enemy))

func remove_enemy(enemy: EnemyUnit) -> void:
	if enemies.has(enemy):
		enemies.erase(enemy)
		enemy_removed.emit(enemy)
		enemies_changed.emit()
		_check_all_defeated()

func get_all_enemies() -> Array:
	return enemies.duplicate()

func get_alive_enemies() -> Array:
	var alive: Array = []
	for enemy in enemies:
		if enemy.is_alive():
			alive.append(enemy)
	return alive

func get_enemy_count() -> int:
	return enemies.size()

func get_alive_count() -> int:
	return get_alive_enemies().size()

func is_all_defeated() -> bool:
	return get_alive_count() == 0

func _on_enemy_died(enemy: EnemyUnit) -> void:
	enemy_died.emit(enemy)
	_check_all_defeated()

func _on_enemy_damaged(amount: int, enemy: EnemyUnit) -> void:
	enemy_damaged.emit(enemy, amount)

func _check_all_defeated() -> void:
	if is_all_defeated():
		all_enemies_defeated.emit()

func clear_all() -> void:
	enemies.clear()
	enemies_changed.emit()

func reset_all_block() -> void:
	for enemy in enemies:
		enemy.reset_block()
