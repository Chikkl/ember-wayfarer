class_name Camp
extends Node2D
## Camp zone around a campfire. Rules: docs/systems/comfort.md.

const GROUP := "camps"

var _radius_px: float


func _ready() -> void:
	add_to_group(GROUP)
	_radius_px = float(GameData.params("comfort").camp_radius) * Units.TILE_PX


func contains(point: Vector2) -> bool:
	return global_position.distance_to(point) <= _radius_px


## Comfort of this camp from the comfort items inside its zone.
func comfort() -> int:
	var ids: Array[String] = []
	for item: ComfortItem in get_tree().get_nodes_in_group(ComfortItem.GROUP):
		if contains(item.global_position):
			ids.append(item.item_id)
	return CampComfort.compute(ids, GameData.table("comfort_items"))


## Comfort at [param point]: zero outside every camp.
static func comfort_at(tree: SceneTree, point: Vector2) -> int:
	var best := 0
	for camp: Camp in tree.get_nodes_in_group(GROUP):
		if camp.contains(point):
			best = maxi(best, camp.comfort())
	return best
