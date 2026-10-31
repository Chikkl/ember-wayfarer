class_name Player
extends CharacterBody2D
## The player: walking, stamina, rest and gathering.
## Rules: docs/systems/movement-stamina.md, docs/systems/gathering.md.
## Values: data/player.json, data/gathering.json.

## Emitted once, when the first hut is built.
signal step_completed

enum Facing { DOWN, UP, LEFT, RIGHT }

const GROUP := "player"
const NEED_MATERIALS_HINT := "нужны материалы"
const EMPTY_FIRST_HINT := "сначала выложи всё"
const COMFORT_COLOR := Color("ffb37a")
## Built last, it finishes step 1.
const FINALE_BUILDING := "hut"
## sin(22.5°): input closer than this to vertical counts as straight up or down,
## anything else, diagonals included, faces left or right.
const SIDE_FACING_MIN_X := 0.3827
const BODY_COLOR := Color("4f7cac")
const SKIN_COLOR := Color("f0c9a0")
const SHADOW_COLOR := Color(0, 0, 0, 0.25)
const HANDLE_COLOR := Color("8a6238")
const TOOL_HEAD_COLOR := Color("8c8a86")
## Tools held in the fist, without a handle.
const FIST_TOOLS: Array[String] = ["chopper"]
const HINT_COLOR := Color("ffb37a")
## One hint for any missing tool: tools change as crafting grows, the hint stays.
const NEED_TOOL_HINT := "нужен инструмент"
const BUNDLE_COLOR := Color("9b7a4c")
const HIT_FLASH_TIME := 0.12
const XP_COLOR := Color("6fb7e8")
const LEVEL_COLOR := Color("ffd25e")
## A ring grows around the player on a new level.
const LEVEL_FLASH_TIME := 0.6
## The crafting ring over the head fills while an item is being made.
const CRAFT_RING_CENTER := Vector2(0, -52)
const CRAFT_RING_RADIUS := 7.0
const CRAFT_RING_BACK := Color(0.1, 0.1, 0.1, 0.55)
const CRAFT_RING_COLOR := Color("ffd25e")
## A dropped pile lands this many tiles in front of the player.
const DROP_DISTANCE_TILES := 0.8

var stamina: Stamina
var inventory: Inventory
var progression: Progression
var recipe_tree: RecipeTree
var crafting: Crafting
## Set by the main scene: in its mode for taking down, E takes buildings down.
var build_mode: BuildMode
var is_resting := false
var facing := Facing.DOWN

var _move_speed_px: float
var _accel_time: float
var _rest_params: Dictionary
var _items: Dictionary
var _work: WorkRhythm
var _interact_radius_px: float
## Rows of data/tools.csv and the rhythm of work by hand.
var _tools: Dictionary
var _hands_interval: float
var _target: ResourceNode
## The tool the player works [member _target] with.
var _tool: ToolStats
var _highlighted: ResourceNode
## The blueprint the player builds while holding the work button.
var _site: Building
## The building the player takes down while holding the work button.
var _teardown: Building
var _teardown_time := 0.0
var _dismantle_time: float
var _step_done := false
var _hit_flash := 0.0
var _level_flash := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	var params := GameData.params("player")
	stamina = Stamina.new(params)
	_move_speed_px = float(params.move_speed) * Units.TILE_PX
	_accel_time = maxf(float(params.move_accel_time), 0.001)
	_rest_params = GameData.params("comfort")
	var gathering := GameData.params("gathering")
	_items = GameData.table("items")
	inventory = Inventory.new(gathering, _items)
	progression = Progression.new(GameData.params("progression"))
	progression.leveled_up.connect(_on_leveled_up)
	recipe_tree = RecipeTree.new(GameData.table("recipe_tree"))
	crafting = Crafting.new(GameData.table("recipes"), inventory, recipe_tree)
	_dismantle_time = float(GameData.params("crafting").dismantle_time)
	_tools = GameData.table("tools")
	_hands_interval = float(gathering.hit_interval)
	_work = WorkRhythm.new(_hands_interval)
	_interact_radius_px = float(gathering.interact_radius) * Units.TILE_PX
	motion_mode = MOTION_MODE_FLOATING
	$StaminaRing.stamina = stamina


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	is_resting = next_resting(is_resting, input, Input.is_action_just_pressed("rest"))
	if crafting.is_busy() and (input != Vector2.ZERO or Input.is_action_just_pressed("interact")):
		crafting.cancel()
	_finish_craft(crafting.update(delta))
	_move(input, delta)
	_gather(delta)
	var rest_rate := 0.0
	var regen_mult := 1.0
	if is_resting:
		var comfort := current_comfort()
		rest_rate = CampComfort.rest_rate(comfort, _rest_params)
		regen_mult = CampComfort.rest_regen_mult(comfort, _rest_params)
	stamina.update(delta, rest_rate, regen_mult)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	_level_flash = maxf(_level_flash - delta, 0.0)
	queue_redraw()


