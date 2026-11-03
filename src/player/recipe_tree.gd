class_name RecipeTree
extends RefCounted
## Nodes of the recipe tree: which are open, which can be opened and which
## recipes they give. Rules: docs/systems/tech-tree.md, "Дерево".
## Values: data/recipe_tree.csv.

signal node_opened(node_id: String)

enum State { OPEN, AVAILABLE, LOCKED }

## Rows of data/recipe_tree.csv by id, in file order.
var nodes: Dictionary

var _open: Array[String] = []


func _init(rows: Dictionary) -> void:
	nodes = rows


func is_open(node_id: String) -> bool:
	return node_id in _open


## Open, available (all requirements open) or locked by a requirement.
func state(node_id: String) -> State:
	if is_open(node_id):
		return State.OPEN
	for required in requirements(node_id):
		if not is_open(required):
			return State.LOCKED
	return State.AVAILABLE


func requirements(node_id: String) -> Array[String]:
	return _ids(nodes[node_id].requires)


func unlocks(node_id: String) -> Array[String]:
	return _ids(nodes[node_id].unlocks)


func cost(node_id: String) -> int:
	return int(nodes[node_id].cost)


## Opens [param node_id] for its cost in points of [param progression].
## False if it is locked, already open or there are not enough points.
func open(node_id: String, progression: Progression) -> bool:
	if state(node_id) != State.AVAILABLE or not progression.spend_points(cost(node_id)):
		return false
	_open.append(node_id)
	node_opened.emit(node_id)
	return true


## Recipes of all open nodes, in the order the nodes were opened.
func unlocked_recipes() -> Array[String]:
	var recipes: Array[String] = []
	for node_id in _open:
		recipes.append_array(unlocks(node_id))
	return recipes


## Column of [param node_id] on the tree screen: the longest chain of
## requirements before it.
func depth(node_id: String) -> int:
	var deepest := -1
	for required in requirements(node_id):
		deepest = maxi(deepest, depth(required))
	return deepest + 1


func _ids(cell: Variant) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(str(cell).split(";", false))
	return ids
