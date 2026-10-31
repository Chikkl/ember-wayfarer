extends GutTest
## Clicks on the inventory bar find the slot under the mouse.

var bar: InventoryBar


func before_each() -> void:
	bar = InventoryBar.new()
	add_child_autofree(bar)
	bar.setup(Inventory.new(GameData.params("gathering"), GameData.table("items")))


func test_slot_at_finds_every_slot() -> void:
	var found := []
	for i in bar.inventory.slots.size():
		found.append(bar.slot_at(bar.slot_rect(i).get_center()))
	assert_eq(found, range(bar.inventory.slots.size()))


func test_slot_at_misses_the_load_bar_and_gaps() -> void:
	assert_eq(bar.slot_at(Vector2(5, 5)), -1, "The load bar is above the slots")
	var gap := bar.slot_rect(0).end + Vector2(SlotGrid.GAP_PX / 2.0, 0)
	assert_eq(bar.slot_at(Vector2(gap.x, bar.slot_rect(0).get_center().y)), -1)
