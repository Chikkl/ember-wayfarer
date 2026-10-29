extends GutTest
## The tile grid on the placeholder ground.

const GROUND := preload("res://src/world/ground.gd")


func test_grid_lines_lie_on_tile_edges() -> void:
	var points := GROUND.grid_lines(2, 32.0)
	assert_eq(points.size(), 12, "3 vertical and 3 horizontal lines for a 2×2 field")
	var vertical_x: Array[float] = []
	for i in range(0, points.size(), 4):
		vertical_x.append(points[i].x)
	assert_eq(vertical_x, [-32.0, 0.0, 32.0])
	assert_eq([points[0], points[1]], [Vector2(-32, -32), Vector2(-32, 32)])
