class_name BasketPanel
extends SlotGrid
## The open basket, just above the inventory bar. Mouse rules: see SlotGrid.
## Rules: docs/systems/gathering.md, "Корзина".

const TITLE_HEIGHT_PX := 18.0
## Space between the panel and the inventory bar under it.
const BAR_GAP_PX := 10.0


## Opens the panel on [param storage] of a basket.
func open(storage: Inventory) -> void:
	show_inventory(storage)
	var bar_height := InventoryBar.LABEL_HEIGHT_PX + InventoryBar.BAR_HEIGHT_PX + GAP_PX
	bar_height += 2 * (SLOT_PX + GAP_PX)
	var margin := InventoryBar.BOTTOM_MARGIN_PX + roundi(bar_height + BAR_GAP_PX)
	set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM, PRESET_MODE_KEEP_SIZE, margin)
	show()


func _slots_top() -> float:
	return TITLE_HEIGHT_PX


func _draw_header(font: Font) -> void:
	_draw_text(font, Vector2(0, TITLE_HEIGHT_PX - 5), "Корзина · Shift+ЛКМ — переложить")
