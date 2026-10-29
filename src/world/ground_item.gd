class_name GroundItem
extends Node2D
## A pile of loot on the ground: one item from a node or a stack the player dropped.
## It hops out, lands and is pulled to the player within pickup_radius if the player
## can carry it. Rules: docs/systems/gathering.md, "Добыча" and "Инвентарь".
## Placeholder graphics until the art pass.

const GROUP := "ground_items"
const HOP_TIME := 0.35
const HOP_HEIGHT_PX := 14.0
## Pull speed in tiles per second: slow at the edge of the radius, fast near the player.
const PULL_SPEED_TILES := Vector2(3.0, 12.0)
## The pile is picked up once it is this close to the player's feet.
const PICKUP_DISTANCE_PX := 6.0
## Blinks per second of loot the player cannot carry.
const BLINK_RATE := 3.0
const SHADOW_COLOR := Color(0, 0, 0, 0.2)

## Row id in data/items.csv.
var item_id := ""
var count := 1
## Where the pile lands after the hop.
var land_at := Vector2.ZERO
## A dropped pile waits until the player walks out of pickup_radius,
## otherwise it would fly straight back.
var wait_for_player_to_leave := false

var _from := Vector2.ZERO
var _hop_time := 0.0
var _height := 0.0
var _blink := 0.0
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
		wait_for_player_to_leave = false
		_set_blink(0.0)
		return
	if wait_for_player_to_leave:
		return
	var amount := _player.inventory.carry_amount(item_id, count)
	if amount == 0:
		_set_blink(_blink + delta)
		return
	_set_blink(0.0)
	if distance > PICKUP_DISTANCE_PX:
		var pull := lerpf(PULL_SPEED_TILES.y, PULL_SPEED_TILES.x, distance / _pickup_radius_px)
		global_position = global_position.move_toward(
			_player.global_position, pull * Units.TILE_PX * delta
		)
		return
	_player.pick_up(item_id, amount)
	count -= amount
	queue_redraw()
	if count <= 0:
		set_process(false)
		queue_free()


func _set_blink(time: float) -> void:
	_blink = time
	modulate.a = 1.0 if time == 0.0 else 0.55 + 0.45 * cos(time * TAU * BLINK_RATE)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 5.0, SHADOW_COLOR)
	ItemIcon.draw(self, item_id, Vector2(0, -_height))
	if count > 1:
		var font := ThemeDB.fallback_font
		draw_string_outline(
			font, Vector2(4, -6), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color.BLACK
		)
		draw_string(font, Vector2(4, -6), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
