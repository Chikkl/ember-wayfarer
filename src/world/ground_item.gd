class_name GroundItem
extends Node2D
## Loot on the ground. It hops out of the node, lands and is pulled
## to the player within pickup_radius. Rules: docs/systems/gathering.md, "Добыча".
## Placeholder graphics until the art pass.

const GROUP := "ground_items"
const HOP_TIME := 0.35
const HOP_HEIGHT_PX := 14.0
## Pull speed in tiles per second: slow at the edge of the radius, fast near the player.
const PULL_SPEED_TILES := Vector2(3.0, 12.0)
## The item is picked up once it is this close to the player's feet.
const PICKUP_DISTANCE_PX := 6.0
const SHADOW_COLOR := Color(0, 0, 0, 0.2)
const COLORS := {
	"stick": Color("8a6238"),
	"stone": Color("8c8a86"),
	"leaves": Color("5b9a3c"),
	"log": Color("6b4a2e"),
}

## Row id in data/items.csv.
var item_id := ""
## Where the item lands after the hop out of the node.
var land_at := Vector2.ZERO

var _from := Vector2.ZERO
var _hop_time := 0.0
var _height := 0.0
var _pickup_radius_px: float
var _player: Player


func _ready() -> void:
	add_to_group(GROUP)
	_from = position
	_pickup_radius_px = float(GameData.params("gathering").pickup_radius) * Units.TILE_PX
	_player = get_tree().get_first_node_in_group(Player.GROUP)


func is_landed() -> bool:
	return _hop_time >= HOP_TIME


func _process(delta: float) -> void:
	if not is_landed():
		_hop_time = minf(_hop_time + delta, HOP_TIME)
		var t := _hop_time / HOP_TIME
		position = _from.lerp(land_at, t)
		_height = sin(t * PI) * HOP_HEIGHT_PX
		queue_redraw()
		return
	if _player == null:
		return
	var distance := global_position.distance_to(_player.global_position)
	if distance > _pickup_radius_px:
		return
	if distance <= PICKUP_DISTANCE_PX:
		_player.pick_up(item_id)
		set_process(false)
		queue_free()
		return
	var pull := lerpf(PULL_SPEED_TILES.y, PULL_SPEED_TILES.x, distance / _pickup_radius_px)
	global_position = global_position.move_toward(
		_player.global_position, pull * Units.TILE_PX * delta
	)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 5.0, SHADOW_COLOR)
	draw_set_transform(Vector2(0, -_height))
	var color: Color = COLORS.get(item_id, Color.MAGENTA)
	match item_id:
		"stick":
			draw_line(Vector2(-5, -2), Vector2(5, -4), color, 2.5)
		"stone":
			draw_circle(Vector2(0, -3), 3.5, color)
		"leaves":
			draw_circle(Vector2(-2, -3), 3.0, color)
			draw_circle(Vector2(2, -4), 3.0, color.lightened(0.15))
		"log":
			draw_rect(Rect2(-8, -7, 16, 6), color)
			draw_circle(Vector2(8, -4), 3.0, color.lightened(0.3))
		_:
			draw_circle(Vector2(0, -3), 3.0, color)