## Starts making [param recipe_id]: the player stands still until it is done,
## a step or the work button cancels it. Rules: docs/systems/crafting.md, "Изготовление".
func start_craft(recipe_id: String) -> bool:
	if not crafting.start(recipe_id):
		return false
	_work.stop()
	_target = null
	return true


## Comfort at the player's feet: the camp they stand in, or zero outside.
func current_comfort() -> int:
	return Camp.comfort_at(get_tree(), global_position)


## Items from the ground go into the inventory. The caller checks
## [method Inventory.carry_amount] first.
func pick_up(item_id: String, amount := 1) -> void:
	inventory.add(item_id, amount)
	var item_name: String = _items[item_id].name
	FloatingText.spawn(get_parent(), position + Vector2(0, -52), "+%d %s" % [amount, item_name])


## Drops one item from slot [param index], or the whole stack, in front of the player.
## The pile is not pulled back until the player walks away from it.
func drop_from_slot(index: int, whole_stack: bool) -> void:
	var taken := inventory.take(index, inventory.slots[index].get("count", 0) if whole_stack else 1)
	if taken.is_empty():
		return
	var item := GroundItem.new()
	item.item_id = taken.item_id
	item.count = taken.count
	item.position = position
	item.land_at = position + _facing_vector() * DROP_DISTANCE_TILES * Units.TILE_PX
	item.wait_for_player_to_leave = true
	get_parent().add_child(item)


## The workable node nearest to [param origin] within [param radius], or null.
static func nearest_node(nodes: Array[Node], origin: Vector2, radius: float) -> ResourceNode:
	var best: ResourceNode = null
	var best_distance := radius
	for node: ResourceNode in nodes:
		if not node.is_workable():
			continue
		var distance := origin.distance_to(node.global_position)
		if distance <= best_distance:
			best = node
			best_distance = distance
	return best


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
	var target := input * _move_speed_px * stamina.speed_mult() * inventory.speed_mult()
	if is_resting:
		target = Vector2.ZERO
	var accel := _move_speed_px / _accel_time
	velocity = velocity.move_toward(target, accel * delta)
	move_and_slide()
	facing = facing_for(input, facing)


## Hold-to-work on the nearest resource node. Rules: docs/systems/gathering.md, "Действия".
func _gather(delta: float) -> void:
	var nearest := nearest_node(
		get_tree().get_nodes_in_group(ResourceNode.GROUP), global_position, _interact_radius_px
	)
	if build_mode != null and build_mode.is_dismantling():
		_work.stop()
		_target = null
		_set_highlight(null)
		_take_down(delta)
		return
	if Input.is_action_just_pressed("interact") and not is_resting:
		var site := _nearest_blueprint()
		var node_distance := INF
		if nearest != null:
			node_distance = global_position.distance_to(nearest.global_position)
		if site != null and site.distance_to(global_position) <= node_distance:
			_start_site(site)
		elif nearest != null:
			_start_work(nearest)
	var held := Input.is_action_pressed("interact") and not is_resting
	_build(delta, held)
	if not held or not _can_keep_working():
		_work.stop()
		_target = null
	_set_highlight(_target if _target != null else nearest)
	var cost := _target.harvest.stamina_cost * _tool.stamina_mult if _target != null else 0.0
	if _work.update(delta, stamina, cost) and _target != null:
		_hit_flash = HIT_FLASH_TIME
		facing = facing_for(_target.global_position - global_position, facing)
		var loot := _target.hit(_tool.power)
		_gain_xp(Progression.loot_xp(loot, _items), _target.position + Vector2(0, -44))


