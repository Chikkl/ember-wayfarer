class_name InventoryBar
extends Control
## Inventory slots and the load bar at the bottom of the screen.
## Left click drops one item from a slot, right click drops the whole stack.
## Feedback rules: docs/systems/gathering.md, "Обратная связь игроку".

signal drop_requested(index: int, whole_stack: bool)

const COLUMNS := 8
const SLOT_PX := 40.0
const GAP_PX := 4.0
const BAR_HEIGHT_PX := 8.0
const LABEL_HEIGHT_PX := 16.0
const BOTTOM_MARGIN_PX := 12
const FONT_SIZE := 12
const ICON_SCALE := 2.0
const SLOT_COLOR := Color(0.1, 0.1, 0.1, 0.55)
const SLOT_BORDER_COLOR := Color(1, 1, 1, 0.15)
const LOAD_COLOR := Color("8fd14f")
const OVERLOAD_COLOR := Color("f0a040")
const CAP_COLOR := Color("e04a3a")
const LIMIT_MARK_COLOR := Color(1, 1, 1, 0.8)

var inventory: Inventory


func setup(player_inventory: Inventory) -> void:
	inventory = player_inventory
	var rows := ceili(float(inventory.slots.size()) / COLUMNS)
	size = Vector2(
		COLUMNS * SLOT_PX + (COLUMNS - 1) * GAP_PX, _slots_top() + rows * (SLOT_PX + GAP_PX)
	)
	set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM, PRESET_MODE_KEEP_SIZE, BOTTOM_MARGIN_PX)


func slot_rect(index: int) -> Rect2:
	var column := index % COLUMNS
	var row := floori(float(index) / COLUMNS)
	var top_left := Vector2(column * (SLOT_PX + GAP_PX), _slots_top() + row * (SLOT_PX + GAP_PX))
	return Rect2(top_left, Vector2(SLOT_PX, SLOT_PX))


## Index of the slot under [param point] in local coordinates, or -1.
func slot_at(point: Vector2) -> int:
	for i in inventory.slots.size():
		if slot_rect(i).has_point(point):
			return i
	return -1


func _slots_top() -> float:
	return LABEL_HEIGHT_PX + BAR_HEIGHT_PX + GAP_PX


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	var index := slot_at(click.position)
	if index >= 0:
		drop_requested.emit(index, click.button_index == MOUSE_BUTTON_RIGHT)
		accept_event()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if inventory == null:
		return
	var font := ThemeDB.fallback_font
	var weight := inventory.carried_weight()
	var limit := inventory.carry_limit()
	var cap := inventory.carry_cap()
	var label := "Груз %d / %d" % [roundi(weight), roundi(limit)]
	_draw_text(font, Vector2(0, LABEL_HEIGHT_PX - 4), label)

	var bar := Rect2(0, LABEL_HEIGHT_PX, size.x, BAR_HEIGHT_PX)
	draw_rect(bar, SLOT_COLOR)
	var color := LOAD_COLOR
	if weight >= cap:
		color = CAP_COLOR
	elif weight > limit:
		color = OVERLOAD_COLOR
	var filled := Vector2(bar.size.x * clampf(weight / cap, 0.0, 1.0), bar.size.y)
	draw_rect(Rect2(bar.position, filled), color)
	var limit_x := bar.size.x * limit / cap
	draw_line(
		Vector2(limit_x, bar.position.y - 2), Vector2(limit_x, bar.end.y + 2), LIMIT_MARK_COLOR, 1.5
	)

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
