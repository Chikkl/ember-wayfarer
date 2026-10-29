extends GutTest
## Item counts of the player inventory.


func test_count_of_missing_item_is_zero() -> void:
	assert_eq(Inventory.new().count("log"), 0)


func test_add_sums_counts() -> void:
	var inventory := Inventory.new()
	inventory.add("stick")
	inventory.add("stick", 2)
	assert_eq(inventory.count("stick"), 3)


func test_item_ids_keep_the_order_of_first_add() -> void:
	var inventory := Inventory.new()
	inventory.add("leaves")
	inventory.add("stick")
	inventory.add("leaves")
	assert_eq(inventory.item_ids(), ["leaves", "stick"])
