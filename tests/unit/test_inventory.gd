extends GutTest
## Inventory rules from docs/systems/gathering.md, "Инвентарь",
## with real data/gathering.json and data/items.csv.

var inventory: Inventory


func before_each() -> void:
	inventory = _inventory(GameData.params("gathering"))


func _inventory(params: Dictionary) -> Inventory:
	return Inventory.new(params, GameData.table("items"))


func _two_slots() -> Inventory:
	var params := GameData.params("gathering").duplicate()
	params.inventory_slots = 2
	return _inventory(params)


func test_count_of_missing_item_is_zero() -> void:
	assert_eq(inventory.count("log"), 0)


func test_items_stack_up_to_stack_max() -> void:
	assert_eq(inventory.add("log", 25), 25)
	assert_eq(inventory.slots[0], {"item_id": "log", "count": 20})
	assert_eq(inventory.slots[1], {"item_id": "log", "count": 5})
	assert_eq(inventory.count("log"), 25)


func test_new_kind_needs_a_free_slot_but_stacks_still_fill() -> void:
	var small := _two_slots()
	small.add("stick")
	small.add("stone")
	assert_eq(small.add("leaves"), 0)
	assert_eq(small.space_for("leaves"), 0)
	assert_eq(small.add("stick", 5), 5)
	assert_eq(small.count("stick"), 6)


func test_weight_sums_every_stack() -> void:
	inventory.add("log", 3)
	inventory.add("stick", 2)
	assert_eq(inventory.carried_weight(), 32.0)


func test_five_logs_fill_the_limit_without_slowdown() -> void:
	inventory.add("log", 5)
	assert_eq(inventory.carried_weight(), inventory.carry_limit())
	assert_eq(inventory.speed_mult(), 1.0)


func test_overload_slows_down_to_the_minimum_at_the_cap() -> void:
	inventory.add("log", 6)
	assert_almost_eq(inventory.speed_mult(), 0.8, 0.0001, "60 of 50..75")
	inventory.add("log", 1)
	inventory.add("stick", 5)
	assert_eq(inventory.carried_weight(), inventory.carry_cap())
	assert_almost_eq(inventory.speed_mult(), 0.5, 0.0001)


func test_seventh_log_fits_the_eighth_does_not() -> void:
	inventory.add("log", 7)
	assert_eq(inventory.carry_amount("log"), 0)
	assert_eq(inventory.carry_amount("stick", 10), 5, "5 of weight 1 fill 70 up to 75")


func test_carry_amount_needs_a_free_slot() -> void:
	var small := _two_slots()
	small.add("stick", 99)
	small.add("stone", 99)
	assert_eq(small.carry_amount("stick"), 0)


func test_take_from_a_slot() -> void:
	inventory.add("stick", 3)
	assert_eq(inventory.take(0, 1), {"item_id": "stick", "count": 1})
	assert_eq(inventory.take(0, 5), {"item_id": "stick", "count": 2})
	assert_eq(inventory.slots[0], {})
	assert_eq(inventory.take(0, 1), {})
