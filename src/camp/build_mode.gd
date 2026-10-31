class_name BuildMode
extends Node2D
## Build mode: a preview of the chosen building follows the cursor, snapped to
## tiles; a left click puts a blueprint there, a right click leaves the mode.
## The cursor comes from mouse events, so capture mode can place buildings too.
## Rules: docs/systems/crafting.md, "Постройки". Values: data/crafting.json.

signal placed(building: Building)

const VALID_COLOR := Color(0.55, 0.95, 0.45, 0.35)
const INVALID_COLOR := Color(1.0, 0.35, 0.3, 0.35)
const CAMP_BORDER_COLOR := Color(1.0, 0.7, 0.35, 0.6)

var active := false
## The building to place.
var recipe_id := ""

var _player: Player
var _campfire: Node2D
var _cursor_screen := Vector2.ZERO
var _valid := false
var _build_radius_px: float
var _camp_radius_px: float


func setup(player: Player, campfire: Node2D) -> void:
	_player = player
	_campfire = campfire
	_build_radius_px = float(GameData.params("crafting").build_radius) * Units.TILE_PX
	_camp_radius_px = float(GameData.params("comfort").camp_radius) * Units.TILE_PX
	z_index = 20


func start(building_id: String) -> void:
	recipe_id = building_id
	active = true
	queue_redraw()


func stop() -> void:
	active = false
	recipe_id = ""
	queue_redraw()


## The ground the preview takes, in world coordinates, snapped to tiles.
func preview_rect() -> Rect2:
	var cursor := get_viewport().get_canvas_transform().affine_inverse() * _cursor_screen
	var size: Dictionary = GameData.table("buildings")[recipe_id]
	var size_px := Vector2(int(size.width), int(size.height)) * Units.TILE_PX
	var top_left := ((cursor - size_px / 2.0) / Units.TILE_PX).round() * Units.TILE_PX
	return Rect2(top_left, size_px)


## Whether a blueprint fits at [param rect]: close enough to the player and
## clear of trees, stumps, bushes, buildings, the fire and the player.
## Sticks and stones on the ground have no bodies and do not get in the way.
func can_place(rect: Rect2) -> bool:
	if rect.get_center().distance_to(_player.global_position) > _build_radius_px:
		return false
	var shape := RectangleShape2D.new()
	shape.size = rect.size - Vector2(2, 2)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, rect.get_center())
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Puts a blueprint at the preview and leaves the mode. Null if it does not fit.
func place() -> Building:
	var rect := preview_rect()
	if not can_place(rect):
		return null
	var building := Building.blueprint(recipe_id, Vector2(rect.get_center().x, rect.end.y))
	get_parent().add_child(building)
	stop()
	placed.emit(building)
	return building


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		_cursor_screen = event.position
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	_cursor_screen = click.position
	if click.button_index == MOUSE_BUTTON_LEFT:
		place()
		get_viewport().set_input_as_handled()
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		stop()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if active:
		_valid = can_place(preview_rect())
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	draw_arc(_campfire.global_position, _camp_radius_px, 0.0, TAU, 96, CAMP_BORDER_COLOR, 2.0, true)
	var rect := preview_rect()
	draw_rect(rect, VALID_COLOR if _valid else INVALID_COLOR)
	draw_rect(rect, Color(1, 1, 1, 0.6), false, 1.5)
