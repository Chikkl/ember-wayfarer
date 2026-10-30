extends Node2D
## Prototype world: the player wakes up by a burning campfire in a small forest.

const NODE_SCENE := preload("res://src/world/resource_node.tscn")
## How many resource nodes of each kind the world starts with.
const NODE_COUNTS := {"tree": 70, "bush": 45, "ground_stick": 60, "ground_stone": 40}
## Nodes that grow: they keep CAMP_CLEARING_TILES away from the camp edge.
const GROWING_NODES: Array[String] = ["tree", "bush"]
const WORLD_HALF_SIZE_TILES := 40.0
const CAMP_CLEARING_TILES := 2.0
## Sticks and stones lie anywhere but right at the fire.
const FIRE_CLEARING_TILES := 1.5
const WORLD_SEED := 7

@onready var _world: Node2D = $World
@onready var _campfire: Node2D = $World/Campfire


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	for node_id: String in NODE_COUNTS:
		_scatter(node_id, NODE_COUNTS[node_id], rng)


func _scatter(node_id: String, count: int, rng: RandomNumberGenerator) -> void:
	var clearing := FIRE_CLEARING_TILES
	if node_id in GROWING_NODES:
		clearing = float(GameData.params("comfort").camp_radius) + CAMP_CLEARING_TILES
	var clearing_px := clearing * Units.TILE_PX
	var half_size_px := WORLD_HALF_SIZE_TILES * Units.TILE_PX
	var placed := 0
	while placed < count:
		var point := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * half_size_px
		if point.distance_to(_campfire.position) < clearing_px:
			continue
		var node: ResourceNode = NODE_SCENE.instantiate()
		node.node_id = node_id
		node.position = point
		_world.add_child(node)
		placed += 1
