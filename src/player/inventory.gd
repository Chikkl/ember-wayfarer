class_name Inventory
extends RefCounted
## Items the player carries: slots with stacks and the weight of the load.
## Rules: docs/systems/gathering.md, "Инвентарь". Values: data/gathering.json, data/items.csv.

## One slot per entry: {"item_id": String, "count": int}, an empty slot is an empty Dictionary.
var slots: Array[Dictionary] = []

var _params: Dictionary
var _items: Dictionary
var _carry_limit: float
var _carry_cap: float
var _speed_min: float


func _init(params: Dictionary, items: Dictionary) -> void:
	_params = params
	_items = items
	_carry_limit = float(params.carry_limit)
	_carry_cap = _carry_limit * float(params.overload_cap)
	_speed_min = float(params.overload_speed_min)
	for i in int(params.inventory_slots):
		slots.append({})


func count(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot.get("item_id") == item_id:
			total += slot.count
	return total


## Total weight of everything the player carries.
func carried_weight() -> float:
	var total := 0.0
	for slot in slots:
		if not slot.is_empty():
			total += float(_items[slot.item_id].weight) * slot.count
	return total


func carry_limit() -> float:
	return _carry_limit


## Above this load nothing can be picked up.
func carry_cap() -> float:
	return _carry_cap


## Walking speed multiplier from the load: 1 up to the limit, then down to
## overload_speed_min at the cap.
func speed_mult() -> float:
	var over := inverse_lerp(_carry_limit, _carry_cap, carried_weight())
	return lerpf(1.0, _speed_min, clampf(over, 0.0, 1.0))


## How many of [param item_id] still fit: stacks of it get topped up first,
## a new kind of item needs a free slot.
func space_for(item_id: String) -> int:
	var stack_max := int(_items[item_id].stack_max)
	var space := 0
	for slot in slots:
		if slot.is_empty():
			space += stack_max
		elif slot.item_id == item_id:
			space += stack_max - slot.count
	return space


## How many of [param wanted] the player can pick up: they must fit into the slots,
## and the load after the pickup must not go above the cap.
func carry_amount(item_id: String, wanted := 1) -> int:
	var weight := float(_items[item_id].weight)
	var by_weight := wanted
	if weight > 0.0:
		by_weight = floori((_carry_cap - carried_weight()) / weight + 0.0001)
	return clampi(mini(wanted, mini(space_for(item_id), by_weight)), 0, wanted)


## Adds up to [param amount] items by slot rules, ignoring weight. Returns how many were added.
func add(item_id: String, amount := 1) -> int:
	var stack_max := int(_items[item_id].stack_max)
	var left := amount
	for slot in slots:
		if left > 0 and slot.get("item_id") == item_id and slot.count < stack_max:
			var moved := mini(left, stack_max - slot.count)
			slot.count += moved
			left -= moved
	for i in slots.size():
		if left > 0 and slots[i].is_empty():
			var moved := mini(left, stack_max)
			slots[i] = {"item_id": item_id, "count": moved}
			left -= moved
	return amount - left


## Removes up to [param amount] of [param item_id], the last stacks first.
## Returns how many were removed.
func remove(item_id: String, amount: int) -> int:
	var left := amount
	for i in range(slots.size() - 1, -1, -1):
		if left > 0 and slots[i].get("item_id") == item_id:
			left -= take(i, left).count
	return amount - left


## A copy with its own slots, to try a change before making it.
func copy() -> Inventory:
	var other := Inventory.new(_params, _items)
	for i in slots.size():
		other.slots[i] = slots[i].duplicate()
	return other


## Takes up to [param amount] items out of slot [param index].
## Returns {"item_id", "count"} of what was taken, empty if the slot was empty.
func take(index: int, amount: int) -> Dictionary:
	var slot := slots[index]
	if slot.is_empty():
		return {}
	var taken := mini(amount, slot.count)
	var result := {"item_id": slot.item_id, "count": taken}
	slot.count -= taken
	if slot.count <= 0:
		slots[index] = {}
	return result
