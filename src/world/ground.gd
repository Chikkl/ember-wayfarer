extends Node2D
## Placeholder ground: a grass field with a few darker patches and a faint tile grid,
## so a tile from the specs is something the player sees.

const SIZE_TILES := 120
const GRASS_COLOR := Color("6f9e4f")
const PATCH_COLOR := Color("638f46")
const PATCH_COUNT := 140
const GRID_COLOR := Color(0.2, 0.3, 0.12, 0.12)


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
	draw_multiline(grid_lines(SIZE_TILES, Units.TILE_PX), GRID_COLOR)


## Pairs of points for the lines between tiles of a [param size_tiles] square field
## centered on the origin: tile edges lie on multiples of [param tile_px].
static func grid_lines(size_tiles: int, tile_px: float) -> PackedVector2Array:
	var half := size_tiles * tile_px / 2.0
	var points := PackedVector2Array()
	for i in size_tiles + 1:
		var offset := -half + i * tile_px
		points.append_array([Vector2(offset, -half), Vector2(offset, half)])
		points.append_array([Vector2(-half, offset), Vector2(half, offset)])
	return points
