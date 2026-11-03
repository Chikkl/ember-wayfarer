class_name SlotMoves
extends RefCounted
## Moving stacks between slots of inventories: the player's and baskets.
## The player's inventory takes no more than its load cap allows.
## Rules: docs/systems/gathering.md, "Инвентарь", rule 7.


## Moves the stack in slot [param from_index] of [param from] onto slot
## [param to_index] of [param to]: into an empty slot, onto the same item up to
## stack_max, or swaps two different items if both loads allow it.
## Returns how many items moved.
static func move(from: Inventory, from_index: int, to: Inventory, to_index: int) -> int:
	if from == to and from_index == to_index:
		return 0
	var source := from.slots[from_index]
	if source.is_empty():
		return 0
	var item_id: String = source.item_id
	var target := to.slots[to_index]
	if target.is_empty() or target.item_id == item_id:
		var amount := mini(source.count, to.stack_max(item_id) - target.get("count", 0))
		if from != to:
			amount = mini(amount, to.weight_room_for(item_id))
		if amount <= 0:
			return 0
		from.take(from_index, amount)
		if target.is_empty():
			to.slots[to_index] = {"item_id": item_id, "count": amount}
		else:
			target.count += amount
		return amount
	if from != to and not (_fits_swap(from, source, target) and _fits_swap(to, target, source)):
		return 0
	from.slots[from_index] = target
	to.slots[to_index] = source
	return source.count


## Moves as much of the stack in slot [param index] of [param from] as fits into
## [param to], its stacks first. Returns how many items moved.
static func quick_move(from: Inventory, index: int, to: Inventory) -> int:
	var source := from.slots[index]
	if source.is_empty():
		return 0
	var item_id: String = source.item_id
	var amount := to.carry_amount(item_id, source.count)
	if amount <= 0:
		return 0
	from.take(index, amount)
	to.add(item_id, amount)
	return amount


## Whether [param inventory] stays within its load after [param outgoing] leaves
## and [param incoming] comes in.
static func _fits_swap(inventory: Inventory, outgoing: Dictionary, incoming: Dictionary) -> bool:
	if not inventory.limit_weight:
		return true
	var weight := inventory.carried_weight()
	weight -= inventory.item_weight(outgoing.item_id) * outgoing.count
	weight += inventory.item_weight(incoming.item_id) * incoming.count
	return weight <= inventory.carry_cap() + 0.0001
