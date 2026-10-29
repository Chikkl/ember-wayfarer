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


func test_tree_without_axe_only_shakes() -> void:
	var tree := _place("tree")
	var stamina := player.stamina.value
	await _hold_interact(0.7)
	assert_eq(tree.harvest.hits_left, 6)
	assert_eq(player.stamina.value, stamina)
