class_name ItemIcon
extends RefCounted
## Placeholder item pictures, shared by loot on the ground and inventory slots.
## Drawn around a point at the bottom center of the item.

const COLORS := {
	"stick": Color("8a6238"),
	"stone": Color("8c8a86"),
	"leaves": Color("5b9a3c"),
	"log": Color("6b4a2e"),
	"stone_axe": Color("8c8a86"),
	"chopper": Color("77746f"),
	"shaped_stick": Color("b08a5a"),
	"plait": Color("7f9a45"),
}
const HANDLE_COLOR := Color("8a6238")


## Draws [param item_id] on [param canvas] at [param at], [param scale] times the ground size.
static func draw(canvas: CanvasItem, item_id: String, at: Vector2, scale := 1.0) -> void:
	canvas.draw_set_transform(at, 0.0, Vector2(scale, scale))
	var color: Color = COLORS.get(item_id, Color.MAGENTA)
	match item_id:
		"stick":
			canvas.draw_line(Vector2(-5, -2), Vector2(5, -4), color, 2.5)
		"stone":
			canvas.draw_circle(Vector2(0, -3), 3.5, color)
		"leaves":
			canvas.draw_circle(Vector2(-2, -3), 3.0, color)
			canvas.draw_circle(Vector2(2, -4), 3.0, color.lightened(0.15))
		"log":
			canvas.draw_rect(Rect2(-8, -7, 16, 6), color)
			canvas.draw_circle(Vector2(8, -4), 3.0, color.lightened(0.3))
		"stone_axe":
			canvas.draw_line(Vector2(-4, -1), Vector2(3, -11), HANDLE_COLOR, 2.0)
			canvas.draw_rect(Rect2(1, -13, 6, 4), color)
		"chopper":
			var flake := PackedVector2Array(
				[Vector2(-4, -1), Vector2(-2, -8), Vector2(4, -6), Vector2(3, -1)]
			)
			canvas.draw_colored_polygon(flake, color)
		"shaped_stick":
			canvas.draw_line(Vector2(-6, -3), Vector2(5, -3), color, 2.5)
			canvas.draw_line(Vector2(5, -3), Vector2(7, -3), color.darkened(0.3), 1.5)
		"plait":
			var braid := PackedVector2Array(
				[Vector2(-6, -3), Vector2(-3, -6), Vector2(0, -3), Vector2(3, -6), Vector2(6, -3)]
			)
			canvas.draw_polyline(braid, color, 2.0)
		_:
			canvas.draw_circle(Vector2(0, -3), 3.0, color)
	canvas.draw_set_transform(Vector2.ZERO)
