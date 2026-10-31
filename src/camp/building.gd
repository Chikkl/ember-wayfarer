class_name Building
extends ComfortItem
## A building of step 1. First a blueprint: it takes materials from the player
## and is assembled by holding the work button. Then the finished building,
## counted by the camp if it is a comfort item.
## Rules: docs/systems/crafting.md, "Постройки" and "Разбор". Values: data/recipes.csv,
## data/buildings.csv. Placeholder graphics until the art pass.

const BUILDINGS_GROUP := "buildings"
const BASKET := "basket"
const BLUEPRINT_ALPHA := 0.35
const OUTLINE_COLOR := Color(1, 1, 1, 0.7)
const FILL_COLOR := Color(1, 1, 1, 0.1)
const RING_RADIUS := 8.0
const RING_BACK := Color(0.1, 0.1, 0.1, 0.55)
const DELIVERY_COLOR := Color("8fd14f")
const ASSEMBLY_COLOR := Color("ffd25e")
const MISSING_COLOR := Color("ff7a6a")
const TEXT_COLOR := Color(1, 1, 1, 0.9)
const FONT_SIZE := 11
const LINE_HEIGHT := 13.0
const WOOD_COLOR := Color("8a6238")
const DARK_WOOD_COLOR := Color("6b4a2e")
const LEAF_COLOR := Color("5b8a3c")
const PLAIT_COLOR := Color("a07a4a")
const TEARDOWN_COLOR := Color("ff9a4a")

var is_blueprint := true
## Materials put into the blueprint, {item_id: count}.
var delivered := {}
## Seconds of assembly done.
var assembled := 0.0
var size_px: Vector2
## Slots of a basket, null for other buildings. A basket has no load cap.
var storage: Inventory
## How far the player has taken it down, from 0 to 1; 0 when nobody does.
var teardown := 0.0:
	set(value):
		teardown = value
		queue_redraw()

var _recipe: Dictionary
var _items: Dictionary
var _player: Node2D
var _interact_radius_px: float


## A blueprint of [param recipe_id] with its bottom center at [param at].
static func blueprint(recipe_id: String, at: Vector2) -> Building:
	var building := Building.new()
	building.item_id = recipe_id
	building.position = at
	return building


func _ready() -> void:
	add_to_group(BUILDINGS_GROUP)
	_recipe = GameData.table("recipes")[item_id]
	_items = GameData.table("items")
	var size: Dictionary = GameData.table("buildings")[item_id]
	size_px = Vector2(int(size.width), int(size.height)) * Units.TILE_PX
	_interact_radius_px = float(GameData.params("gathering").interact_radius) * Units.TILE_PX
	_player = get_tree().get_first_node_in_group(Player.GROUP)
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_px
	shape.shape = rect
	shape.position = Vector2(0, -size_px.y / 2.0)
	body.add_child(shape)
	add_child(body)


## The ground the building takes, in global coordinates.
func footprint() -> Rect2:
	return Rect2(global_position - Vector2(size_px.x / 2.0, size_px.y), size_px)


## Distance from [param point] to the nearest edge of the footprint, 0 inside it.
func distance_to(point: Vector2) -> float:
	var rect := footprint()
	var closest := Vector2(
		clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y)
	)
	return point.distance_to(closest)


func materials() -> Dictionary:
	return DataLoader.parse_amounts(_recipe.materials)


## Materials still missing in the blueprint, {item_id: count}.
func missing() -> Dictionary:
	var left := {}
	var needed := materials()
	for item_id_needed: String in needed:
		var count: int = needed[item_id_needed] - delivered.get(item_id_needed, 0)
		if count > 0:
			left[item_id_needed] = count
	return left


func has_all_materials() -> bool:
	return missing().is_empty()


## Share of the materials delivered, by weight.
func delivered_share() -> float:
	var total := _weight(materials())
	return _weight(delivered) / total if total > 0.0 else 1.0


## Moves every missing material the [param inventory] has into the blueprint.
## Returns what was moved, {item_id: count}.
func deliver_from(inventory: Inventory) -> Dictionary:
	var moved := {}
	var left := missing()
	for item_id_needed: String in left:
		var count := inventory.remove(item_id_needed, left[item_id_needed])
		if count > 0:
			delivered[item_id_needed] = delivered.get(item_id_needed, 0) + count
			moved[item_id_needed] = count
	return moved


## Assembles for [param delta] seconds once all materials are in.
## True when the assembly time is reached; then call [method complete].
func assemble(delta: float) -> bool:
	if not is_blueprint or not has_all_materials():
		return false
	assembled += delta
	return assembled >= float(_recipe.time)


## Share of the ring over the blueprint: materials first, then assembly.
func progress() -> float:
	if not has_all_materials():
		return delivered_share()
	return clampf(assembled / float(_recipe.time), 0.0, 1.0)


## Turns the blueprint into the finished building; a comfort item joins the camp count.
func complete() -> void:
	is_blueprint = false
	if item_id == BASKET:
		var params := GameData.params("gathering").duplicate()
		params.inventory_slots = params.basket_slots
		storage = Inventory.new(params, _items)
		storage.limit_weight = false
	if item_id in GameData.table("comfort_items"):
		add_to_group(ComfortItem.GROUP)
	queue_redraw()