## Work needs a fitting tool in the inventory, the strongest one is taken.
## Without it the player only pushes the node. Rules: docs/systems/gathering.md, "Инструменты".
func _start_work(node: ResourceNode) -> void:
	var tool_id := node.harvest.best_tool(inventory, _tools)
	if tool_id.is_empty():
		node.push()
		_hit_flash = HIT_FLASH_TIME
		FloatingText.spawn(
			get_parent(), node.position + Vector2(0, -44), NEED_TOOL_HINT, HINT_COLOR
		)
		return
	_target = node
	_tool = ToolStats.new(tool_id, _tools, _hands_interval)
	_work.interval = _tool.hit_interval
	_work.start()


## The nearest blueprint in reach, or null.
func _nearest_blueprint() -> Building:
	return _nearest_building(true)


## The nearest building in reach, only blueprints if [param blueprints_only], or null.
func _nearest_building(blueprints_only := false) -> Building:
	var best: Building = null
	var best_distance := _interact_radius_px
	for building: Building in get_tree().get_nodes_in_group(Building.BUILDINGS_GROUP):
		var distance := building.distance_to(global_position)
		if (building.is_blueprint or not blueprints_only) and distance <= best_distance:
			best = building
			best_distance = distance
	return best


## In the mode for taking down: holding E at a building for dismantle_time
## takes it down and gives the materials back. Rules: docs/systems/crafting.md, "Разбор".
func _take_down(delta: float) -> void:
	var held := Input.is_action_pressed("interact") and not is_resting
	if Input.is_action_just_pressed("interact") and not is_resting:
		_stop_take_down()
		_teardown = _nearest_building()
		if _teardown != null and not _teardown.can_dismantle():
			var top := _teardown.position - Vector2(0, _teardown.size_px.y + 20)
			FloatingText.spawn(get_parent(), top, EMPTY_FIRST_HINT, HINT_COLOR)
			_teardown = null
	if _teardown == null:
		return
	if not held or not is_instance_valid(_teardown):
		_stop_take_down()
		return
	if _teardown.distance_to(global_position) > _interact_radius_px:
		_stop_take_down()
		return
	_teardown_time += delta
	_teardown.teardown = _teardown_time / _dismantle_time
	if _teardown_time >= _dismantle_time:
		var building := _teardown
		_stop_take_down()
		var share := float(GameData.params("crafting").dismantle_refund)
		_take_back(building.refund(share), building.position)
		building.queue_free()


func _stop_take_down() -> void:
	if is_instance_valid(_teardown):
		_teardown.teardown = 0.0
	_teardown = null
	_teardown_time = 0.0


## Materials back into the inventory, what does not fit falls in piles at [param at].
func _take_back(materials: Dictionary, at: Vector2) -> void:
	var y := -52.0
	var piles := 0
	for item_id: String in materials:
		var count: int = materials[item_id]
		var fit := inventory.carry_amount(item_id, count)
		if fit > 0:
			inventory.add(item_id, fit)
			var text := "+%d %s" % [fit, _items[item_id].name]
			FloatingText.spawn(get_parent(), position + Vector2(0, y), text)
			y -= 14.0
		if count > fit:
			var pile := GroundItem.new()
			pile.item_id = item_id
			pile.count = count - fit
			pile.position = at
			pile.land_at = at + Vector2(-12 + 12 * piles, 10)
			piles += 1
			pile.wait_for_player_to_leave = true
			get_parent().add_child(pile)


## The work button at a blueprint: first every missing material from the
## inventory goes in. Rules: docs/systems/crafting.md, "Постройки".
func _start_site(site: Building) -> void:
	_work.stop()
	_target = null
	_site = site
	var top := site.position - Vector2(0, site.size_px.y + 20)
	if not site.deliver_from(inventory).is_empty():
		var percent := roundi(site.delivered_share() * 100.0)
		FloatingText.spawn(get_parent(), top, "сдано %d%%" % percent)
	elif not site.has_all_materials():
		FloatingText.spawn(get_parent(), top, NEED_MATERIALS_HINT, HINT_COLOR)


## While the button is held in reach, a blueprint with all materials is assembled.
func _build(delta: float, held: bool) -> void:
	if _site == null:
		return
	if not held or not is_instance_valid(_site) or not _site.is_blueprint:
		_site = null
	elif _site.distance_to(global_position) > _interact_radius_px:
		_site = null
	elif _site.assemble(delta):
		_finish_building(_site)
		_site = null


