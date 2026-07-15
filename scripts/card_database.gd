## 卡牌数据库：从 JSON 文件加载所有卡牌配置，提供按 ID/标签 检索卡牌的方法。
## Godot 特色：
## - DirAccess 遍历文件系统目录（类似 Python 的 os.listdir）
## - JSON.new().parse() 解析 JSON 字符串
## - FileAccess.get_file_as_string() 一次性读取整个文件内容
## - push_warning() 输出警告信息到 Godot 调试台
class_name CardDatabase

const CARDS_PATH := "res://data/cards/"  ## 卡牌 JSON 文件目录
var _cards: Dictionary = {}  ## 所有卡牌的原始数据 { card_id: dict }

func _init():
	_load_all_cards()

## 遍历 cards 目录，加载所有 .json 文件到 _cards 字典
func _load_all_cards() -> void:
	var dir = DirAccess.open(CARDS_PATH)
	if dir == null:
		push_error("CardDatabase: Cannot open cards directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path = CARDS_PATH + file_name
			var json_text: String = FileAccess.get_file_as_string(file_path)
			var json = JSON.new()
			if json.parse(json_text) == OK:
				var card_id = json.data.get("id", "")
				if card_id != "":
					_cards[card_id] = json.data
		file_name = dir.get_next()
	dir.list_dir_end()

## 根据 id 获取卡牌（普通版）
func get_card(card_id: String) -> CardData:
	if _cards.has(card_id):
		return CardData.new(_cards[card_id])
	push_warning("CardDatabase: Card not found: " + card_id)
	return null

## 根据 id 获取卡牌（升级版）
func get_upgraded_card(card_id: String) -> CardData:
	if _cards.has(card_id):
		return CardData.new(_cards[card_id], true)
	return null

func get_all_card_ids() -> Array:
	return _cards.keys()

## 根据牌组配置创建牌组（如 [{"card_id": "斩击", "count": 3}]）
func create_deck(deck_data: Array) -> Array:
	var deck: Array = []
	for entry in deck_data:
		var card_id = entry.get("card_id", "")
		var count = entry.get("count", 1)
		for i in count:
			var card = get_card(card_id)
			if card != null:
				deck.append(card)
	return deck

## 加载初始牌组（从 decks.json）
func load_starter_deck() -> Array:
	var file_path = "res://data/decks.json"
	var json_text: String = FileAccess.get_file_as_string(file_path)
	var json = JSON.new()
	if json.parse(json_text) == OK:
		var starter_deck = json.data.get("starter_deck", [])
		return create_deck(starter_deck)
	return []

## 根据标签搜索卡牌
func get_cards_by_tag(tag: String) -> Array:
	var result: Array = []
	for card_id in _cards:
		var card = get_card(card_id)
		if card and card.has_tag(tag):
			result.append(card)
	return result

func get_cards_by_any_tags(tags: Array) -> Array:
	var result: Array = []
	for card_id in _cards:
		var card = get_card(card_id)
		if card and card.has_any_tag(tags):
			result.append(card)
	return result

func get_cards_by_all_tags(tags: Array) -> Array:
	var result: Array = []
	for card_id in _cards:
		var card = get_card(card_id)
		if card and card.has_all_tags(tags):
			result.append(card)
	return result

## 随机获取一张拥有指定标签的卡牌
func get_random_card_by_tag(tag: String) -> CardData:
	var matching_cards = get_cards_by_tag(tag)
	if matching_cards.is_empty():
		return null
	return matching_cards.pick_random()
