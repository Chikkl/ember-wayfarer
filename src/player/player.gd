class_name Player
extends CharacterBody2D
## The player: walking, stamina and rest.
## Rules: docs/systems/movement-stamina.md. Values: data/player.json.

enum Facing { DOWN, UP, LEFT, RIGHT }

## sin(22.5°): input closer than this to vertical counts as straight up or down,
## anything else, diagonals included, faces left or right.
const SIDE_FACING_MIN_X := 0.3827
const BODY_COLOR := Color("4f7cac")
const SKIN_COLOR := Color("f0c9a0")
const SHADOW_COLOR := Color(0, 0, 0, 0.25)
const HIT_FLASH_TIME := 0.12

var stamina: Stamina
var is_resting := false
var facing := Facing.DOWN

var _move_speed_px: float
var _accel_time: float
var _rest_params: Dictionary
var _work: WorkRhythm
var _debug_work_cost: float
var _hit_flash := 0.0


func _ready() -> void:
	var params := GameData.params("player")
	stamina = Stamina.new(params)
	_move_speed_px = float(params.move_speed) * Units.TILE_PX
	_accel_time = maxf(float(params.move_accel_time), 0.001)
	_rest_params = GameData.params("comfort")
	_work = WorkRhythm.new(float(GameData.params("gathering").hit_interval))
	_debug_work_cost = float(GameData.table("resource_nodes").tree.stamina_cost)
	motion_mode = MOTION_MODE_FLOATING
	$StaminaRing.stamina = stamina


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_resting = next_resting(is_resting, input, Input.is_action_just_pressed("rest"))
	_move(input, delta)
	_debug_work(delta)
	var rest_rate := 0.0
	var regen_mult := 1.0
	if is_resting:
		var comfort := current_comfort()
		rest_rate = CampComfort.rest_rate(comfort, _rest_params)
		regen_mult = CampComfort.rest_regen_mult(comfort, _rest_params)
	stamina.update(delta, rest_rate, regen_mult)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	queue_redraw()


## Comfort at the player's feet: the camp they stand in, or zero outside.
func current_comfort() -> int:
	return Camp.comfort_at(get_tree(), global_position)


## Rest state after this frame: any movement stands the player up,
## the rest button toggles sitting.
static func next_resting(resting: bool, input: Vector2, rest_pressed: bool) -> bool:
	if input != Vector2.ZERO:
		return false
	if rest_pressed:
		return not resting
	return resting


## Sprite facing for the movement input: 4 sides, diagonals face left or right.
static func facing_for(input: Vector2, current: Facing) -> Facing:
	if input == Vector2.ZERO:
		return current
	var direction := input.normalized()
	if absf(direction.x) >= SIDE_FACING_MIN_X:
		return Facing.LEFT if direction.x < 0.0 else Facing.RIGHT
	return Facing.UP if direction.y < 0.0 else Facing.DOWN


func _move(input: Vector2, delta: float) -> void:
	var target := input * _move_speed_px * stamina.speed_mult()
	if is_resting:
		target = Vector2.ZERO
	var accel := _move_speed_px / _accel_time
	velocity = velocity.move_toward(target, accel * delta)
	move_and_slide()
	facing = facing_for(input, facing)


## Temporary until the gathering prototype: holding the debug key works
## "into the air" with the tree's stamina cost and the gathering hit rhythm.
func _debug_work(delta: float) -> void:
	if Input.is_action_just_pressed("debug_work") and not is_resting:
		_work.start()
	if is_resting or not Input.is_action_pressed("debug_work"):
		_work.stop()
	if _work.update(delta, stamina, _debug_work_cost):
		_hit_flash = HIT_FLASH_TIME


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 10.0, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO)

	var body_color := BODY_COLOR.lightened(0.5) if _hit_flash > 0.0 else BODY_COLOR
	var head := Vector2(0, -32)
	if is_resting:
		draw_rect(Rect2(-9, -14, 18, 12), body_color)
		head = Vector2(0, -20)
	elif stamina.is_exhausted():
		draw_rect(Rect2(-8, -22, 16, 18), body_color)
		head = Vector2(3 if facing != Facing.LEFT else -3, -26)
	else:
		draw_rect(Rect2(-8, -26, 16, 22), body_color)
	draw_circle(head, 7.0, SKIN_COLOR)
	_draw_eyes(head)


func _draw_eyes(head: Vector2) -> void:
	var eye_color := Color("2b2b2b")
	match facing:
		Facing.DOWN:
			draw_circle(head + Vector2(-2.5, 0), 1.2, eye_color)
			draw_circle(head + Vector2(2.5, 0), 1.2, eye_color)
		Facing.LEFT:
			draw_circle(head + Vector2(-3.5, 0), 1.2, eye_color)
		Facing.RIGHT:
			draw_circle(head + Vector2(3.5, 0), 1.2, eye_color)
		Facing.UP:
			pass
