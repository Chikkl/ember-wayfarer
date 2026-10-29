extends GutTest
## Resource nodes in the world and their loot, docs/systems/gathering.md.

const NODE_SCENE := preload("res://src/world/resource_node.tscn")
const PLAYER_SCENE := preload("res://src/player/player.tscn")

var world: Node2D


func before_each() -> void:
	world = Node2D.new()
	add_child_autofree(world)


func _place(node_id: String, point := Vector2.ZERO) -> ResourceNode:
	var node: ResourceNode = NODE_SCENE.instantiate()
	node.node_id = node_id
	node.position = point
	world.add_child(node)
	return node


func _loot_ids() -> Array[String]:
	var ids: Array[String] = []
	for item: GroundItem in get_tree().get_nodes_in_group(GroundItem.GROUP):
		if item.get_parent() == world:
			ids.append(item.item_id)
	ids.sort()
	return ids


func test_felled_tree_becomes_a_stump_and_drops_its_loot() -> void:
	var node := _place("tree")
	for i in 6:
		node.hit()
	assert_eq(node.node_id, "stump")
	assert_true(node.is_workable(), "The stump can be uprooted")
	assert_eq(_loot_ids(), ["log", "log", "log", "stick", "stick"])


func test_uprooted_stump_disappears() -> void:
	var node := _place("stump")
	node.hit()
	node.hit()
	assert_true(node.is_queued_for_deletion())
	assert_eq(_loot_ids(), ["stick", "stick"])


func test_bare_bush_stays() -> void:
	var node := _place("bush")
	for i in 3:
		node.hit()
	assert_false(node.is_workable())
	assert_false(node.is_queued_for_deletion())


func test_picked_stick_disappears_from_the_ground() -> void:
	var node := _place("ground_stick")
	node.hit()
	assert_true(node.is_queued_for_deletion())
	assert_eq(_loot_ids(), ["stick"])


func test_nearest_workable_node_in_radius() -> void:
	var far := _place("bush", Vector2(30, 0))
	var near := _place("bush", Vector2(10, 0))
	_place("bush", Vector2(5, 0)).harvest.hits_left = 0
	var nodes: Array[Node] = [far, near]
	assert_eq(Player.nearest_node(world.get_children(), Vector2.ZERO, 40.0), near)
	assert_eq(Player.nearest_node(nodes, Vector2.ZERO, 8.0), null, "Nothing within 8 px")


func test_loot_in_radius_is_pulled_into_the_inventory() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	var item := GroundItem.new()
	item.item_id = "stone"
	item.position = Vector2(20, 0)
	item.land_at = item.position
	world.add_child(item)
	simulate(item, 30, 0.05, true)
	assert_eq(player.inventory.count("stone"), 1)
	assert_true(item.is_queued_for_deletion())


func test_loot_out_of_radius_stays_on_the_ground() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	var item := GroundItem.new()
	item.item_id = "stone"
	item.position = Vector2(200, 0)
	item.land_at = item.position
	world.add_child(item)
	simulate(item, 30, 0.05, true)
	assert_eq(player.inventory.count("stone"), 0)
	assert_eq(item.position, Vector2(200, 0))