func _finish_building(site: Building) -> void:
	var comfort_before := Camp.comfort_at(get_tree(), site.global_position)
	site.complete()
	var comfort_gain := Camp.comfort_at(get_tree(), site.global_position) - comfort_before
	var top := site.position - Vector2(0, site.size_px.y + 20)
	if comfort_gain > 0:
		FloatingText.spawn(get_parent(), top, "+%d комфорта" % comfort_gain, COMFORT_COLOR)
	_gain_xp(crafting.finish_building(site.item_id), top - Vector2(0, 16), " · впервые")
	if site.item_id == FINALE_BUILDING and not _step_done:
		_step_done = true
		step_completed.emit()


## Experience for a result, shown as "+N опыта" over [param at].
## Rules: docs/systems/tech-tree.md, "Опыт и уровень".
func _gain_xp(amount: int, at: Vector2, note := "") -> void:
	if amount <= 0:
		return
	FloatingText.spawn(get_parent(), at, "+%d опыта%s" % [amount, note], XP_COLOR)
	progression.add_xp(amount)


## A made item flies into the inventory; the first one also gives experience.
func _finish_craft(result: Dictionary) -> void:
	if result.is_empty():
		return
	var item_name: String = _items[result.item_id].name
	FloatingText.spawn(get_parent(), position + Vector2(0, -52), "+1 %s" % item_name)
	_gain_xp(result.xp, position + Vector2(0, -68), " · впервые")


func _on_leveled_up(level: int) -> void:
	_level_flash = LEVEL_FLASH_TIME
	FloatingText.spawn(get_parent(), position + Vector2(0, -68), "Уровень %d!" % level, LEVEL_COLOR)


## Work goes on while the node is in reach and the tool still fits it:
## a tree felled with the chopper leaves a stump that only the axe takes.
func _can_keep_working() -> bool:
	return (
		_work.is_working
		and is_instance_valid(_target)
		and _target.is_workable()
		and _target.harvest.best_tool(inventory, _tools) == _tool.id
		and global_position.distance_to(_target.global_position) <= _interact_radius_px
	)


func _set_highlight(node: ResourceNode) -> void:
	if node == _highlighted:
		return
	if is_instance_valid(_highlighted):
		_highlighted.highlighted = false
	_highlighted = node
	if node != null:
		node.highlighted = true


func _facing_vector() -> Vector2:
	match facing:
		Facing.UP:
			return Vector2.UP
		Facing.LEFT:
			return Vector2.LEFT
		Facing.RIGHT:
			return Vector2.RIGHT
	return Vector2.DOWN


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
	elif inventory.carried_weight() > inventory.carry_limit():
		draw_rect(Rect2(-9, -33, 18, 10), BUNDLE_COLOR)
		draw_rect(Rect2(-8, -23, 16, 19), body_color)
		head = Vector2(0, -28)
	else:
		draw_rect(Rect2(-8, -26, 16, 22), body_color)
	draw_circle(head, 7.0, SKIN_COLOR)
	_draw_eyes(head)
	if _target != null and _tool.id not in NodeHarvest.NO_TOOL:
		_draw_tool()
	if crafting.is_busy():
		draw_arc(CRAFT_RING_CENTER, CRAFT_RING_RADIUS, 0.0, TAU, 32, CRAFT_RING_BACK, 4.0, true)
		var end_angle := -PI / 2.0 + TAU * crafting.progress()
		draw_arc(
			CRAFT_RING_CENTER,
			CRAFT_RING_RADIUS,
			-PI / 2.0,
			end_angle,
			32,
			CRAFT_RING_COLOR,
			3.0,
			true
		)
	if _level_flash > 0.0:
		var t := _level_flash / LEVEL_FLASH_TIME
		var color := LEVEL_COLOR
		color.a = t
		draw_arc(Vector2(0, -16), 14.0 + (1.0 - t) * 22.0, 0.0, TAU, 40, color, 3.0, true)


## The tool comes out of the inventory while the player works with it.
## During a hit it swings down.
func _draw_tool() -> void:
	var side := -1.0 if facing == Facing.LEFT else 1.0
	var angle := (0.9 if _hit_flash > 0.0 else 0.0) * side
	draw_set_transform(Vector2(9 * side, -14), angle)
	if _tool.id in FIST_TOOLS:
		draw_circle(Vector2(3 * side, -4), 3.5, TOOL_HEAD_COLOR)
	else:
		draw_line(Vector2.ZERO, Vector2(4 * side, -16), HANDLE_COLOR, 2.5)
		draw_rect(Rect2(Vector2(4 * side - 3, -19), Vector2(6, 5)), TOOL_HEAD_COLOR)
	draw_set_transform(Vector2.ZERO)


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
