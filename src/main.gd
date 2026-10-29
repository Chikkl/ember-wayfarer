extends Node2D
## Prototype world: the player wakes up by a burning campfire in a small forest.

const TREE_SCENE := preload("res://src/world/tree_stub.tscn")
const TREE_COUNT := 70
const WORLD_HALF_SIZE_TILES := 40.0
## Trees keep this many tiles away from the camp edge.
const CAMP_CLEARING_TILES := 2.0
const TREE_SEED := 7

@onready var _world: Node2D = $World
@onready var _campfire: Node2D = $World/Campfire


func _ready() -> void:
	_plant_trees()


func _plant_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var clearing := float(GameData.params("comfort").camp_radius) + CAMP_CLEARING_TILES
	var clearing_px := clearing * Units.TILE_PX
	var half_size_px := WORLD_HALF_SIZE_TILES * Units.TILE_PX
	var planted := 0
	while planted < TREE_COUNT:
		var point := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * half_size_px
		if point.distance_to(_campfire.position) < clearing_px:
			continue
		var tree := TREE_SCENE.instantiate()
		tree.position = point
		_world.add_child(tree)
		planted += 1
