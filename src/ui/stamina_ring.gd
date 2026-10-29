extends Node2D
## Stamina ring next to the player. The dark sector is the part of the maximum
## lost to fatigue. Feedback rules: docs/systems/movement-stamina.md.

const RADIUS := 8.0
const WIDTH := 4.0
const POINTS := 48
const START := -PI / 2.0
const TRACK_COLOR := Color(0.1, 0.1, 0.1, 0.55)
const FATIGUE_COLOR := Color(0.25, 0.08, 0.05, 0.9)
const VALUE_COLOR := Color("8fd14f")
const EXHAUSTED_COLOR := Color("e04a3a")
## The ring flashes red briefly when exhaustion starts.
const FLASH_TIME := 0.4

var stamina: Stamina

var _was_exhausted := false
var _flash := 0.0


func _process(delta: float) -> void:
	if stamina != null:
		if stamina.is_exhausted() and not _was_exhausted:
			_flash = FLASH_TIME
		_was_exhausted = stamina.is_exhausted()
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if stamina == null:
		return
	var full := stamina.base_max()
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, POINTS, TRACK_COLOR, WIDTH + 2.0, true)
	var available_end := _angle(stamina.available_max() / full)
	if available_end < START + TAU:
		draw_arc(
			Vector2.ZERO, RADIUS, available_end, START + TAU, POINTS, FATIGUE_COLOR, WIDTH, true
		)
	if stamina.value > 0.0:
		draw_arc(
			Vector2.ZERO,
			RADIUS,
			START,
			_angle(stamina.value / full),
			POINTS,
			VALUE_COLOR,
			WIDTH,
			true
		)
	if _flash > 0.0:
		var color := EXHAUSTED_COLOR
		color.a = _flash / FLASH_TIME
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, POINTS, color, WIDTH + 2.0, true)


func _angle(fraction: float) -> float:
	return START + TAU * clampf(fraction, 0.0, 1.0)
