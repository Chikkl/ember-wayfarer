extends GutTest
## Loot on the ground and dropping it, docs/systems/gathering.md, "Добыча" and "Инвентарь".

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const STEPS := 30
const STEP := 0.05

var world: Node2D
var player: Player


func before_each() -> void:
	world = Node2D.new()
	add_child_autofree(world)
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)


func _pile(item_id: String, count: int, point: Vector2) -> GroundItem:
	var item := GroundItem.new()
	item.item_id = item_id
	item.count = count
	item.position = point
	item.land_at = point
	world.add_child(item)
	return item


func _piles() -> Array[GroundItem]:
	var piles: Array[GroundItem] = []
	for node in world.get_children():
		if node is GroundItem and not node.is_queued_for_deletion():
			piles.append(node)
	return piles


func test_loot_in_radius_is_pulled_into_the_inventory() -> void:
	var item := _pile("stone", 1, Vector2(20, 0))
	simulate(item, STEPS, STEP, true)
	assert_eq(player.inventory.count("stone"), 1)
	assert_true(item.is_queued_for_deletion())


func test_loot_out_of_radius_stays_on_the_ground() -> void:
	var item := _pile("stone", 1, Vector2(200, 0))
	simulate(item, STEPS, STEP, true)
	assert_eq(player.inventory.count("stone"), 0)
	assert_eq(item.position, Vector2(200, 0))


func test_loot_fades_and_disappears_after_its_lifetime() -> void:
	var lifetime := float(GameData.params("gathering").ground_item_lifetime)
	var item := _pile("stone", 1, Vector2(200, 0))
	simulate(item, 1, lifetime - 10.0, true)
	assert_eq(item.modulate.a, 1.0)
	simulate(item, 1, 8.5, true)
	assert_almost_eq(item.modulate.a, 0.5, 0.001, "Halfway through the fade")
	assert_false(item.is_queued_for_deletion())
	simulate(item, 1, 1.5, true)
	assert_true(item.is_queued_for_deletion())


func test_loot_over_the_cap_is_not_pulled() -> void:
	player.inventory.add("log", 7)
	var item := _pile("log", 1, Vector2(20, 0))
	simulate(item, STEPS, STEP, true)
	assert_eq(player.inventory.count("log"), 7)
	assert_eq(item.position, Vector2(20, 0))


func test_pile_is_picked_up_as_far_as_the_cap_allows() -> void:
	player.inventory.add("log", 7)
	var item := _pile("stick", 10, Vector2(20, 0))
	simulate(item, STEPS, STEP, true)
	assert_eq(player.inventory.count("stick"), 5)
	assert_eq(item.count, 5)
	assert_false(item.is_queued_for_deletion())


func test_drop_one_item_from_a_slot() -> void:
	player.inventory.add("stick", 3)
	player.drop_from_slot(0, false)
	assert_eq(player.inventory.count("stick"), 2)
	var piles := _piles()
	assert_eq(piles.size(), 1)
	assert_eq([piles[0].item_id, piles[0].count], ["stick", 1])


func test_drop_the_whole_stack() -> void:
	player.inventory.add("stick", 3)
	player.drop_from_slot(0, true)
	assert_eq(player.inventory.slots[0], {})
	assert_eq(_piles()[0].count, 3)


func test_dropped_pile_waits_until_the_player_walks_away() -> void:
	player.inventory.add("stone", 2)
	player.drop_from_slot(0, true)
	var item := _piles()[0]
	simulate(item, STEPS, STEP, true)
	assert_eq(player.inventory.count("stone"), 0, "Standing next to it does not pull it back")
	player.position = Vector2(500, 0)
	simulate(item, 1, STEP, true)
	player.position = Vector2.ZERO
	simulate(item, STEPS, STEP, true)
	assert_eq(player.inventory.count("stone"), 2)
