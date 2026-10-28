class_name Stamina
extends RefCounted
## Stamina, fatigue and exhaustion of the player.
## Rules: docs/systems/movement-stamina.md. Values: data/player.json.

## Current stamina.
var value: float
## Slow debt that lowers the available maximum.
var fatigue := 0.0
## Seconds of exhaustion left; work is blocked while it is above zero.
var exhaust_time_left := 0.0

var _max: float
var _regen: float
var _regen_delay: float
var _fatigue_rate: float
var _fatigue_floor: float
var _exhaust_duration: float
var _exhaust_speed_mult: float
var _since_spend: float


func _init(params: Dictionary) -> void:
	_max = float(params.stamina_max)
	_regen = float(params.stamina_regen)
	_regen_delay = float(params.stamina_regen_delay)
	_fatigue_rate = float(params.fatigue_rate)
	_fatigue_floor = float(params.fatigue_floor)
	_exhaust_duration = float(params.exhaust_duration)
	_exhaust_speed_mult = float(params.exhaust_speed_mult)
	if _fatigue_floor > _max:
		push_error("fatigue_floor %s is above stamina_max %s" % [_fatigue_floor, _max])
		_fatigue_floor = _max
	value = _max
	_since_spend = _regen_delay


## Base maximum without fatigue.
func base_max() -> float:
	return _max


## Maximum the bar can refill to: the base maximum minus fatigue, not below the floor.
func available_max() -> float:
	return maxf(_max - fatigue, _fatigue_floor)


## Fatigue stops growing once the available maximum reaches the floor.
func max_fatigue() -> float:
	return _max - _fatigue_floor


func is_exhausted() -> bool:
	return exhaust_time_left > 0.0


## Work can start with any non-zero stamina, even if it costs more.
func can_work() -> bool:
	return value > 0.0 and not is_exhausted()


## Spends stamina on one work action. Returns false if work is not possible.
## A cost above the remaining stamina empties the bar and starts exhaustion.
## A free action (cost 0, like a pickup) always succeeds and changes nothing.
func spend(cost: float) -> bool:
	if cost <= 0.0:
		return true
	if not can_work():
		return false
	var spent := minf(cost, value)
	value -= spent
	fatigue = minf(fatigue + spent * _fatigue_rate, max_fatigue())
	value = minf(value, available_max())
	_since_spend = 0.0
	if value <= 0.0:
		value = 0.0
		exhaust_time_left = _exhaust_duration
	return true


## Advances time. [param rest_rate] is fatigue removed per second while resting,
## zero when the player is not resting. [param regen_mult] scales stamina regen,
## comfort raises it while resting.
func update(delta: float, rest_rate := 0.0, regen_mult := 1.0) -> void:
	if exhaust_time_left > 0.0:
		exhaust_time_left = maxf(exhaust_time_left - delta, 0.0)
		# If regen_delay is tuned longer than exhaustion, regen starts as soon as
		# exhaustion ends, so the player never stands at zero without being exhausted.
		if exhaust_time_left == 0.0 and value <= 0.0:
			_since_spend = maxf(_since_spend, _regen_delay)
	_since_spend += delta
	if rest_rate > 0.0:
		fatigue = maxf(fatigue - rest_rate * delta, 0.0)
	var regen_time := minf(delta, _since_spend - _regen_delay)
	if regen_time > 0.0:
		value = minf(value + _regen * regen_mult * regen_time, available_max())


## Walking speed multiplier from exhaustion.
func speed_mult() -> float:
	return _exhaust_speed_mult if is_exhausted() else 1.0
