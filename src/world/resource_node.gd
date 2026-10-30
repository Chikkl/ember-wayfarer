class_name ResourceNode
extends StaticBody2D
## A resource node in the world: a stick or a stone on the ground, a bush, a tree, a stump.
## Collision only at the base, so the player can stand behind a crown thanks to Y-sorting.
## Rules: docs/systems/gathering.md. Values: data/resource_nodes.csv.
## Placeholder graphics until the art pass.

const GROUP := "resource_nodes"
## Nodes that lie flat: the player walks over them, their loot goes straight to the player.
const FLAT_NODES: Array[String] = ["ground_stick", "ground_stone"]
## Loot of other nodes lands this many tiles away, from x to y.
const DROP_DISTANCE_TILES := Vector2(0.4, 1.0)
const SHAKE_TIME := 0.18
const SHAKE_PX := 2.5
## The bar of hits left stays this long after a hit.
const BAR_TIME := 2.0
const BAR_SIZE := Vector2(24, 4)
## Height of the bar above the node base for each node.
const BAR_HEIGHT_PX := {"bush": 30.0, "tree": 82.0, "stump": 18.0}
## A stick or a stone does not come back this close to the player or to a camp item.
const PLAYER_CLEARANCE_TILES := 1.0
const CAMP_ITEM_CLEARANCE_TILES := 1.5
## Random points tried in the zone before the comeback waits RETRY_TIME seconds.
const ZONE_TRIES := 8
const RETRY_TIME := 1.0

const SHADOW_COLOR := Color(0, 0, 0, 0.22)
const HIGHLIGHT_COLOR := Color(1, 1, 1, 0.55)
const TRUNK_COLOR := Color("6b4a2e")
const STUMP_TOP_COLOR := Color("b08a5a")
const STICK_COLOR := Color("8a6238")
const STONE_COLOR := Color("8c8a86")
const BUSH_COLOR := Color("4c8a3a")
const BAR_BACK_COLOR := Color(0.1, 0.1, 0.1, 0.6)
const BAR_COLOR := Color("f2d16b")

## Row id in data/resource_nodes.csv.
@export var node_id := "tree"

var harvest: NodeHarvest
## The player's current target: drawn with a ring at the base.
var highlighted := false:
	set(value):
		if value != highlighted:
			highlighted = value
			queue_redraw()

var _rng := RandomNumberGenerator.new()
var _shake := 0.0
var _bar := 0.0
var _crown_color := Color("3f7d3a")
var _crown_radius := 20.0
## Where a stick or a stone lay at the start: the center of its zone.
var _home := Vector2.ZERO
## Seconds until a depleted node comes back as [member _comeback_id]; 0 if it is not waiting.
var _comeback_left := 0.0
var _comeback_id := ""
var _respawn_radius_px: float

@onready var _base: CollisionShape2D = $Base


func _ready() -> void:
	add_to_group(GROUP)
	_home = global_position
	_respawn_radius_px = float(GameData.params("gathering").respawn_radius) * Units.TILE_PX
	_rng.seed = hash(global_position)
	_crown_color = _crown_color.darkened(_rng.randf_range(0.0, 0.2))
	_crown_radius = _rng.randf_range(17.0, 23.0)
	_become(node_id)
	set_process(false)


## The player can start work on the node: it still has hits left.
func is_workable() -> bool:
	return not harvest.is_depleted()


## One hit by the player with a tool of [param power]: the node shakes and drops
## its loot for this hit.
func hit(power := 1.0) -> void:
	var loot := harvest.hit(power)
	_bar = BAR_TIME
	_start_shake()
	for item_id: String in loot:
		for i in loot[item_id]:
			_drop(item_id)
	if harvest.is_depleted():
		_deplete()


## Seconds until the node comes back, 0 if it is not waiting.
func comeback_left() -> float:
	return _comeback_left


## Rules: docs/systems/gathering.md, "Восстановление". A felled tree leaves a stump
## that grows back into a tree, a bush stays bare until it regrows, a stick or a stone
## disappears and comes back elsewhere in its zone. An uprooted stump is gone for good.
func _deplete() -> void:
	var respawn := harvest.respawn
	match node_id:
		"tree":
			_become("stump")
			_bar = 0.0
			_wait_comeback(respawn, "tree")
		"bush":
			_wait_comeback(respawn, "bush")
		_:
			if respawn <= 0.0:
				queue_free()
				return
			visible = false
			_wait_comeback(respawn, node_id)


func _wait_comeback(seconds: float, id: String) -> void:
	_comeback_left = seconds
	_comeback_id = id
	set_process(true)


func _come_back() -> void:
	if node_id in FLAT_NODES:
		var point := _zone_point()
		if point == Vector2.INF:
			_comeback_left = RETRY_TIME
			return
		global_position = point
		visible = true
	_become(_comeback_id)


