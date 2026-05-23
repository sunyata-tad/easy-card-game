class_name CardSystem

const MAX_HAND_SIZE: int = 10

var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []

signal card_drawn(card: CardData)
signal card_played(card: CardData, target)
signal card_discarded(card: CardData)
signal card_exhausted(card: CardData)
signal hand_changed(hand_array: Array)
signal deck_count_changed(draw_count: int, discard_count: int)
signal card_added_to_hand(card: CardData)
signal deck_exhausted()

func _init():
	pass

func initialize_deck(deck: Array) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	
	for card in deck:
		draw_pile.append(card.duplicate())
	
	shuffle_draw_pile()
	_emit_deck_count()

func shuffle_draw_pile() -> void:
	draw_pile.shuffle()

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

func _shuffle_discard_into_draw() -> void:
	while not discard_pile.is_empty():
		draw_pile.append(discard_pile.pop_front())
	shuffle_draw_pile()

func play_card(card: CardData, target = null) -> bool:
	if not hand.has(card):
		return false
	
	hand.erase(card)
	discard_pile.append(card)
	card_played.emit(card, target)
	hand_changed.emit(hand)
	_emit_deck_count()
	return true

func exhaust_card(card: CardData) -> void:
	if hand.has(card):
		hand.erase(card)
		exhaust_pile.append(card)
		card_exhausted.emit(card)
		hand_changed.emit(hand)
		_emit_deck_count()

func discard_hand() -> void:
	while not hand.is_empty():
		var card = hand.pop_back()
		discard_pile.append(card)
		card_discarded.emit(card)
	
	hand_changed.emit(hand)
	_emit_deck_count()

func add_to_hand(card: CardData) -> void:
	hand.append(card)
	card_added_to_hand.emit(card)
	card_drawn.emit(card)
	hand_changed.emit(hand)

func add_to_draw_pile(card: CardData, to_top: bool = false) -> void:
	if to_top:
		draw_pile.push_front(card.duplicate())
	else:
		draw_pile.append(card.duplicate())
	_emit_deck_count()

func add_to_discard(card: CardData) -> void:
	discard_pile.append(card.duplicate())
	_emit_deck_count()

func search_draw_pile(card_id: String) -> CardData:
	for i in draw_pile.size():
		if draw_pile[i].id == card_id:
			return draw_pile[i]
	return null

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

func search_discard_pile(card_id: String) -> CardData:
	for i in discard_pile.size():
		if discard_pile[i].id == card_id:
			return discard_pile[i]
	return null

func search_discard_and_draw(card_id: String) -> CardData:
	var card = search_discard_pile(card_id)
	if card != null:
		discard_pile.erase(card)
		hand.append(card)
		card_drawn.emit(card)
		hand_changed.emit(hand)
		_emit_deck_count()
		return card
	return null

func get_hand() -> Array:
	return hand.duplicate()

func get_draw_pile_count() -> int:
	return draw_pile.size()

func get_discard_pile_count() -> int:
	return discard_pile.size()

func get_total_deck_count() -> int:
	return draw_pile.size() + hand.size() + discard_pile.size() + exhaust_pile.size()

func _emit_deck_count() -> void:
	deck_count_changed.emit(draw_pile.size(), discard_pile.size())

func search_draw_by_tag(tag: String) -> CardData:
	for i in draw_pile.size():
		if draw_pile[i].has_tag(tag):
			return draw_pile[i]
	return null

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

func search_discard_by_tag(tag: String) -> CardData:
	for i in discard_pile.size():
		if discard_pile[i].has_tag(tag):
			return discard_pile[i]
	return null

func search_discard_and_draw_by_tag(tag: String) -> CardData:
	var card = search_discard_by_tag(tag)
	if card != null:
		discard_pile.erase(card)
		hand.append(card)
		card_drawn.emit(card)
		hand_changed.emit(hand)
		_emit_deck_count()
		return card
	return null

func exhaust_hand_card(card: CardData) -> bool:
	if hand.has(card):
		hand.erase(card)
		exhaust_pile.append(card)
		card_exhausted.emit(card)
		hand_changed.emit(hand)
		_emit_deck_count()
		return true
	return false

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

func discard_random_hand_card() -> CardData:
	if hand.is_empty():
		return null
	var card = hand.pick_random()
	hand.erase(card)
	discard_pile.append(card)
	card_discarded.emit(card)
	hand_changed.emit(hand)
	_emit_deck_count()
	return card

func discard_specific_card(card: CardData) -> bool:
	if not hand.has(card):
		return false
	hand.erase(card)
	discard_pile.append(card)
	card_discarded.emit(card)
	hand_changed.emit(hand)
	_emit_deck_count()
	return true

func get_cards_in_hand_by_tag(tag: String) -> Array:
	var result: Array = []
	for card in hand:
		if card.has_tag(tag):
			result.append(card)
	return result

func count_cards_in_hand_with_tag(tag: String) -> int:
	var count = 0
	for card in hand:
		if card.has_tag(tag):
			count += 1
	return count

func end_turn_discard() -> void:
	while hand.size() > MAX_HAND_SIZE:
		var card = hand.pop_back()
		discard_pile.append(card)
		card_discarded.emit(card)
	
	hand_changed.emit(hand)
	_emit_deck_count()

func manual_shuffle_discard_to_draw() -> void:
	if discard_pile.is_empty():
		return
	
	while not discard_pile.is_empty():
		draw_pile.append(discard_pile.pop_front())
	
	shuffle_draw_pile()
	_emit_deck_count()
