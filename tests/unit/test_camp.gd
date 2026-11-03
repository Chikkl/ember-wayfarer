extends GutTest
## Camp zone rules from docs/systems/comfort.md with real data/comfort.json.

var camp: Camp
var radius_px: float


func before_each() -> void:
	radius_px = float(GameData.params("comfort").camp_radius) * Units.TILE_PX
	camp = Camp.new()
	add_child_autofree(camp)


func _place(item_id: String, point: Vector2) -> void:
	var item := ComfortItem.new()
	item.item_id = item_id
	item.position = point
	add_child_autofree(item)


func test_item_counts_when_center_is_inside() -> void:
	_place("campfire", Vector2.ZERO)
	_place("bedroll", Vector2(radius_px - 1.0, 0))
	assert_eq(camp.comfort(), 4)


func test_item_on_the_edge_counts() -> void:
	_place("campfire", Vector2.ZERO)
	_place("bedroll", Vector2(0, radius_px))
	assert_eq(camp.comfort(), 4)


func test_item_outside_does_not_count() -> void:
	_place("campfire", Vector2.ZERO)
	_place("bedroll", Vector2(radius_px + 1.0, 0))
	assert_eq(camp.comfort(), 2)


func test_comfort_is_zero_outside_camp() -> void:
	_place("campfire", Vector2.ZERO)
	assert_eq(Camp.comfort_at(get_tree(), Vector2(10, 10)), 2)
	assert_eq(Camp.comfort_at(get_tree(), Vector2(radius_px + 1.0, 0)), 0)
