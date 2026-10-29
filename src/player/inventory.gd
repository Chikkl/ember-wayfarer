class_name Inventory
extends RefCounted
## Items the player carries. For now only counts: slots, stacks and weight
## come with the inventory step. Rules: docs/systems/gathering.md, "Инвентарь".

var _counts := {}


func add(item_id: String, amount := 1) -> void:
	_counts[item_id] = count(item_id) + amount


func count(item_id: String) -> int:
	return _counts.get(item_id, 0)


## Ids of the items the player has, in the order they were first added.
func item_ids() -> Array[String]:
	var ids: Array[String] = []
	for item_id: String in _counts:
		if _counts[item_id] > 0:
			ids.append(item_id)
	return ids
