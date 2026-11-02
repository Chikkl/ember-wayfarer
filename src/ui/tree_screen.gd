class_name TreeScreen
extends Control
## The recipe tree screen: nodes in columns by their chain of requirements,
## lines from requirements. A click on an available node opens it.
## Feedback rules: docs/systems/tech-tree.md, "Обратная связь игроку".

const NODE_SIZE := Vector2(240, 84)
const GAP := Vector2(56, 22)
const MARGIN := 24.0
const TITLE_HEIGHT := 44.0
const FONT_SIZE := 12
const NAME_SIZE := 14
const PANEL_COLOR := Color(0.06, 0.07, 0.06, 0.9)
const NODE_COLOR := Color(0.17, 0.19, 0.17)
const OPEN_FILL_COLOR := Color(0.3, 0.26, 0.12)
const OPEN_COLOR := Color("ffd25e")
const AVAILABLE_COLOR := Color(1, 1, 1, 0.9)
const WAITING_COLOR := Color(1, 1, 1, 0.35)
const LINE_COLOR := Color(1, 1, 1, 0.25)
const MUTED_COLOR := Color(1, 1, 1, 0.6)
## A locked node is drawn this faint.
const LOCKED_ALPHA := 0.4
## A node glows for this long after it opens.
const OPEN_FLASH_TIME := 0.8

var tree: RecipeTree
var progression: Progression

var _recipe_names: Dictionary
var _node_names: Dictionary
## Node id -> its rectangle in local coordinates.
var _rects := {}
## Node id -> seconds of glow left.
var _flash := {}


func setup(recipe_tree: RecipeTree, player_progression: Progression, recipes: Dictionary) -> void:
	tree = recipe_tree
	progression = player_progression
	for recipe_id: String in recipes:
		_recipe_names[recipe_id] = recipes[recipe_id].name
	for node_id: String in tree.nodes:
		_node_names[node_id] = tree.nodes[node_id].name
	_layout()
	set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_KEEP_SIZE)
	mouse_filter = MOUSE_FILTER_STOP
	tree.node_opened.connect(func(node_id: String) -> void: _flash[node_id] = OPEN_FLASH_TIME)
	hide()


func toggle() -> void:
	visible = not visible


## Id of the node under [param point] in local coordinates, or "".
func node_at(point: Vector2) -> String:
	for node_id: String in _rects:
		if _rects[node_id].has_point(point):
			return node_id
	return ""


## Center of [param node_id] on the screen, for a click.
func node_center(node_id: String) -> Vector2:
	return get_global_transform() * (_rects[node_id] as Rect2).get_center()


## A line from requirement [param from] to node [param to] that runs only through
## the gaps between nodes: through the column gap to a neighbour column, along
## the row gap past the columns in between.
static func edge_points(from: Rect2, to: Rect2) -> PackedVector2Array:
	var start := Vector2(from.end.x, from.get_center().y)
	var finish := Vector2(to.position.x, to.get_center().y)
	if to.position.x - from.end.x <= GAP.x + 1.0:
		var middle := from.end.x + GAP.x / 2.0
		return PackedVector2Array(
			[start, Vector2(middle, start.y), Vector2(middle, finish.y), finish]
		)
	# A separate lane at a quarter of the gap, so it does not merge with the
	# lines between neighbour columns.
	var out_x := from.end.x + GAP.x / 4.0
	var in_x := to.position.x - GAP.x / 4.0
	var row_gap_y := from.position.y - GAP.y / 2.0
	if to.position.y >= from.position.y:
		row_gap_y = from.end.y + GAP.y / 2.0
	return PackedVector2Array(
		[
			start,
			Vector2(out_x, start.y),
			Vector2(out_x, row_gap_y),
			Vector2(in_x, row_gap_y),
			Vector2(in_x, finish.y),
			finish,
		]
	)


