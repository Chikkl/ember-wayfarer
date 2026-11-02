class_name ComfortItem
extends Node2D
## A placed comfort item. A camp counts it if its center is inside the camp zone.

const GROUP := "comfort_items"

## Row id in data/comfort_items.csv.
@export var item_id := ""


func _ready() -> void:
	add_to_group(GROUP)


## Distance from [param point] to the item. A building counts from its edge.
func distance_to(point: Vector2) -> float:
	return global_position.distance_to(point)
