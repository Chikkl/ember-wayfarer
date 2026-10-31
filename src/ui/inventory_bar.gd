class_name InventoryBar
extends SlotGrid
## Inventory slots and the load bar at the bottom of the screen.
## Mouse rules for the slots: see SlotGrid.
## Feedback rules: docs/systems/gathering.md, "Обратная связь игроку".

const BAR_HEIGHT_PX := 8.0
const LABEL_HEIGHT_PX := 16.0
const BOTTOM_MARGIN_PX := 12
const LOAD_COLOR := Color("8fd14f")
const OVERLOAD_COLOR := Color("f0a040")
const CAP_COLOR := Color("e04a3a")
const LIMIT_MARK_COLOR := Color(1, 1, 1, 0.8)


func setup(player_inventory: Inventory) -> void:
	show_inventory(player_inventory)
	set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM, PRESET_MODE_KEEP_SIZE, BOTTOM_MARGIN_PX)


func _slots_top() -> float:
	return LABEL_HEIGHT_PX + BAR_HEIGHT_PX + GAP_PX


func _draw_header(font: Font) -> void:
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
