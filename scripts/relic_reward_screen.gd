## 遗物奖励场景：Boss 战后遗物三选一。
## 逻辑：从遗物池随机 3 件（头环填补空缺）→ 玩家选 1 → 加入遗物 → 返回地图。
## UI 布局由 RelicRewardScreen.tscn 提供（CenterContainer 居中）；本脚本只填充动态卡片。
extends Control

const CHOICE_CARD_SCENE := preload("res://scenes/RelicChoiceCard.tscn")

var _choices: Array = []   ## 当前展示的三件遗物（RelicData）

@onready var choices_container: HBoxContainer = $%ChoicesContainer

func _ready():
	_build_ui()

func _build_ui() -> void:
	_choices = _roll_choices()
	for relic in _choices:
		var card = CHOICE_CARD_SCENE.instantiate()
		card.setup(relic)
		card.picked.connect(_on_pick)
		choices_container.add_child(card)
	# 窗口过小时整体缩放，保证可完整显示与点击
	await get_tree().process_frame
	_fit_to_viewport()

## 若卡片总宽度/总高度超出视口，按比例缩小整体容器
func _fit_to_viewport() -> void:
	var vp := get_viewport_rect().size
	var required := choices_container.get_combined_minimum_size()
	var s: float = 1.0
	if required.x > vp.x:
		s = vp.x / required.x
	if required.y > vp.y:
		s = minf(s, vp.y / required.y)
	if s < 1.0:
		$Center.pivot_offset = $Center.size * 0.5
		$Center.scale = Vector2(s, s)

## 供测试/外部读取当前展示的遗物选项
func get_choices() -> Array:
	return _choices

## 从遗物池抽取 3 件：头环（placeholder_crown）用于填补所有空缺。
## 只有头环可重复；其余遗物不可重复。
## 真实遗物不足 3 件时用头环补齐；一个正常遗物则配两个头环；没有任何可选则三个头环。
const CROWN_ID := "placeholder_crown"

func _roll_choices() -> Array:
	var relic_db := RelicDatabase.new()
	var owned: Array = GameData.get_relic_ids() if GameData else []
	# 真实遗物池：非头环 + 不可重复 + 未拥有
	var real_pool: Array = []
	for rid in relic_db.get_all_relic_ids():
		if rid == CROWN_ID:
			continue
		var r = relic_db.get_relic(rid)
		if r and not r.repeatable and not owned.has(rid):
			real_pool.append(rid)
	real_pool.shuffle()
	var picked: Array = []
	for i in mini(3, real_pool.size()):
		var relic = relic_db.get_relic(real_pool[i])
		if relic:
			picked.append(relic)
	# 用头环填补空缺（保证始终 3 个选项）
	var crown = relic_db.get_relic(CROWN_ID)
	while picked.size() < 3 and crown:
		picked.append(crown)
	return picked

func _on_pick(relic: RelicData) -> void:
	if GameData:
		GameData.grant_relic(relic.id)
	SaveManager.save_map_state()
	var cached = SaveManager.get_cached_map_state()
	var map_id = "test" if cached.get("test_mode", false) else "endless"
	GameManager.go_to_map(map_id, cached)