## What taking it down gives back: everything delivered into a blueprint, or
## [param share] of the recipe materials of a finished building.
func refund(share: float) -> Dictionary:
	if is_blueprint:
		return delivered.duplicate()
	var back := {}
	var needed := materials()
	for item: String in needed:
		var count := floori(needed[item] * share + 0.0001)
		if count > 0:
			back[item] = count
	return back


## Whether the building can be taken down now: a basket only when it is empty.
## Rules: docs/systems/crafting.md, "Разбор".
func can_dismantle() -> bool:
	return storage == null or storage.is_empty()


func _weight(amounts: Dictionary) -> float:
	var total := 0.0
	for item: String in amounts:
		total += float(_items[item].weight) * amounts[item]
	return total


func _process(_delta: float) -> void:
	if is_blueprint:
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2(-size_px.x / 2.0, -size_px.y), size_px)
	if teardown > 0.0:
		var top := Vector2(0, rect.position.y - RING_RADIUS - 6)
		draw_arc(top, RING_RADIUS, 0.0, TAU, 32, RING_BACK, 4.0, true)
		draw_arc(
			top, RING_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * teardown, 32, TEARDOWN_COLOR, 3.0, true
		)
	if not is_blueprint:
		_draw_shape(rect, 1.0)
		return
	draw_rect(rect, FILL_COLOR)
	_draw_shape(rect, BLUEPRINT_ALPHA)
	draw_rect(rect, OUTLINE_COLOR, false, 1.5)
	var ring_center := Vector2(0, rect.position.y - RING_RADIUS - 6)
	draw_arc(ring_center, RING_RADIUS, 0.0, TAU, 32, RING_BACK, 4.0, true)
	var color := ASSEMBLY_COLOR if has_all_materials() else DELIVERY_COLOR
	var end_angle := -PI / 2.0 + TAU * progress()
	draw_arc(ring_center, RING_RADIUS, -PI / 2.0, end_angle, 32, color, 3.0, true)
	if _player != null and distance_to(_player.global_position) <= _interact_radius_px:
		_draw_list(Vector2(rect.end.x + 8, rect.position.y + LINE_HEIGHT))


## "delivered / needed" for every material, to the right of the blueprint so it
## does not cover the player, first line at [param top_left].
func _draw_list(top_left: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var needed := materials()
	var y := top_left.y
	for item: String in needed:
		var have: int = delivered.get(item, 0)
		var line := "%s %d/%d" % [_items[item].name, have, needed[item]]
		var color := TEXT_COLOR if have >= needed[item] else MISSING_COLOR
		var at := Vector2(top_left.x, y)
		draw_string_outline(
			font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, Color.BLACK
		)
		draw_string(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
		y += LINE_HEIGHT


func _draw_shape(rect: Rect2, alpha: float) -> void:
	match item_id:
		"basket":
			var body := rect.grow(-4.0)
			draw_rect(body, Color(PLAIT_COLOR, alpha))
			for i in 3:
				var y := body.position.y + body.size.y * (i + 1) / 4.0
				var line := Color(DARK_WOOD_COLOR, alpha)
				draw_line(Vector2(body.position.x, y), Vector2(body.end.x, y), line, 1.5)
		"log_seat":
			var log_rect := Rect2(
				rect.position + Vector2(2, rect.size.y * 0.45), rect.size * Vector2(1, 0.4)
			)
			draw_rect(log_rect.grow_individual(-2, 0, -2, 0), Color(DARK_WOOD_COLOR, alpha))
			draw_circle(
				Vector2(log_rect.end.x - 4, log_rect.get_center().y), 5.0, Color(WOOD_COLOR, alpha)
			)
		"bedroll":
			var bed := rect.grow(-3.0)
			draw_rect(bed, Color(LEAF_COLOR, alpha))
			var pillow := Rect2(bed.position + Vector2(3, 3), Vector2(10, bed.size.y - 6))
			draw_rect(pillow, Color(LEAF_COLOR.lightened(0.25), alpha))
		"lean_to":
			var roof := PackedVector2Array(
				[
					Vector2(rect.position.x, rect.end.y - 4),
					Vector2(rect.position.x + 6, rect.position.y - 10),
					Vector2(rect.end.x, rect.position.y + 6),
					Vector2(rect.end.x - 4, rect.end.y - 4),
				]
			)
			draw_colored_polygon(roof, Color(LEAF_COLOR.darkened(0.1), alpha))
			draw_polyline(roof, Color(WOOD_COLOR, alpha), 2.0)
		"hut":
			var walls := PackedVector2Array(
				[
					Vector2(rect.position.x, rect.end.y),
					Vector2(0, rect.position.y - 26),
					Vector2(rect.end.x, rect.end.y),
				]
			)
			draw_colored_polygon(walls, Color(LEAF_COLOR.darkened(0.05), alpha))
			draw_polyline(walls, Color(WOOD_COLOR, alpha), 2.5)
			var door := Rect2(Vector2(-9, rect.end.y - 26), Vector2(18, 26))
			draw_rect(door, Color(0.12, 0.09, 0.06, alpha))
