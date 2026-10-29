extends StaticBody2D
## Placeholder tree: collision only at the base, the crown covers the player
## standing behind it thanks to Y-sorting. Gathering comes in its own prototype.

const TRUNK_COLOR := Color("6b4a2e")
const SHADOW_COLOR := Color(0, 0, 0, 0.22)

var _crown_color := Color("3f7d3a")
var _crown_radius := 20.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	_crown_color = _crown_color.darkened(rng.randf_range(0.0, 0.2))
	_crown_radius = rng.randf_range(17.0, 23.0)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 14.0, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-4, -26, 8, 26), TRUNK_COLOR)
	var crown := Vector2(0, -26 - _crown_radius * 0.8)
	draw_circle(crown, _crown_radius, _crown_color)
	draw_circle(crown + Vector2(-6, -6), _crown_radius * 0.45, _crown_color.lightened(0.12))
