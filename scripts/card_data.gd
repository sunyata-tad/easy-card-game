class_name CardData

var id: String
var name: String
var type: String
var description: String
var rarity: String
var target_type: String
var effects: Array
var is_upgraded: bool = false
var tags: Array = []
var treated_as: Array = []

func _init(data: Dictionary, upgraded: bool = false):
	id = data.get("id", "")
	is_upgraded = upgraded

	if upgraded and data.has("upgrade"):
		var upgrade_data = data.upgrade
		name = upgrade_data.get("name", data.name + "+")
		description = upgrade_data.get("description", data.description)
		effects = upgrade_data.get("effects", data.effects)
	else:
		name = data.get("name", "")
		description = data.get("description", "")
		effects = data.get("effects", [])

	type = data.get("type", "attack")
	rarity = data.get("rarity", "common")
	target_type = data.get("target_type", "single_enemy")
	tags = data.get("tags", [])
	treated_as = data.get("treated_as", [])

func get_description_text() -> String:
	var text = description
	for effect in effects:
		var key = effect.get("scaling_key", "")
		if key != "":
			var placeholder = "{" + key + "}"
			text = text.replace(placeholder, str(effect.value))
	return text

func duplicate() -> CardData:
	var data = {
		"id": id,
		"name": name,
		"type": type,
		"description": description,
		"rarity": rarity,
		"target_type": target_type,
		"effects": effects.duplicate(true),
		"tags": tags.duplicate(),
		"treated_as": treated_as.duplicate()
	}
	return CardData.new(data, is_upgraded)

func has_tag(tag: String) -> bool:
	return tags.has(tag) or treated_as.has(tag)

func has_any_tag(check_tags: Array) -> bool:
	for tag in check_tags:
		if has_tag(tag):
			return true
	return false

func has_all_tags(check_tags: Array) -> bool:
	for tag in check_tags:
		if not has_tag(tag):
			return false
	return true

func get_all_tags() -> Array:
	var all_tags = tags.duplicate()
	for tag in treated_as:
		if not all_tags.has(tag):
			all_tags.append(tag)
	return all_tags

func add_tag(tag: String) -> void:
	if not tags.has(tag):
		tags.append(tag)

func remove_tag(tag: String) -> void:
	tags.erase(tag)

func add_treated_as(tag: String) -> void:
	if not treated_as.has(tag):
		treated_as.append(tag)

func remove_treated_as(tag: String) -> void:
	treated_as.erase(tag)
