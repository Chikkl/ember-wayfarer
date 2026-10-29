extends Node2D
## Placeholder ground: a grass field with a few darker patches.

const SIZE_TILES := 120
const GRASS_COLOR := Color("6f9e4f")
const PATCH_COLOR := Color("638f46")
const PATCH_COUNT := 140


func _draw() -> void:
	var half := SIZE_TILES * Units.TILE_PX / 2.0
	draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), GRASS_COLOR)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in PATCH_COUNT:
		var center := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		draw_set_transform(center, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, rng.randf_range(20.0, 70.0), PATCH_COLOR)
	draw_set_transform(Vector2.ZERO)