## A random free point of the zone, or Vector2.INF if none was found.
func _zone_point() -> Vector2:
	for i in ZONE_TRIES:
		var angle := _rng.randf() * TAU
		var distance := sqrt(_rng.randf()) * _respawn_radius_px
		var point := _home + Vector2(cos(angle), sin(angle)) * distance
		if _is_free(point):
			return point
	return Vector2.INF


func _is_free(point: Vector2) -> bool:
	var player: Node2D = get_tree().get_first_node_in_group(Player.GROUP)
	var player_clearance := PLAYER_CLEARANCE_TILES * Units.TILE_PX
	if player != null and player.global_position.distance_to(point) < player_clearance:
		return false
	for item: ComfortItem in get_tree().get_nodes_in_group(ComfortItem.GROUP):
		if item.global_position.distance_to(point) < CAMP_ITEM_CLEARANCE_TILES * Units.TILE_PX:
			return false
	return true


## A push without the needed tool: the node only shakes.
func push() -> void:
	_start_shake()


func _become(id: String) -> void:
	node_id = id
	harvest = NodeHarvest.new(GameData.table("resource_nodes")[id])
	_base.set_deferred("disabled", id in FLAT_NODES)
	queue_redraw()


func _drop(item_id: String) -> void:
	var item := GroundItem.new()
	item.item_id = item_id
	item.position = position
	item.land_at = position
	if node_id not in FLAT_NODES:
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(DROP_DISTANCE_TILES.x, DROP_DISTANCE_TILES.y)
		item.land_at += Vector2(cos(angle), sin(angle) * 0.6) * distance * Units.TILE_PX
	get_parent().add_child(item)


func _start_shake() -> void:
	_shake = SHAKE_TIME
	set_process(true)


func _process(delta: float) -> void:
	if _shake > 0.0 or _bar > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		_bar = maxf(_bar - delta, 0.0)
		queue_redraw()
	if _comeback_left > 0.0:
		_comeback_left -= delta
		if _comeback_left <= 0.0:
			_comeback_left = 0.0
			_come_back()
	if _shake == 0.0 and _bar == 0.0 and _comeback_left == 0.0:
		set_process(false)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	if node_id not in FLAT_NODES:
		draw_circle(Vector2.ZERO, 14.0, SHADOW_COLOR)
	if highlighted:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, HIGHLIGHT_COLOR, 2.0, true)
	var offset := Vector2(sin(_shake * 70.0) * SHAKE_PX * _shake / SHAKE_TIME, 0)
	draw_set_transform(offset)
	match node_id:
		"ground_stick":
			draw_line(Vector2(-7, -1), Vector2(7, 1), STICK_COLOR, 2.5)
			draw_line(Vector2(2, 0), Vector2(5, -4), STICK_COLOR, 1.5)
		"ground_stone":
			draw_set_transform(offset + Vector2(0, -2), 0.0, Vector2(1.0, 0.7))
			draw_circle(Vector2.ZERO, 5.0, STONE_COLOR)
			draw_circle(Vector2(-1.5, -1.5), 2.0, STONE_COLOR.lightened(0.25))
		"bush":
			_draw_bush()
		"tree":
			draw_rect(Rect2(-4, -26, 8, 26), TRUNK_COLOR)
			var crown := Vector2(0, -26 - _crown_radius * 0.8)
			draw_circle(crown, _crown_radius, _crown_color)
			draw_circle(crown + Vector2(-6, -6), _crown_radius * 0.45, _crown_color.lightened(0.12))
		"stump":
			draw_rect(Rect2(-6, -8, 12, 8), TRUNK_COLOR)
			draw_set_transform(offset + Vector2(0, -8), 0.0, Vector2(1.0, 0.4))
			draw_circle(Vector2.ZERO, 6.0, STUMP_TOP_COLOR)
	draw_set_transform(Vector2.ZERO)
	if _bar > 0.0 and BAR_HEIGHT_PX.has(node_id):
		_draw_bar(BAR_HEIGHT_PX[node_id])


## A full bush is three round leafy blobs; they shrink with every hit, a bare bush is twigs.
func _draw_bush() -> void:
	for twig in [Vector2(-7, -14), Vector2(0, -18), Vector2(7, -14)]:
		draw_line(Vector2(0, -2), twig, TRUNK_COLOR, 1.5)
	if harvest.is_depleted():
		return
	var fullness := float(harvest.hits_left) / harvest.hits
	var radius := lerpf(5.0, 10.0, fullness)
	draw_circle(Vector2(-6, -10), radius, BUSH_COLOR.darkened(0.1))
	draw_circle(Vector2(6, -10), radius, BUSH_COLOR.darkened(0.1))
	draw_circle(Vector2(0, -15), radius, BUSH_COLOR)


func _draw_bar(height: float) -> void:
	var rect := Rect2(Vector2(-BAR_SIZE.x / 2.0, -height), BAR_SIZE)
	draw_rect(rect.grow(1.0), BAR_BACK_COLOR)
	var left := float(harvest.hits_left) / harvest.hits
	draw_rect(Rect2(rect.position, Vector2(BAR_SIZE.x * left, BAR_SIZE.y)), BAR_COLOR)
