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
	return CampComfort.compute(_item_ids(), GameData.table("comfort_items"))


## The best comfort item of each group inside the camp, {group: item_id}.
func best_by_group() -> Dictionary:
	return CampComfort.best_by_group(_item_ids(), GameData.table("comfort_items"))


## Comfort of this camp if one more [param item_id] stood inside it.
func comfort_with(item_id: String) -> int:
	var ids := _item_ids()
	ids.append(item_id)
	return CampComfort.compute(ids, GameData.table("comfort_items"))


func _item_ids() -> Array[String]:
	var ids: Array[String] = []
	for item: ComfortItem in get_tree().get_nodes_in_group(ComfortItem.GROUP):
		if contains(item.global_position):
			ids.append(item.item_id)
	return ids


## Comfort at [param point]: zero outside every camp.
static func comfort_at(tree: SceneTree, point: Vector2) -> int:
	var best := 0
	for camp: Camp in tree.get_nodes_in_group(GROUP):
		if camp.contains(point):
			best = maxi(best, camp.comfort())
	return best
