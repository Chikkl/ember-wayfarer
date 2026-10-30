class_name CaptureDirector
extends Node
## Capture mode: plays a take from CaptureTakes by pressing the same actions as
## the player, so Movie Maker records real gameplay for reels and visual reviews.
## Run: godot --path . --write-movie <file>.avi --fixed-fps 60 -- --capture=<take>
## Guide: docs/captures.md, "Режим съёмки".
##
## Steps:
## - wait: stand still for "time" seconds;
## - walk_to: walk to "target", the fire or the nearest workable node with this id;
## - work: hold E on the node in reach until it is used up or turns into another
##   node; with "until": "exhausted" keep chopping trees and stumps until exhaustion;
## - collect: walk over the loot around the player;
## - rest: press R once;
## - press: press "action" once, like T for the tree screen;
## - click_tree_node: click "node" on the tree screen;
## - click_recipe: click "recipe" in the open crafting menu;
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
	"zoom",
]
const FIRE_TARGET := "fire"
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
		elif kind == "walk_to" and target != FIRE_TARGET and target not in nodes:
			problems.append("unknown target in %s" % step)
		elif kind == "work" and step.get("until", UNTIL_EXHAUSTED) != UNTIL_EXHAUSTED:
			problems.append("unknown 'until' in %s" % step)
		elif kind == "press" and not InputMap.has_action(step.get("action", "")):
			problems.append("unknown action in %s" % step)
		elif kind == "click_tree_node" and step.get("node", "") not in tree_nodes:
			problems.append("unknown tree node in %s" % step)
		elif kind == "click_recipe" and step.get("recipe", "") not in recipes:
			problems.append("unknown recipe in %s" % step)
	return problems


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
			_node = null if _step.target == FIRE_TARGET else _nearest_node([_step.target])
			if _node != null:
				_work_spot = _work_spot_for(_node)
			_start_walk()
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
		"zoom":
			var zoom := Vector2.ONE * float(_step.zoom)
			create_tween().tween_property(_camera, "zoom", zoom, ZOOM_TIME)


## Runs one frame of the step. True when the step is over.
func _run_step(delta: float) -> bool:
	match _step.do:
		"wait":
			return _step_time >= float(_step.time)
		"walk_to":
			return _run_walk_to(delta)
		"work":
			return _run_work(delta)
		"collect":
			return _run_collect(delta)
		"rest", "press", "click_tree_node", "click_recipe", "zoom":
			return true
	push_warning("capture: unknown step %s" % _step)
	return true


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
	# Only a walk hands its node over to the next step.
	if _step.get("do", "") != "walk_to":
		_node = null
	_step = {}


func _run_walk_to(delta: float) -> bool:
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


## A left mouse button event at [param at] on the screen, the way a player clicks.
func _click(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
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
