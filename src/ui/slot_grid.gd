class_name SlotGrid
extends Control
## Slots of an inventory drawn as a grid, with the mouse rules shared by the
## inventory bar and the basket: the left button drags a stack to another slot
## or out of the panels onto the ground, the right button drops one item, Shift
## and the left button move a stack to the other open grid.
## Rules: docs/systems/gathering.md, "Инвентарь", rule 7.


## The dragged stack under the cursor.
class StackPreview:
	extends Control

	var item_id := ""
	var count := 0

	func _draw() -> void:
		ItemIcon.draw(self, item_id, Vector2(0, 8), SlotGrid.ICON_SCALE)
		if count > 1:
			var font := ThemeDB.fallback_font
			var at := Vector2(6, 16)
			draw_string_outline(
				font,
				at,
				str(count),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				SlotGrid.FONT_SIZE,
				3,
				Color.BLACK
			)
			draw_string(font, at, str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, SlotGrid.FONT_SIZE)


## A stack goes to the ground: one item, or the whole stack dragged out of the panels.
signal drop_requested(index: int, whole_stack: bool)
## Shift and the left button: the stack goes to the other open grid.
signal quick_move_requested(index: int)

const COLUMNS := 8
const SLOT_PX := 40.0
const GAP_PX := 4.0
const FONT_SIZE := 12
const ICON_SCALE := 2.0
const SLOT_COLOR := Color(0.1, 0.1, 0.1, 0.55)
const SLOT_BORDER_COLOR := Color(1, 1, 1, 0.15)

var inventory: Inventory

## The slot being dragged, -1 if none.
var _dragging_index := -1
## The cursor on the screen from the latest mouse event. Drops use it instead of
## the system cursor, so capture mode drags land where its events point.
var _cursor := Vector2.ZERO


## Shows [param slots_of]: the grid takes the size its slots need.
func show_inventory(slots_of: Inventory) -> void:
	inventory = slots_of
	var rows := ceili(float(inventory.slots.size()) / COLUMNS)
	size = Vector2(grid_width(), _slots_top() + rows * (SLOT_PX + GAP_PX))


static func grid_width() -> float:
	return COLUMNS * SLOT_PX + (COLUMNS - 1) * GAP_PX


func slot_rect(index: int) -> Rect2:
	var column := index % COLUMNS
	var row := floori(float(index) / COLUMNS)
	var top_left := Vector2(column * (SLOT_PX + GAP_PX), _slots_top() + row * (SLOT_PX + GAP_PX))
	return Rect2(top_left, Vector2(SLOT_PX, SLOT_PX))


## Index of the slot under [param point] in local coordinates, or -1.
func slot_at(point: Vector2) -> int:
	if inventory == null:
		return -1
	for i in inventory.slots.size():
		if slot_rect(i).has_point(point):
			return i
	return -1


## Center of slot [param index] on the screen, for capture mode clicks.
func slot_center(index: int) -> Vector2:
	return get_global_transform() * slot_rect(index).get_center()


## Height of the header above the slots.
func _slots_top() -> float:
	return 0.0


func _draw_header(_font: Font) -> void:
	pass


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	var index := slot_at(click.position)
	if index < 0 or inventory.slots[index].is_empty():
		return
	if click.button_index == MOUSE_BUTTON_RIGHT:
		drop_requested.emit(index, false)
		accept_event()
	elif click.button_index == MOUSE_BUTTON_LEFT and click.shift_pressed:
		quick_move_requested.emit(index)
		accept_event()


func _get_drag_data(at_position: Vector2) -> Variant:
	var index := slot_at(at_position)
	if index < 0 or inventory.slots[index].is_empty():
		return null
	_dragging_index = index
	var preview := StackPreview.new()
	preview.item_id = inventory.slots[index].item_id
	preview.count = inventory.slots[index].count
	set_drag_preview(preview)
	return {"grid": self, "index": index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("grid") and _slot_under_cursor() >= 0


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source: SlotGrid = data.grid
	SlotMoves.move(source.inventory, data.index, inventory, _slot_under_cursor())


func _slot_under_cursor() -> int:
	return slot_at(get_global_transform().affine_inverse() * _cursor)


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_cursor = event.position


## A stack let go outside every slot falls on the ground.
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or _dragging_index < 0:
		return
	if not get_viewport().gui_is_drag_successful():
		drop_requested.emit(_dragging_index, true)
	_dragging_index = -1


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if inventory == null:
		return
	var font := ThemeDB.fallback_font
	_draw_header(font)
	for i in inventory.slots.size():
		var rect := slot_rect(i)
		draw_rect(rect, SLOT_COLOR)
		draw_rect(rect, SLOT_BORDER_COLOR, false, 1.0)
		var slot := inventory.slots[i]
		if slot.is_empty():
			continue
		ItemIcon.draw(self, slot.item_id, rect.get_center() + Vector2(0, 8), ICON_SCALE)
		if slot.count > 1:
			_draw_text(font, rect.end - Vector2(14, 4), str(slot.count))


func _draw_text(font: Font, at: Vector2, text: String) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
