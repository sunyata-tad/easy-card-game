## 卡牌系统：管理抽牌堆、手牌、弃牌堆、消耗堆四个区域，以及卡牌的抽取、打出、弃置、消耗等操作。
## 类似杀戮尖塔的卡牌流转体系。
## Godot 特色：
## - Array 的 .shuffle() 是内置洗牌方法
## - .pop_front() / .pop_back() / .push_front() 操作数组头尾（类似 Python 的 deque）
## - .pick_random() 随机选取一个元素
class_name CardSystem

## 手牌上限（默认 10，可被卡牌效果/被动修改）
var max_hand_size: int = 10


var draw_pile: Array = []     ## 抽牌堆（牌库）
var hand: Array = []          ## 手牌（当前可用的卡牌）
var discard_pile: Array = []  ## 弃牌堆（使用后进入此处）
var exhaust_pile: Array = []  ## 消耗堆（本场战斗不再使用）

## 卡牌相关信号
## [未连接] 抽到卡牌通知。若已连接接收方，请删除此标记注释。
signal card_drawn(card: CardData)                               ## 抽到卡牌
signal card_played(card: CardData, target)                      ## 卡牌被打出
## [未连接] 卡牌弃置通知。若已连接接收方，请删除此标记注释。
signal card_discarded(card: CardData)                           ## 卡牌被弃置
## [未连接] 卡牌消耗通知。若已连接接收方，请删除此标记注释。
signal card_exhausted(card: CardData)                           ## 卡牌被消耗
signal hand_changed(hand_array: Array)                          ## 手牌发生变化
signal deck_count_changed(draw_count: int, discard_count: int)  ## 抽牌堆/弃牌堆数量变化
## [未连接] 卡牌加入手牌通知。若已连接接收方，请删除此标记注释。
signal card_added_to_hand(card: CardData)                       ## 卡牌被加入手牌（不经过抽牌流程）
signal deck_exhausted()                                         ## 牌库已空

func _init():
	pass

## 用初始牌组初始化所有牌堆，并将抽牌堆洗牌
func initialize_deck(deck: Array) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	
	# 深拷贝卡牌到抽牌堆，避免外部修改影响内部数据
	for card in deck:
		draw_pile.append(card.duplicate())
	
	shuffle_draw_pile()
	_emit_deck_count()

## 洗牌（随机打乱抽牌堆顺序）
func shuffle_draw_pile() -> void:
	draw_pile.shuffle()

## 从抽牌堆抽取指定数量的卡牌到手牌
func draw_cards(count: int) -> Array:
	var drawn_cards: Array = []
	
	for i in count:
		if draw_pile.is_empty():
			deck_exhausted.emit()
			break
		
		var card = draw_pile.pop_front()
		hand.append(card)
		drawn_cards.append(card)
		card_drawn.emit(card)
	
	if drawn_cards.size() > 0:
		hand_changed.emit(hand)
		_emit_deck_count()
	
	return drawn_cards

## 打出手牌中的一张卡牌（带 Exhaust 标签的卡进消耗堆，否则回牌库底部）
func play_card(card: CardData, target = null) -> bool:
	if not hand.has(card):
		return false
	
	hand.erase(card)
	if card.has_tag("Exhaust"):
		exhaust_pile.append(card)
		card_exhausted.emit(card)
	else:
		draw_pile.append(card)
	card_played.emit(card, target)
	hand_changed.emit(hand)
	_emit_deck_count()
	return true


## 弃置全部手牌（回牌库底部）
func discard_hand() -> void:
	while not hand.is_empty():
		var card = hand.pop_back()
		draw_pile.append(card)
		card_discarded.emit(card)
	
	hand_changed.emit(hand)
	_emit_deck_count()

## 直接将一张卡牌加入手牌（不从抽牌堆抽取，是卡牌效果产生的）
func add_to_hand(card: CardData) -> void:
	hand.append(card)
	card_added_to_hand.emit(card)
	card_drawn.emit(card)
	hand_changed.emit(hand)


## 将手牌中的一张牌移回抽牌堆（用于"回到牌库"类效果）
func move_hand_to_draw_pile(card: CardData, to_top: bool = false) -> void:
	if hand.has(card):
		hand.erase(card)
		if to_top:
			draw_pile.push_front(card)
		else:
			draw_pile.append(card)
		hand_changed.emit(hand)
		_emit_deck_count()

## 将牌库中的一张牌移回手牌（用于"墓地回手"类效果，新模型中从牌库取）
func move_discard_to_hand(card: CardData) -> void:
	if draw_pile.has(card):
		draw_pile.erase(card)
		hand.append(card)
		card_drawn.emit(card)
		hand_changed.emit(hand)
		_emit_deck_count()

