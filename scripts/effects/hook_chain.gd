class_name HookChain

var _hooks: Dictionary = {}

func register(hook_name: String, callback: Callable, priority: int = 0, id: String = "") -> void:
	if not _hooks.has(hook_name):
		_hooks[hook_name] = []
	_hooks[hook_name].append({
		"callback": callback,
		"priority": priority,
		"id": id
	})
	_hooks[hook_name].sort_custom(func(a, b): return a.priority < b.priority)

func unregister(hook_name: String, id: String) -> void:
	if not _hooks.has(hook_name):
		return
	_hooks[hook_name] = _hooks[hook_name].filter(func(h): return h.id != id)

func trigger(hook_name: String, value: Variant = null, context: Dictionary = {}) -> Variant:
	if not _hooks.has(hook_name):
		return value
	var current_value = value
	for hook in _hooks[hook_name]:
		current_value = hook.callback.call(current_value, context)
	return current_value

func has_hooks(hook_name: String) -> bool:
	return _hooks.has(hook_name) and _hooks[hook_name].size() > 0

func clear() -> void:
	_hooks.clear()

func clear_hook(hook_name: String) -> void:
	_hooks.erase(hook_name)