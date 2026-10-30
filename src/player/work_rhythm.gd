class_name WorkRhythm
extends RefCounted
## Hold-to-work rhythm: one hit every [member interval] while the button is held.
## Work stops on release or exhaustion; to continue, the button is pressed again.
## Rules: docs/systems/gathering.md, "Действия", rule 3.

var is_working := false
## Seconds between hits: the rhythm of the tool in use.
var interval: float

var _cooldown := 0.0


func _init(hit_interval: float) -> void:
	interval = hit_interval


## Call when the button is pressed, not while it is held.
func start() -> void:
	is_working = true


func stop() -> void:
	is_working = false


## Advances time. Returns true when a hit happens; a hit spends [param cost].
## The cooldown keeps running after release, so tapping cannot beat the rhythm.
func update(delta: float, stamina: Stamina, cost: float) -> bool:
	_cooldown -= delta
	if not is_working:
		_cooldown = maxf(_cooldown, 0.0)
		return false
	if _cooldown > 0.0:
		return false
	if not stamina.spend(cost):
		is_working = false
		return false
	_cooldown += interval
	if stamina.is_exhausted():
		is_working = false
	return true
