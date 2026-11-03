extends GutTest
## Hold-to-work with the real input and physics frames, docs/systems/gathering.md.

const NODE_SCENE := preload("res://src/world/resource_node.tscn")
const PLAYER_SCENE := preload("res://src/player/player.tscn")
const FPS := 60

var world: Node2D
var player: Player


func before_each() -> void:
	world = Node2D.new()
	add_child_autofree(world)
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)


func after_each() -> void:
	Input.action_release("interact")


func _place(node_id: String) -> ResourceNode:
	var node: ResourceNode = NODE_SCENE.instantiate()
	node.node_id = node_id
	node.position = Vector2(15, 0)
	world.add_child(node)
	return node


func _hold_interact(seconds: float) -> void:
	Input.action_press("interact")
	await wait_physics_frames(roundi(seconds * FPS))
	Input.action_release("interact")


func test_holding_strips_a_bush_into_the_inventory() -> void:
	var bush := _place("bush")
	await _hold_interact(1.5)
	assert_false(bush.is_workable(), "3 hits at 0.6 s fit into 1.5 s")
	await wait_seconds(1.0)
	assert_eq(player.inventory.count("leaves"), 6)
	assert_almost_eq(player.stamina.fatigue, 0.36, 0.001, "3 hits of 4 stamina were spent")
	assert_eq(player.progression.xp, 6, "1 xp per leaf, given when the leaves drop")


func test_tree_without_axe_only_shakes() -> void:
	var tree := _place("tree")
	var stamina := player.stamina.value
	await _hold_interact(0.7)
	assert_eq(tree.harvest.hits_left, 6)
	assert_eq(player.stamina.value, stamina)
	assert_eq(player.progression.xp, 0, "Pushing gives no xp")


func test_chopper_fells_a_tree_with_light_quick_strikes() -> void:
	player.inventory.add("chopper")
	var tree := _place("tree")
	await _hold_interact(5.7)
	assert_eq(tree.node_id, "stump", "15 strikes every 0.4 s take 5.6 s")
	assert_eq(tree.harvest.hits_left, 2.0, "The chopper does not take the stump")
	assert_almost_eq(player.stamina.fatigue, 2.25, 0.001, "15 strikes of 5 stamina")
	assert_eq(player.progression.xp, 14, "The same xp for a tree with any tool")


func test_axe_is_taken_over_the_chopper() -> void:
	player.inventory.add("chopper")
	player.inventory.add("stone_axe")
	var tree := _place("tree")
	await _hold_interact(3.1)
	assert_eq(tree.node_id, "stump", "6 strikes every 0.6 s take 3.0 s")
	assert_almost_eq(player.stamina.fatigue, 1.44, 0.001, "6 strikes of 8 stamina")


func test_picked_stick_goes_straight_into_the_inventory() -> void:
	_place("ground_stick")
	await _hold_interact(0.05)
	assert_eq(player.inventory.count("stick"), 1, "No hop and pull: the pickup is instant")
	assert_eq(_piles().size(), 0)


func test_stone_over_the_cap_stays_on_the_ground() -> void:
	player.inventory.add("log", 7)
	player.inventory.add("stone", 2)
	_place("ground_stone")
	await _hold_interact(0.05)
	assert_eq(player.inventory.count("stone"), 2, "74 of 75: one more stone does not fit")
	assert_eq(_piles().size(), 1, "The stone lies on the ground")


func _piles() -> Array[Node]:
	return world.get_children().filter(func(node: Node) -> bool: return node is GroundItem)


func test_crafting_while_standing_makes_the_item() -> void:
	player.inventory.add("stone", 2)
	assert_true(player.start_craft("chopper"))
	await wait_seconds(2.2)
	assert_eq(player.inventory.count("chopper"), 1)
	assert_eq(player.progression.xp, 4, "First chopper")


func test_a_step_cancels_crafting_and_keeps_the_materials() -> void:
	player.inventory.add("stone", 2)
	player.start_craft("chopper")
	await wait_physics_frames(30)
	Input.action_press("move_right")
	await wait_physics_frames(5)
	Input.action_release("move_right")
	await wait_seconds(2.0)
	assert_eq(player.inventory.count("chopper"), 0)
	assert_eq(player.inventory.count("stone"), 2)
