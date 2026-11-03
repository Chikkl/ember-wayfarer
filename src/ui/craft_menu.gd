class_name CraftMenu
extends Control
## The crafting menu on the left: starting recipes and recipes of open nodes,
## "have / need" for every material, a click makes the item or places a building.
## Feedback rules: docs/systems/crafting.md, "Обратная связь игроку".

## Emitted when a building is chosen: build mode places its blueprint.
signal build_requested(recipe_id: String)

const WIDTH_PX := 430.0
const ROW_HEIGHT_PX := 54.0
const HEADER_PX := 40.0
const MARGIN_PX := 12.0
const TOP_PX := 96
const ICON_X_PX := 26.0
const TEXT_X_PX := 50.0
const FONT_SIZE := 12
const NAME_SIZE := 14
const PANEL_COLOR := Color(0.06, 0.07, 0.06, 0.88)
const ROW_COLOR := Color(1, 1, 1, 0.06)
const MISSING_COLOR := Color("ff7a6a")
const MUTED_COLOR := Color(1, 1, 1, 0.55)
const NEW_COLOR := Color("ffd25e")
const XP_COLOR := Color("6fb7e8")
const PROGRESS_COLOR := Color("ffd25e")
const COMFORT_COLOR := Color("ffb37a")

var crafting: Crafting

var _player: Player
var _tree: RecipeTree
var _items: Dictionary
## Recipes shown, top to bottom.
var _rows: Array[String] = []
## Recipes from tree nodes the player has already seen in the menu.
var _seen: Array[String] = []


func setup(player: Player, items: Dictionary) -> void:
	_player = player
	crafting = player.crafting
	_tree = player.recipe_tree
	_items = items
	position = Vector2(16, TOP_PX)
	mouse_filter = MOUSE_FILTER_STOP
	_refresh()
	hide()


func toggle() -> void:
	if visible:
		close()
	else:
		show()


## Hides the menu; recipes from new nodes stop being marked as new.
func close() -> void:
	if visible:
		_seen.assign(crafting.available())
	hide()


## Id of the recipe in the row under [param point] in local coordinates, or "".
func recipe_at(point: Vector2) -> String:
	for i in _rows.size():
		if _row_rect(i).has_point(point):
			return _rows[i]
	return ""


## Center of the row of [param recipe_id] on the screen, for a click.
func recipe_center(recipe_id: String) -> Vector2:
	return get_global_transform() * _row_rect(_rows.find(recipe_id)).get_center()


func _row_rect(index: int) -> Rect2:
	var top := HEADER_PX + index * ROW_HEIGHT_PX
	return Rect2(MARGIN_PX, top, WIDTH_PX - 2 * MARGIN_PX, ROW_HEIGHT_PX - 4)


func _refresh() -> void:
	_rows = crafting.available()
	size = Vector2(WIDTH_PX, HEADER_PX + _rows.size() * ROW_HEIGHT_PX + MARGIN_PX)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var recipe_id := recipe_at(click.position)
	if recipe_id.is_empty():
		pass
	elif crafting.is_building(recipe_id):
		build_requested.emit(recipe_id)
	else:
		_player.start_craft(recipe_id)
	accept_event()


func _process(_delta: float) -> void:
	if visible:
		_refresh()
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR)
	_text(font, Vector2(MARGIN_PX, 26), "Крафт", NAME_SIZE)
	var hint := "C или Esc — закрыть"
	var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_text(font, Vector2(size.x - MARGIN_PX - hint_width, 26), hint, FONT_SIZE, MUTED_COLOR)
	for i in _rows.size():
		_draw_row(font, i)


func _draw_row(font: Font, index: int) -> void:
	var recipe_id := _rows[index]
	var rect := _row_rect(index)
	var problem := crafting.problem(recipe_id)
	var ready := problem in [Crafting.Problem.NONE, Crafting.Problem.BUILDING]
	draw_rect(rect, ROW_COLOR)
	if recipe_id in _items:
		ItemIcon.draw(
			self, recipe_id, Vector2(rect.position.x + ICON_X_PX, rect.get_center().y + 8), 2.0
		)

	var left := rect.position.x + TEXT_X_PX
	var name_color := Color.WHITE if ready else MUTED_COLOR
	var name: String = crafting.recipes[recipe_id].name
	_text(font, Vector2(left, rect.position.y + 18), name, NAME_SIZE, name_color)
	var name_width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
	if recipe_id in _tree.unlocked_recipes() and recipe_id not in _seen:
		_text(
			font,
			Vector2(left + name_width + 8, rect.position.y + 18),
			"новое",
			FONT_SIZE,
			NEW_COLOR
		)

	var x := left
	var line_y := rect.position.y + 38
	var needed := crafting.materials(recipe_id)
	for item_id: String in needed:
		var have := _player.inventory.count(item_id)
		var part := "%s %d/%d" % [_item_name(item_id), mini(have, needed[item_id]), needed[item_id]]
		var color := MUTED_COLOR if have >= needed[item_id] else MISSING_COLOR
		x = _text(font, Vector2(x, line_y), part + "   ", FONT_SIZE, color)
	for tool_id in crafting.tools(recipe_id):
		var color := MUTED_COLOR if _player.inventory.count(tool_id) > 0 else MISSING_COLOR
		x = _text(font, Vector2(x, line_y), "нужно: " + _item_name(tool_id), FONT_SIZE, color)

	var right := _right_note(recipe_id, problem)
	var right_width := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var right_color := XP_COLOR if ready else MUTED_COLOR
	if problem == Crafting.Problem.BUILDING:
		right_color = COMFORT_COLOR
	_text(
		font,
		Vector2(rect.end.x - 6 - right_width, rect.position.y + 18),
		right,
		FONT_SIZE,
		right_color
	)
	if crafting.current == recipe_id:
		var bar := Rect2(rect.position.x, rect.end.y - 3, rect.size.x * crafting.progress(), 3)
		draw_rect(bar, PROGRESS_COLOR)


## Time and first-time experience, or why the recipe cannot be made.
func _right_note(recipe_id: String, problem: Crafting.Problem) -> String:
	match problem:
		Crafting.Problem.BUILDING:
			return _comfort_note(recipe_id)
		Crafting.Problem.SPACE:
			return "нет места"
	var note := "%s с" % str(crafting.time(recipe_id)).replace(".", ",")
	if crafting.is_first(recipe_id):
		note += " · +%d опыта" % int(crafting.recipes[recipe_id].xp)
	return note


## What a building adds to the camp: comfort, or nothing if the camp has better.
func _comfort_note(recipe_id: String) -> String:
	var camp: Camp = get_tree().get_first_node_in_group(Camp.GROUP)
	if camp == null or recipe_id not in GameData.table("comfort_items"):
		return "склад"
	var gain := camp.comfort_with(recipe_id) - camp.comfort()
	if gain <= 0:
		return "+0, уже есть лучше"
	return "+%d комфорта" % gain


func _item_name(item_id: String) -> String:
	return _items[item_id].name if item_id in _items else item_id


## Draws [param text] and returns the x where the next text can start.
func _text(font: Font, at: Vector2, text: String, font_size: int, color := Color.WHITE) -> float:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	return at.x + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
