## 敌人系统：管理场上所有敌人单位的增删查，以及全体敌人的死亡/战败检测。
## Godot 特色：
## - .bind(enemy) 将额外参数绑定到信号回调中（类似 Python 的 partial / Java 的 Currying）
##   写法：signal_source.signal_name.connect(callback.bind(extra_arg))
class_name EnemySystem

## 场上所有敌人（包括已死亡的）
var enemies: Array = []

signal enemy_added(enemy: EnemyUnit)         ## 敌人被添加到场上
signal enemy_removed(enemy: EnemyUnit)       ## 敌人从场上移除
signal enemy_damaged(enemy: EnemyUnit, amount: int)  ## 敌人受到伤害
signal enemy_died(enemy: EnemyUnit)          ## 敌人死亡
signal enemies_changed()                    ## 敌人列表发生变化
signal all_enemies_defeated()               ## 所有敌人都被击败

func _init():
	pass

## 创建一个 EnemyUnit 并加入敌方列表
func add_enemy(enemy_data: EnemyData) -> EnemyUnit:
	var enemy = EnemyUnit.new(enemy_data)
	enemies.append(enemy)
	_connect_enemy_signals(enemy)
	enemy_added.emit(enemy)
	enemies_changed.emit()
	return enemy

## 连接单个敌人单位的信号到系统层
## .bind(enemy) 使得回调函数能额外接收到 enemy 参数
func _connect_enemy_signals(enemy: EnemyUnit) -> void:
	enemy.enemy_died.connect(_on_enemy_died.bind(enemy))
	enemy.enemy_damaged.connect(_on_enemy_damaged.bind(enemy))

## 移除指定敌人
func remove_enemy(enemy: EnemyUnit) -> void:
	if enemies.has(enemy):
		enemies.erase(enemy)
		enemy_removed.emit(enemy)
		enemies_changed.emit()
		_check_all_defeated()

## 获取所有敌人的副本
func get_all_enemies() -> Array:
	return enemies.duplicate()

## 获取所有存活的敌人
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

## 判断是否所有敌人都已被击败
func is_all_defeated() -> bool:
	return get_alive_count() == 0

func _on_enemy_died(enemy: EnemyUnit) -> void:
	enemy_died.emit(enemy)
	_check_all_defeated()

func _on_enemy_damaged(amount: int, enemy: EnemyUnit) -> void:
	enemy_damaged.emit(enemy, amount)

## 检查是否全部击败，如果是则发出信号
func _check_all_defeated() -> void:
	if is_all_defeated():
		all_enemies_defeated.emit()

## 清除所有敌人
func clear_all() -> void:
	enemies.clear()
	enemies_changed.emit()

## 重置所有敌人的格挡值
func reset_all_block() -> void:
	for enemy in enemies:
		enemy.reset_block()
