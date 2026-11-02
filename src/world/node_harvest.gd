class_name NodeHarvest
extends RefCounted
## Hits and loot of one resource node: a stick on the ground, a bush, a tree.
## Rules: docs/systems/gathering.md, "Действия" and "Инструменты".
## Values: data/resource_nodes.csv.

## Tools every player has from the start.
const NO_TOOL: Array[String] = ["pickup", "hands"]
## Durability left below this counts as zero: strikes of 0.4 do not add up to 6 exactly.
const EPSILON := 0.0001

var node_id: String
## Durability in strikes of the main tool.
var hits: int
var hits_left: float
var stamina_cost: float
## Item id of the main tool, or one of [constant NO_TOOL].
var tool_id: String
## Other tools that work this node, usually weaker ones.
var alt_tool_ids: Array[String] = []
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
	alt_tool_ids.assign(str(row.get("alt_tools", "")).split(";", false))
	respawn = 0.0 if row.respawn is String else float(row.respawn)
	_drops = DataLoader.parse_amounts(row.drops)
	_per_hit = row.drop_mode == "per_hit"


func is_depleted() -> bool:
	return hits_left <= EPSILON


## The tool to work this node with: the strongest fitting one in [param inventory],
## the no-tool id for hands and pickup, or "" if nothing fits.
## [param tools] are the rows of data/tools.csv.
func best_tool(inventory: Inventory, tools: Dictionary) -> String:
	if tool_id in NO_TOOL:
		return tool_id
	var best := ""
	var best_power := 0.0
	for id: String in [tool_id] + alt_tool_ids:
		var power := float(tools[id].power)
		if inventory.count(id) > 0 and power > best_power:
			best = id
			best_power = power
	return best


## One strike of [param power]. Returns the loot it drops as {item_id: count}.
## A bush gives its loot in parts as its durability goes down, a tree everything
## on the last strike.
func hit(power := 1.0) -> Dictionary:
	if is_depleted():
		return {}
	var done_before := hits - hits_left
	hits_left -= power
	if hits_left <= EPSILON:
		hits_left = 0.0
	if not _per_hit:
		return _drops.duplicate() if is_depleted() else {}
	var done := hits - hits_left
	var loot := {}
	for item_id: String in _drops:
		var count := share(_drops[item_id], hits, done_before, done)
		if count > 0:
			loot[item_id] = count
	return loot


## Part of [param total] for the durability from [param done_before] to
## [param done_after], when the total is spread over [param hit_count] hits.
## The parts always add up to the total.
static func share(total: int, hit_count: int, done_before: float, done_after: float) -> int:
	var after := floori(total * done_after / hit_count + EPSILON)
	return after - floori(total * done_before / hit_count + EPSILON)
