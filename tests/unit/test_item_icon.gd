extends GutTest
## Placeholder item pictures: every item in data/items.csv has its own.


func test_every_item_has_a_picture() -> void:
	for item_id: String in GameData.table("items"):
		assert_has(ItemIcon.COLORS, item_id, "%s would show as a magenta dot" % item_id)
