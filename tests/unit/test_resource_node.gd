extends GutTest
## Resource nodes in the world, their loot and comeback, docs/systems/gathering.md.

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


func _hit_all(node: ResourceNode) -> void:
	while node.is_workable() and not node.is_queued_for_deletion():
		node.hit()


func _wait(node: ResourceNode, seconds: float) -> void:
	simulate(node, 1, seconds, true)


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


func test_stump_grows_back_into_a_tree() -> void:
	var node := _place("tree")
	_hit_all(node)
	_wait(node, 299.0)
	assert_eq(node.node_id, "stump")
	_wait(node, 1.0)
	assert_eq(node.node_id, "tree")
	assert_eq(node.harvest.hits_left, 6)


func test_uprooted_stump_of_a_felled_tree_never_comes_back() -> void:
	var node := _place("tree")
	_hit_all(node)
	_hit_all(node)
	assert_true(node.is_queued_for_deletion())


func test_bare_bush_stays_until_it_regrows() -> void:
	var node := _place("bush")
	_hit_all(node)
	assert_false(node.is_workable())
	assert_false(node.is_queued_for_deletion())
	_wait(node, 179.0)
	assert_false(node.is_workable())
	_wait(node, 1.0)
	assert_eq(node.harvest.hits_left, 3)


func test_picked_stick_comes_back_in_its_zone() -> void:
	var node := _place("ground_stick", Vector2(100, 0))
	node.hit()
	assert_eq(_loot_ids(), ["stick"])
	assert_false(node.visible)
	assert_false(node.is_workable())
	_wait(node, 119.0)
	assert_false(node.visible)
	_wait(node, 1.0)
	assert_true(node.visible)
	assert_true(node.is_workable())
	var radius := float(GameData.params("gathering").respawn_radius) * Units.TILE_PX
	assert_lt(node.position.distance_to(Vector2(100, 0)), radius + 0.001)


func test_stick_comes_back_away_from_the_player_and_camp_items() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	var fire := ComfortItem.new()
	fire.item_id = "campfire"
	fire.position = Vector2(64, 0)
	world.add_child(fire)
	var stones: Array[ResourceNode] = []
	for i in 10:
		var stone := _place("ground_stone", Vector2(i * 0.1, 0))
		stone.hit()
		_wait(stone, 120.0)
		stones.append(stone)
	for stone in stones:
		assert_gte(stone.position.distance_to(player.position), Units.TILE_PX)
		assert_gte(stone.position.distance_to(fire.position), 1.5 * Units.TILE_PX)


func test_nearest_workable_node_in_radius() -> void:
	var far := _place("bush", Vector2(30, 0))
	var near := _place("bush", Vector2(10, 0))
	_place("bush", Vector2(5, 0)).harvest.hits_left = 0
	var nodes: Array[Node] = [far, near]
	assert_eq(Player.nearest_node(world.get_children(), Vector2.ZERO, 40.0), near)
	assert_eq(Player.nearest_node(nodes, Vector2.ZERO, 8.0), null, "Nothing within 8 px")
