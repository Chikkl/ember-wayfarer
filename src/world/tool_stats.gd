class_name ToolStats
extends RefCounted
## How a tool strikes: power, rhythm and stamina cost. Hands and pickup strike
## with power 1 at the hands rhythm.
## Rules: docs/systems/gathering.md, "Инструменты". Values: data/tools.csv.

var id: String
## Share of a node's hits one strike takes; the node's main tool has 1.
var power := 1.0
## Seconds between strikes while the button is held.
var hit_interval: float
## Multiplier to the node's stamina_cost for one strike.
var stamina_mult := 1.0


func _init(tool_id: String, tools: Dictionary, hands_interval: float) -> void:
	id = tool_id
	hit_interval = hands_interval
	if tool_id in tools:
		var row: Dictionary = tools[tool_id]
		power = float(row.power)
		hit_interval = float(row.hit_interval)
		stamina_mult = float(row.stamina_mult)
