## 钩子链系统，用于在攻击/伤害计算流程中插入可叠加的修改逻辑。
## 工作原理类似"责任链模式"：多个回调按优先级排序后依次执行，每个回调接收上一个的返回值作为输入。
## Godot 特色：
## - class_name 使脚本成为全局可用的类型（类似 Python 中定义一个类）
## - Callable 是可调用对象（类似 Python 的 callable / Java 的 FunctionalInterface）
## - Variant 是 Godot 的万能类型，可以容纳任何值（类似 Python 的 Any）
class_name HookChain

## 存储所有注册的钩子，结构：{ "hook_name": [ {callback, priority, id}, ... ] }
var _hooks: Dictionary = {}

## 注册一个钩子回调
## @param hook_name: 钩子名称（对应攻击计算的不同阶段，如 "calc_attack_base"）
## @param callback: 回调函数，签名为 func(current_value: Variant, context: Dictionary) -> Variant
## @param priority: 优先级，数值越小越先执行（类似 Python 的 sorted(key=lambda)）
## @param id: 唯一标识，用于后续取消注册
func register(hook_name: String, callback: Callable, priority: int = 0, id: String = "") -> void:
	if not _hooks.has(hook_name):
		_hooks[hook_name] = []
	_hooks[hook_name].append({
		"callback": callback,
		"priority": priority,
		"id": id
	})
	# 每次注册后重新排序，确保执行顺序正确
	_hooks[hook_name].sort_custom(func(a, b): return a.priority < b.priority)

## 取消注册指定 id 的钩子（遍历整个钩子列表，过滤掉匹配的 id）
func unregister(hook_name: String, id: String) -> void:
	if not _hooks.has(hook_name):
		return
	# filter 返回新数组，保留 id 不匹配的钩子
	_hooks[hook_name] = _hooks[hook_name].filter(func(h): return h.id != id)

## 触发钩子链：按优先级依次执行所有注册的回调，每个回调的返回值作为下一个的输入
## @param value: 初始值（如基础攻击力）
## @param context: 可变的上下文字典，回调可以在其中读写额外数据（如标记"忽略格挡"）
## @return: 经过所有钩子处理后的最终值
func trigger(hook_name: String, value: Variant = null, context: Dictionary = {}) -> Variant:
	if not _hooks.has(hook_name):
		return value
	var current_value = value
	# 按 priority 从小到大的顺序依次调用
	for hook in _hooks[hook_name]:
		# .call() 是 Callable 类型的方法，传入参数并返回结果
		current_value = hook.callback.call(current_value, context)
	return current_value

## 检查指定钩子是否有注册的回调
func has_hooks(hook_name: String) -> bool:
	return _hooks.has(hook_name) and _hooks[hook_name].size() > 0

## 清空所有钩子
func clear() -> void:
	_hooks.clear()

## 清空指定名称的所有钩子
func clear_hook(hook_name: String) -> void:
	_hooks.erase(hook_name)
