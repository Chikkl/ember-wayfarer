class_name CampComfort
extends RefCounted
## Comfort formulas. Rules: docs/systems/comfort.md.


## Camp comfort: the best item of each comfort group, summed.
## [param item_ids] are comfort items inside the camp zone,
## [param item_table] is data/comfort_items.csv indexed by id.
static func compute(item_ids: Array[String], item_table: Dictionary) -> int:
	var total := 0
	for best_id: String in best_by_group(item_ids, item_table).values():
		total += int(item_table[best_id].comfort)
	return total


## The item with the highest comfort in each group, {group: item_id}.
static func best_by_group(item_ids: Array[String], item_table: Dictionary) -> Dictionary:
	var best := {}
	for id in item_ids:
		if not item_table.has(id):
			push_warning("Unknown comfort item: %s" % id)
			continue
		var row: Dictionary = item_table[id]
		var group: String = row.group
		if group not in best or int(row.comfort) > int(item_table[best[group]].comfort):
			best[group] = id
	return best


## Fatigue removed per second while resting at [param comfort].
## [param params] is data/comfort.json.
static func rest_rate(comfort: int, params: Dictionary) -> float:
	return float(params.rest_fatigue_base) + comfort * float(params.rest_per_comfort)


## Stamina regen multiplier while resting at [param comfort].
## [param params] is data/comfort.json.
static func rest_regen_mult(comfort: int, params: Dictionary) -> float:
	return 1.0 + comfort * float(params.rest_regen_per_comfort)
