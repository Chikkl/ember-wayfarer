class_name CaptureDirector
extends Node
## Capture mode: plays a take from CaptureTakes by pressing the same actions as
## the player, so Movie Maker records real gameplay for reels and visual reviews.
## Run: godot --path . --write-movie <file>.avi --fixed-fps 60 -- --capture=<take>
## Guide: docs/captures.md, "Режим съёмки".
##
## Steps:
## - wait: stand still for "time" seconds;
## - walk_to: walk to "target": the fire, "blueprint" for the nearest blueprint,
##   "building" for the nearest blueprint or finished building, or
##   the nearest workable node with this id; or to "at", [x, y] tiles from the fire;
## - work: hold E on the node in reach until it is used up or turns into another
##   node; with "until": "exhausted" keep chopping trees and stumps until exhaustion;
## - collect: walk over the loot around the player;
## - rest: press R once;
## - press: press "action" once, like T for the tree screen;
## - click_tree_node: click "node" on the tree screen;
## - click_recipe: click "recipe" in the open crafting menu;
## - place: point at the tile "at", [x, y] from the fire, as the top left of the building
##   chosen in build mode, show the preview there for "time" seconds, then click;
## - build: hold E at the nearest blueprint until it is built or lacks materials;
## - hover_comfort: point at the comfort badge, so its groups open;
## - drag: drag the stack in slot "index" of "from" ("inventory" or "basket") to
##   slot "to_index" of "to", or to "ground" out of the panels;
## - shift_click: Shift and the left button on slot "index" of "grid";
## - take_down: in the mode for taking down (B), hold E at the nearest building
##   until it is gone;
## - zoom: zoom the camera to "zoom" while the next steps play.

const ARG_PREFIX := "--capture="
const STEP_KINDS: Array[String] = [
	"wait",
	"walk_to",
	"work",
	"collect",
	"rest",
	"press",
	"click_tree_node",
	"click_recipe",
	"place",
	"build",
	"hover_comfort",
	"take_down",
	"drag",
	"shift_click",
	"zoom",
]
const FIRE_TARGET := "fire"
const BLUEPRINT_TARGET := "blueprint"
const BUILDING_TARGET := "building"
const UNTIL_EXHAUSTED := "exhausted"
const HELD_ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down", "interact", "rest"
]
## The spot by the fire, in tiles from it: to the right and a bit in front,
## so the stamina ring next to the player stays clear of the flames.
const FIRE_SPOT_TILES := Vector2(0.9, 0.9)
## The player works a node from its side and a bit in front of it: in reach,
## not hidden by a crown, with the tool swing in view. The side is this share
## of interact_radius away, the front offset is in pixels.
const NODE_SIDE_SHARE := 0.55
const NODE_FRONT_PX := 6.0
## A walk to a spot ends this close to it.
const ARRIVE_PX := 3.0
## Loot farther than this from the player stays on the ground, in tiles.
const COLLECT_RADIUS_TILES := 3.0
## Work until exhaustion looks this far for the next tree or stump, in tiles.
const CHOP_SEARCH_TILES := 12.0
const CHOP_IDS: Array[String] = ["tree", "stump"]
## A walk that gets no closer for this long has run into a tree or a bush base:
## the player steps aside for DETOUR_TIME, to the other side on the next try,
## and gives up after DETOUR_TRIES.
const STUCK_TIME := 0.3
const DETOUR_TIME := 0.3
const DETOUR_TRIES := 4
## The place step shows the preview this long before the click, unless the step
## says otherwise: viewers should see where the building goes.
const PLACE_AIM_TIME := 1.2
## A drag moves the cursor from slot to target over this long, then lets go.
const DRAG_TIME := 0.6
const GRIDS: Array[String] = ["inventory", "basket"]
const GROUND_TARGET := "ground"
## The build step gives up after this long at a blueprint that lacks materials.
const BUILD_GIVE_UP_TIME := 0.3
## The player stands this far in front of a blueprint to build it, in pixels.
const BLUEPRINT_FRONT_PX := 10.0
## A loot pile this close that is still on the ground cannot be carried.
const LOOT_REACHED_PX := 2.0
## A step that runs longer than this is cut short with a warning.
const STEP_TIMEOUT := 30.0
const ZOOM_TIME := 0.6

