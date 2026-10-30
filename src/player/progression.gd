class_name Progression
extends RefCounted
## Experience, level and development points. Experience comes for results:
## dropped resources and crafted items, never for a single strike.
## Rules: docs/systems/tech-tree.md, "Опыт и уровень". Values: data/progression.json.

signal leveled_up(level: int)

var level := 1
## Experience gathered towards the next level.
var xp := 0
## Unspent development points.
var points := 0

var _base: float
var _growth: float
var _points_per_level: int


func _init(params: Dictionary) -> void:
	_base = float(params.xp_base)
	_growth = float(params.xp_growth)
	_points_per_level = int(params.points_per_level)


## Experience for [param loot] ({item_id: count}) by the xp column of [param items].
static func loot_xp(loot: Dictionary, items: Dictionary) -> int:
	var total := 0
	for item_id: String in loot:
		total += int(items[item_id].xp) * int(loot[item_id])
	return total


## Experience needed to go from [param from_level] to the next level.
func threshold(from_level: int) -> int:
	return roundi(_base * pow(_growth, from_level - 1))


## Adds experience. Extra experience carries over to the next level,
## every new level gives its points, several levels at once go one by one.
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= threshold(level):
		xp -= threshold(level)
		level += 1
		points += _points_per_level
		leveled_up.emit(level)
