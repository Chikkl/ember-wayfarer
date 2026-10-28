extends ComfortItem
## The starting campfire: a comfort item that creates the camp.
## Placeholder graphics until the art pass.

const STONE_COLOR := Color("7a7268")
const LOG_COLOR := Color("6b4a2e")
const FLAME_COLORS: Array[Color] = [Color("e8562a"), Color("f59a2c"), Color("ffd25e")]
const GLOW_COLOR := Color(1.0, 0.6, 0.2, 0.12)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	draw_circle(Vector2(0, -6), 34.0 + sin(t * 3.0) * 2.0, GLOW_COLOR)
	for i in 7:
		var angle := TAU * i / 7.0
		draw_circle(Vector2(cos(angle) * 12.0, sin(angle) * 5.0), 3.5, STONE_COLOR)
	draw_line(Vector2(-9, -2), Vector2(9, -4), LOG_COLOR, 4.0)
	draw_line(Vector2(-8, -5), Vector2(8, -1), LOG_COLOR, 4.0)
	for i in FLAME_COLORS.size():
		var height := 22.0 - i * 6.0 + sin(t * 9.0 + i) * 2.5
		var half_width := 8.0 - i * 2.2
		var flame := PackedVector2Array(
			[Vector2(-half_width, -4), Vector2(0, -4 - height), Vector2(half_width, -4)]
		)
		draw_colored_polygon(flame, FLAME_COLORS[i])