## 在抽牌堆中按 id 搜索卡牌（不取出）
func search_draw_pile(card_id: String) -> CardData:
	for i in draw_pile.size():
		if draw_pile[i].id == card_id:
			return draw_pile[i]
	return null

## 从抽牌堆搜索并抽取指定 id 的卡牌到手牌
func search_and_draw(card_id: String) -> CardData:
	var card = search_draw_pile(card_id)
	if card != null:
		draw_pile.erase(card)
		hand.append(card)
		card_drawn.emit(card)
		hand_changed.emit(hand)
		_emit_deck_count()
		return card
	return null

## 在牌库中按 id 搜索卡牌（不取出）
func search_discard_pile(card_id: String) -> CardData:
	for i in draw_pile.size():
		if draw_pile[i].id == card_id:
			return draw_pile[i]
	return null

## 从牌库搜索并抽取指定 id 的卡牌到手牌
func search_discard_and_draw(card_id: String) -> CardData:
	var card = search_discard_pile(card_id)
	if card != null:
		draw_pile.erase(card)
		hand.append(card)
		card_drawn.emit(card)
		hand_changed.emit(hand)
		_emit_deck_count()
		return card
	return null

## 获取手牌副本（防止外部直接修改内部数组）
func get_hand() -> Array:
	return hand.duplicate()

func get_draw_pile_count() -> int:
	return draw_pile.size()

func get_discard_pile_count() -> int:
	return 0

## 获取牌组总卡牌数（包含手牌、牌库、消耗堆）
func get_total_deck_count() -> int:
	return draw_pile.size() + hand.size() + exhaust_pile.size()

## 发送抽牌堆/弃牌堆数量变化信号
func _emit_deck_count() -> void:
	deck_count_changed.emit(draw_pile.size(), discard_pile.size())

## 在抽牌堆中按标签搜索卡牌
func search_draw_by_tag(tag: String) -> CardData:
	for i in draw_pile.size():
		if draw_pile[i].has_tag(tag):
			return draw_pile[i]
	return null

## 从抽牌堆按标签搜索并抽取卡牌到手牌
func search_and_draw_by_tag(tag: String) -> CardData:
	var card = search_draw_by_tag(tag)
	if card != null:
		draw_pile.erase(card)
		hand.append(card)
		card_drawn.emit(card)
		hand_changed.emit(hand)
		_emit_deck_count()
		return card
	return null

## 在牌库中按标签搜索卡牌
func search_discard_by_tag(tag: String) -> CardData:
	for i in draw_pile.size():
		if draw_pile[i].has_tag(tag):
			return draw_pile[i]
	return null

## 从牌库按标签搜索并抽取卡牌到手牌
func search_discard_and_draw_by_tag(tag: String) -> CardData:
	var card = search_discard_by_tag(tag)
	if card != null:
		draw_pile.erase(card)
		hand.append(card)
		card_drawn.emit(card)
		hand_changed.emit(hand)
		_emit_deck_count()
		return card
	return null


## 随机消耗一张手牌
func exhaust_random_hand_card() -> CardData:
	if hand.is_empty():
		return null
	var card = hand.pick_random()
	hand.erase(card)
	exhaust_pile.append(card)
	card_exhausted.emit(card)
	hand_changed.emit(hand)
	_emit_deck_count()
	return card

## 随机弃置一张手牌（回牌库底部）
func discard_random_hand_card() -> CardData:
	if hand.is_empty():
		return null
	var card = hand.pick_random()
	hand.erase(card)
	draw_pile.append(card)
	card_discarded.emit(card)
	hand_changed.emit(hand)
	_emit_deck_count()
	return card

## 弃置指定的手牌（回牌库底部）
func discard_specific_card(card: CardData) -> bool:
	if not hand.has(card):
		return false
	hand.erase(card)
	draw_pile.append(card)
	card_discarded.emit(card)
	hand_changed.emit(hand)
	_emit_deck_count()
	return true


## 回合结束时弃置超出上限的手牌（回牌库底部）
func end_turn_discard() -> void:
	while hand.size() > max_hand_size:
		var card = hand.pop_back()
		draw_pile.append(card)
		card_discarded.emit(card)
	
	hand_changed.emit(hand)
	_emit_deck_count()

## 手动将弃牌堆洗回抽牌堆（新模型中打出已回牌库，此操作无需执行）
func manual_shuffle_discard_to_draw() -> void:
	pass
