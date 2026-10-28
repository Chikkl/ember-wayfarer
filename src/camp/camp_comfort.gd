class_name CampComfort
extends RefCounted
## Comfort formulas. Rules: docs/systems/comfort.md.


## Camp comfort: the best item of each comfort group, summed.
## [param item_ids] are comfort items inside the camp zone,
## [param item_table] is data/comfort_items.csv indexed by id.
static func compute(item_ids: Array[String], item_table: Dictionary) -> int:
	var best_by_group := {}
	for id in item_ids:
		if not item_table.has(id):
			push_warning("Unknown comfort item: %s" % id)
			continue
		var row: Dictionary = item_table[id]
		var group: String = row.group
		best_by_group[group] = maxi(best_by_group.get(group, 0), int(row.comfort))
	var total := 0
	for group_best: int in best_by_group.values():
		total += group_best
	return total


## Fatigue removed per second while resting at [param comfort].
## [param params] is data/comfort.json.
static func rest_rate(comfort: int, params: Dictionary) -> float:
	return float(params.rest_fatigue_base) + comfort * float(params.rest_per_comfort)
