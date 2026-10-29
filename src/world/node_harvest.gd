class_name NodeHarvest
extends RefCounted
## Hits and loot of one resource node: a stick on the ground, a bush, a tree.
## Rules: docs/systems/gathering.md, "Действия". Values: data/resource_nodes.csv.

## Tools every player has from the start.
const NO_TOOL: Array[String] = ["pickup", "hands"]

var node_id: String
var hits: int
var hits_left: int
var stamina_cost: float
## Item id of the tool the node needs, or one of [constant NO_TOOL].
var tool_id: String
## Seconds until a depleted node is back; 0 if it never comes back.
var respawn: float

var _drops: Dictionary
var _per_hit: bool


func _init(row: Dictionary) -> void:
	node_id = row.id
	hits = int(row.hits)
	hits_left = hits
	stamina_cost = float(row.stamina_cost)
	tool_id = row.tool
	respawn = 0.0 if row.respawn is String else float(row.respawn)
	_drops = DataLoader.parse_amounts(row.drops)
	_per_hit = row.drop_mode == "per_hit"


func is_depleted() -> bool:
	return hits_left <= 0


## True if [param inventory] holds the tool this node needs.
func can_work(inventory: Inventory) -> bool:
	return tool_id in NO_TOOL or inventory.count(tool_id) > 0


## One hit. Returns the loot it drops as {item_id: count}.
## A bush gives its loot in parts on every hit, a tree everything on the last one.
func hit() -> Dictionary:
	if is_depleted():
		return {}
	var index := hits - hits_left
	hits_left -= 1
	if not _per_hit:
		return _drops.duplicate() if is_depleted() else {}
	var loot := {}
	for item_id: String in _drops:
		var count := share(_drops[item_id], hits, index)
		if count > 0:
			loot[item_id] = count
	return loot


## Part of [param total] for hit number [param index] (from 0) when the total
## is spread over [param hit_count] hits. The parts always add up to the total.
static func share(total: int, hit_count: int, index: int) -> int:
	return floori(total * (index + 1.0) / hit_count) - floori(total * float(index) / hit_count)