func _layout() -> void:
	var rows_in_column := {}
	var end := Vector2.ZERO
	for node_id: String in tree.nodes:
		var column := tree.depth(node_id)
		var row: int = rows_in_column.get(column, 0)
		rows_in_column[column] = row + 1
		var top_left := (
			Vector2(MARGIN, MARGIN + TITLE_HEIGHT)
			+ Vector2(column * (NODE_SIZE.x + GAP.x), row * (NODE_SIZE.y + GAP.y))
		)
		_rects[node_id] = Rect2(top_left, NODE_SIZE)
		end = end.max(top_left + NODE_SIZE)
	size = end + Vector2(MARGIN, MARGIN)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var node_id := node_at(click.position)
	if not node_id.is_empty():
		tree.open(node_id, progression)
	accept_event()


func _process(delta: float) -> void:
	if not visible:
		return
	for node_id: String in _flash.keys():
		_flash[node_id] -= delta
		if _flash[node_id] <= 0.0:
			_flash.erase(node_id)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR)
	_text(font, Vector2(MARGIN, MARGIN + 16), "Дерево рецептов", NAME_SIZE)
	var right := "Очки развития: %d    T или Esc — закрыть" % progression.points
	var right_width := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_text(font, Vector2(size.x - MARGIN - right_width, MARGIN + 16), right, FONT_SIZE)
	for node_id: String in _rects:
		for required in tree.requirements(node_id):
			var color := OPEN_COLOR if tree.is_open(required) else LINE_COLOR
			draw_polyline(edge_points(_rects[required], _rects[node_id]), color, 2.0, true)
	for node_id: String in _rects:
		_draw_node(font, node_id)


func _draw_node(font: Font, node_id: String) -> void:
	var rect: Rect2 = _rects[node_id]
	var state := tree.state(node_id)
	var alpha := LOCKED_ALPHA if state == RecipeTree.State.LOCKED else 1.0
	var can_open := state == RecipeTree.State.AVAILABLE and progression.points >= tree.cost(node_id)
	var fill := OPEN_FILL_COLOR if state == RecipeTree.State.OPEN else NODE_COLOR
	draw_rect(rect, Color(fill, 0.95 * alpha))
	var border := WAITING_COLOR
	if state == RecipeTree.State.OPEN:
		border = OPEN_COLOR
	elif can_open:
		border = AVAILABLE_COLOR
	draw_rect(rect, Color(border, border.a * alpha), false, 2.0)
	if _flash.has(node_id):
		var glow := OPEN_COLOR
		glow.a = _flash[node_id] / OPEN_FLASH_TIME
		draw_rect(rect.grow(4.0 * glow.a), glow, false, 3.0)

	var left := rect.position.x + 10
	var white := Color(1, 1, 1, alpha)
	_text(font, Vector2(left, rect.position.y + 20), _node_names[node_id], NAME_SIZE, white)
	var recipes: Array[String] = []
	for recipe_id in tree.unlocks(node_id):
		recipes.append(_recipe_names.get(recipe_id, recipe_id))
	var gives := "→ " + ", ".join(recipes)
	draw_multiline_string(
		font,
		Vector2(left, rect.position.y + 38),
		gives,
		HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x - 20,
		FONT_SIZE,
		2,
		Color(MUTED_COLOR, MUTED_COLOR.a * alpha)
	)
	var status_color := Color(OPEN_COLOR if can_open else MUTED_COLOR, alpha)
	_text(font, Vector2(left, rect.end.y - 8), _status(node_id, state), FONT_SIZE, status_color)


func _status(node_id: String, state: RecipeTree.State) -> String:
	match state:
		RecipeTree.State.OPEN:
			return "открыт"
		RecipeTree.State.LOCKED:
			var missing: Array[String] = []
			for required in tree.requirements(node_id):
				if not tree.is_open(required):
					missing.append(_node_names[required])
			return "нужно: " + ", ".join(missing)
	var node_cost := tree.cost(node_id)
	if progression.points >= node_cost:
		return "клик — открыть за %d %s" % [node_cost, points_word(node_cost)]
	return "нужно очко развития"


## "очко", "очка" or "очков" for [param count].
static func points_word(count: int) -> String:
	if count % 100 in range(11, 15):
		return "очков"
	match count % 10:
		1:
			return "очко"
		2, 3, 4:
			return "очка"
	return "очков"


func _text(font: Font, at: Vector2, text: String, font_size: int, color := Color.WHITE) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