var _player: Player
var _campfire: Node2D
var _hud: Hud
var _camera: Camera2D
var _steps: Array = []
var _step: Dictionary = {}
## Seconds since the take started and since the current step started.
var _clock := 0.0
var _step_time := 0.0
var _interact_radius_px: float
## The node the step walks to or works on. An empty id means any id will do.
var _node: ResourceNode
var _node_id := ""
## The blueprint the build step works on.
var _site: Building
## Where the player stands to work [member _node].
var _work_spot := Vector2.ZERO
var _walking := false
var _loot: GroundItem
## Piles the collect step could not pick up.
var _skipped_loot: Array[GroundItem] = []
var _best_distance := INF
var _stuck_time := 0.0
var _detours := 0
var _detour_left := 0.0
var _detour_direction := Vector2.ZERO
## Where the last mouse event of the take pointed, on the screen.
var _mouse_screen := Vector2.ZERO
## The place step has clicked and waits a frame for the blueprint.
var _placed := false
## Where the drag step starts and ends on the screen, and whether it let go.
var _drag_from := Vector2.ZERO
var _drag_to := Vector2.ZERO
var _released := false


## The take name from the user arguments after "--", or "" outside capture mode.
static func take_from_args(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with(ARG_PREFIX):
			return arg.trim_prefix(ARG_PREFIX)
	return ""


## What is wrong with [param take]: unknown steps, targets, actions, tree nodes
## and items. Empty if nothing.
static func take_problems(take: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var items := GameData.table("items")
	for item_id: String in take.get("items", {}):
		if item_id not in items:
			problems.append("unknown item '%s'" % item_id)
	var nodes := GameData.table("resource_nodes")
	var tree_nodes := GameData.table("recipe_tree")
	var recipes := GameData.table("recipes")
	for step: Dictionary in take.get("steps", []):
		var kind: String = step.get("do", "")
		var target: String = step.get("target", FIRE_TARGET)
		if kind not in STEP_KINDS:
			problems.append("unknown step %s" % step)
		elif kind == "walk_to" and not step.has("at") and not _known_target(target, nodes):
			problems.append("unknown target in %s" % step)
		elif kind == "place" and not step.has("at"):
			problems.append("no 'at' in %s" % step)
		elif kind == "drag" and not _known_drag(step):
			problems.append("unknown grid in %s" % step)
		elif kind == "shift_click" and step.get("grid", "") not in GRIDS:
			problems.append("unknown grid in %s" % step)
		elif kind == "work" and step.get("until", UNTIL_EXHAUSTED) != UNTIL_EXHAUSTED:
			problems.append("unknown 'until' in %s" % step)
		elif kind == "press" and not InputMap.has_action(step.get("action", "")):
			problems.append("unknown action in %s" % step)
		elif kind == "click_tree_node" and step.get("node", "") not in tree_nodes:
			problems.append("unknown tree node in %s" % step)
		elif kind == "click_recipe" and step.get("recipe", "") not in recipes:
			problems.append("unknown recipe in %s" % step)
	return problems


static func _known_drag(step: Dictionary) -> bool:
	var to: String = step.get("to", "")
	return step.get("from", "") in GRIDS and (to in GRIDS or to == GROUND_TARGET)


static func _known_target(target: String, nodes: Dictionary) -> bool:
	return target in [FIRE_TARGET, BLUEPRINT_TARGET, BUILDING_TARGET] or target in nodes


## Strengths of the move actions that walk at full speed toward [param direction].
static func move_strengths(direction: Vector2) -> Dictionary:
	var unit := direction.normalized()
	return {
		"move_left": maxf(-unit.x, 0.0),
		"move_right": maxf(unit.x, 0.0),
		"move_up": maxf(-unit.y, 0.0),
		"move_down": maxf(unit.y, 0.0),
	}


## Gives the take's items and experience ("xp") and moves the player to its start
## before the first frame.
func setup(take: Dictionary, player: Player, campfire: Node2D, hud: Hud) -> void:
	_player = player
	_campfire = campfire
	_hud = hud
	_camera = player.get_node("Camera")
	_steps = take.steps.duplicate()
	_interact_radius_px = float(GameData.params("gathering").interact_radius) * Units.TILE_PX
	var items: Dictionary = take.get("items", {})
	for item_id: String in items:
		player.inventory.add(item_id, items[item_id])
	if take.has("start"):
		player.global_position = campfire.global_position + take.start * Units.TILE_PX
	player.progression.add_xp(int(take.get("xp", 0)))
	# The player reads the actions later in the same physics frame.
	process_physics_priority = -1


func _ready() -> void:
	_camera.force_update_scroll()
	_camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	_clock += delta
	_step_time += delta
	if not _step.is_empty() and _step_time >= STEP_TIMEOUT:
		push_warning("capture: step cut short after %.0f s: %s" % [STEP_TIMEOUT, _step])
		_end_step()
	if _step.is_empty() or _run_step(delta):
		_end_step()
		_begin_next_step()


func _begin_next_step() -> void:
	if _steps.is_empty():
		print("capture %.2f s: done" % _clock)
		set_physics_process(false)
		get_tree().quit()
		return
	_step = _steps.pop_front()
	_step_time = 0.0
	print("capture %.2f s: %s" % [_clock, _step])
	match _step.do:
		"walk_to":
			_begin_walk_to()
		"work":
			_begin_work()
		"collect":
			_loot = null
			_skipped_loot.clear()
		"rest":
			Input.action_press("rest")
		"press":
			Input.action_press(_step.action)
		"click_tree_node":
			_click(_hud.tree_screen().node_center(_step.node), true)
		"click_recipe":
			_click(_hud.craft_menu().recipe_center(_step.recipe), true)
		"place":
			_placed = false
			_move_mouse(_tile_center(_step.at, _hud.build_mode.recipe_id))
		"build":
			_site = _nearest_blueprint()
			Input.action_press("interact")
		"hover_comfort":
			_move_mouse(_hud.comfort_badge().center())
		"take_down":
			_site = _nearest_blueprint(-1.0, true)
			Input.action_press("interact")
		"drag":
			_released = false
			_drag_from = _grid(_step.from).slot_center(int(_step.index))
			_drag_to = _drag_target()
			_move_mouse(_drag_from)
			_click(_drag_from, true)
		"shift_click":
			var at := _grid(_step.grid).slot_center(int(_step.index))
			_move_mouse(at)
			_click(at, true, true)
		"zoom":
			var zoom := Vector2.ONE * float(_step.zoom)
			create_tween().tween_property(_camera, "zoom", zoom, ZOOM_TIME)


## Runs one frame of the step. True when the step is over.
func _run_step(delta: float) -> bool:
	var done := true
	match _step.do:
		"wait":
			done = _step_time >= float(_step.time)
		"walk_to":
			done = _run_walk_to(delta)
		"work":
			done = _run_work(delta)
		"collect":
			done = _run_collect(delta)
		"build":
			done = _run_build()
		"take_down":
			done = _site == null or not is_instance_valid(_site) or not _site.is_inside_tree()
		"drag":
			done = _run_drag()
		"place":
			done = _run_place()
		"rest", "press", "click_tree_node", "click_recipe", "hover_comfort", "zoom", "shift_click":
			done = true
		_:
			push_warning("capture: unknown step %s" % _step)
	return done


func _end_step() -> void:
	for action in HELD_ACTIONS:
		Input.action_release(action)
	match _step.get("do", ""):
		"press":
			Input.action_release(_step.action)
		"click_tree_node":
			_click(_hud.tree_screen().node_center(_step.node), false)
		"click_recipe":
			_click(_hud.craft_menu().recipe_center(_step.recipe), false)
		"place":
			_click(_mouse_screen, false)
		"shift_click":
			_click(_mouse_screen, false, true)
	# Only a walk hands its node over to the next step.
	if _step.get("do", "") != "walk_to":
		_node = null
	_step = {}


func _begin_walk_to() -> void:
	_node = null
	_site = null
	var target: String = _step.get("target", "")
	if target in [BLUEPRINT_TARGET, BUILDING_TARGET]:
		_site = _nearest_blueprint(INF, target == BUILDING_TARGET)
		if _site != null:
			_work_spot = _blueprint_spot(_site.footprint())
	elif _step.has("at"):
		_work_spot = _campfire.global_position + _tiles(_step.at) * Units.TILE_PX
	elif target != FIRE_TARGET:
		_node = _nearest_node([target])
		if _node != null:
			_work_spot = _work_spot_for(_node)
	_start_walk()


func _run_walk_to(delta: float) -> bool:
	if _step.get("target", "") in [BLUEPRINT_TARGET, BUILDING_TARGET]:
		if _site == null:
			push_warning("capture: no %s to walk to" % _step.target)
			return true
		return _walk_toward(_work_spot, ARRIVE_PX, delta)
	if _step.has("at"):
		return _walk_toward(_work_spot, ARRIVE_PX, delta)
	if _step.target == FIRE_TARGET:
		var spot := _campfire.global_position + FIRE_SPOT_TILES * Units.TILE_PX
		return _walk_toward(spot, ARRIVE_PX, delta)
	if not is_instance_valid(_node):
		push_warning("capture: no %s to walk to" % _step.target)
		return true
	return _walk_toward(_work_spot, ARRIVE_PX, delta)


func _begin_work() -> void:
	var walked_to := _node
	_node = Player.nearest_node(
		get_tree().get_nodes_in_group(ResourceNode.GROUP),
		_player.global_position,
		_interact_radius_px
	)
	if walked_to != null and _node != walked_to:
		push_warning("capture: the player did not reach the %s" % walked_to.node_id)
	_node_id = _node.node_id if _node != null and not _until_exhausted() else ""
	_walking = false
	Input.action_press("interact")


func _run_work(delta: float) -> bool:
	if _until_exhausted() and _player.stamina.is_exhausted():
		return true
	if _walking:
		if _walk_toward(_work_spot, ARRIVE_PX, delta):
			_walking = false
			Input.action_press("interact")
		return false
	if not _node_done():
		return false
	if not _until_exhausted():
		return true
	# Release E before the next node: the player starts work on a fresh press.
	Input.action_release("interact")
	_node = _nearest_node(CHOP_IDS, CHOP_SEARCH_TILES)
	if _node == null:
		push_warning("capture: no tree or stump left to chop")
		return true
	_work_spot = _work_spot_for(_node)
	_walking = true
	_start_walk()
	return false


func _until_exhausted() -> bool:
	return _step.get("until", "") == UNTIL_EXHAUSTED


## The node is used up, gone or turned into another node, like a tree into a stump.
func _node_done() -> bool:
	if not is_instance_valid(_node) or not _node.visible or not _node.is_workable():
		return true
	return not _node_id.is_empty() and _node.node_id != _node_id


func _run_collect(delta: float) -> bool:
	if not is_instance_valid(_loot):
		_loot = _nearest_loot()
		if _loot == null:
			return true
		_start_walk()
	# The pile is pulled in and picked up on the way. A pile the walk cannot
	# reach or the player cannot carry is left behind.
	if _walk_toward(_loot.global_position, LOOT_REACHED_PX, delta):
		_skipped_loot.append(_loot)
		_loot = null
	return false


func _start_walk() -> void:
	_best_distance = INF
	_stuck_time = 0.0
	_detours = 0
	_detour_left = 0.0


## Holds the move actions toward [param point], stepping aside around obstacles.
## True once the player is within [param stop_px] of it or has given up.
func _walk_toward(point: Vector2, stop_px: float, delta: float) -> bool:
	var offset := point - _player.global_position
	var distance := offset.length()
	if distance <= stop_px:
		_hold_move(Vector2.ZERO)
		return true
	if _detour_left > 0.0:
		_detour_left -= delta
		_hold_move(_detour_direction)
		return false
	if distance < _best_distance - 1.0:
		_best_distance = distance
		_stuck_time = 0.0
	else:
		_stuck_time += delta
		if _stuck_time >= STUCK_TIME:
			if _detours >= DETOUR_TRIES:
				push_warning("capture: stuck %.0f px short of the target" % distance)
				_hold_move(Vector2.ZERO)
				return true
			_detours += 1
			var side := 1.0 if _detours % 2 == 1 else -1.0
			_detour_direction = offset.orthogonal() * side
			_detour_left = DETOUR_TIME * _detours
			_best_distance = INF
			_stuck_time = 0.0
	_hold_move(offset)
	return false


## Moves the cursor with the left button held from the slot to the target,
## then lets go a frame later, as a player drags a stack.
func _run_drag() -> bool:
	if _released:
		return true
	if _step_time < DRAG_TIME:
		var at := _drag_from.lerp(_drag_to, _step_time / DRAG_TIME)
		_move_mouse(at, MOUSE_BUTTON_MASK_LEFT)
		return false
	_move_mouse(_drag_to, MOUSE_BUTTON_MASK_LEFT)
	_click(_drag_to, false)
	_released = true
	return false


func _grid(grid_name: String) -> SlotGrid:
	return _hud.inventory_bar() if grid_name == "inventory" else _hud.basket_panel()


## The screen point the drag ends at: a slot, or a spot above the player, out of
## every panel, for the ground.
func _drag_target() -> Vector2:
	if _step.to == GROUND_TARGET:
		var player := get_viewport().get_canvas_transform() * _player.global_position
		return player + Vector2(0, -120)
	return _grid(_step.to).slot_center(int(_step.to_index))


## Clicks once the preview has been shown long enough. The step ends a frame
## later, when the game has handled the click and the blueprint stands.
func _run_place() -> bool:
	if _placed:
		return true
	if _step_time >= float(_step.get("time", PLACE_AIM_TIME)):
		_click(_mouse_screen, true)
		_placed = true
	return false


## Holds E at the blueprint until it is built; a blueprint that lacks materials
## takes what the player has, then the step ends.
func _run_build() -> bool:
	if _site == null:
		push_warning("capture: no blueprint in reach")
		return true
	if not _site.is_blueprint:
		return true
	return not _site.has_all_materials() and _step_time >= BUILD_GIVE_UP_TIME


## A spot just outside the side of [param rect] nearest to the player, so the
## walk does not run into the blueprint itself.
func _blueprint_spot(rect: Rect2) -> Vector2:
	var center := rect.get_center()
	var spots: Array[Vector2] = [
		Vector2(center.x, rect.end.y + BLUEPRINT_FRONT_PX),
		Vector2(center.x, rect.position.y - BLUEPRINT_FRONT_PX),
		Vector2(rect.position.x - BLUEPRINT_FRONT_PX, center.y),
		Vector2(rect.end.x + BLUEPRINT_FRONT_PX, center.y),
	]
	var best := spots[0]
	for spot in spots:
		if spot.distance_to(_player.global_position) < best.distance_to(_player.global_position):
			best = spot
	return best


## The nearest blueprint within [param radius_px] of the player, or null;
## any building, finished too, if [param any_building]. A negative radius means
## the interact radius.
func _nearest_blueprint(radius_px := -1.0, any_building := false) -> Building:
	var best: Building = null
	var best_distance := _interact_radius_px if radius_px < 0.0 else radius_px
	for building: Building in get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP):
		var distance := building.distance_to(_player.global_position)
		if (building.is_blueprint or any_building) and distance <= best_distance:
			best = building
			best_distance = distance
	return best


## The screen point over the center of the building that has its top left tile
## at [param tile], tiles from the fire.
func _tile_center(tile: Array, recipe_id: String) -> Vector2:
	var size: Dictionary = GameData.table("buildings")[recipe_id]
	var center := _tiles(tile) + Vector2(int(size.width), int(size.height)) / 2.0
	var world := _campfire.global_position + center * Units.TILE_PX
	return get_viewport().get_canvas_transform() * world


func _tiles(cell: Array) -> Vector2:
	return Vector2(float(cell[0]), float(cell[1]))


## A mouse move to [param at] on the screen with [param buttons] held, so build
## mode moves its preview there and a held left button drags a stack.
func _move_mouse(at: Vector2, buttons := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at - _mouse_screen
	event.button_mask = buttons
	_mouse_screen = at
	Input.parse_input_event(event)


## A left mouse button event at [param at] on the screen, the way a player clicks;
## with [param shift] Shift is held.
func _click(at: Vector2, pressed: bool, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.shift_pressed = shift
	if pressed:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)


func _hold_move(direction: Vector2) -> void:
	var strengths := move_strengths(direction)
	for action: String in strengths:
		if strengths[action] > 0.0:
			Input.action_press(action, strengths[action])
		else:
			Input.action_release(action)


## The work spot on a side of the node from which the player picks this node and
## not a neighbour, like the stump of a tree felled next to it. The side nearer
## to the player goes first.
func _work_spot_for(node: ResourceNode) -> Vector2:
	var side_px := _interact_radius_px * NODE_SIDE_SHARE
	var near_side := -1.0 if _player.global_position.x < node.global_position.x else 1.0
	var nodes := get_tree().get_nodes_in_group(ResourceNode.GROUP)
	for side in [near_side, -near_side]:
		var spot := node.global_position + Vector2(side * side_px, NODE_FRONT_PX)
		if Player.nearest_node(nodes, spot, _interact_radius_px) == node:
			return spot
	push_warning("capture: a neighbour is nearer than %s from both sides" % node.node_id)
	return node.global_position + Vector2(near_side * side_px, NODE_FRONT_PX)


## The nearest workable node with one of [param ids] within [param radius_tiles], or null.
func _nearest_node(ids: Array, radius_tiles := INF) -> ResourceNode:
	var best: ResourceNode = null
	var best_distance := radius_tiles * Units.TILE_PX
	for node: ResourceNode in get_tree().get_nodes_in_group(ResourceNode.GROUP):
		if node.node_id not in ids or not node.visible or not node.is_workable():
			continue
		var distance := _player.global_position.distance_to(node.global_position)
		if distance <= best_distance:
			best = node
			best_distance = distance
	return best


## The nearest pile around the player that the player can carry, or null.
func _nearest_loot() -> GroundItem:
	var best: GroundItem = null
	var best_distance := COLLECT_RADIUS_TILES * Units.TILE_PX
	for item: GroundItem in get_tree().get_nodes_in_group(GroundItem.GROUP):
		if item in _skipped_loot or item.is_queued_for_deletion():
			continue
		if _player.inventory.carry_amount(item.item_id, item.count) <= 0:
			continue
		var distance := _player.global_position.distance_to(item.global_position)
		if distance <= best_distance:
			best = item
			best_distance = distance
	return best
