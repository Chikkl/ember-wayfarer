extends CanvasLayer
## Screen bars and hints. The comfort bar is visible from the start:
## the starting campfire already gives minimal comfort.

@export var player: Player

@onready var _comfort_label: Label = $Comfort
@onready var _debug_label: Label = $Debug
@onready var _inventory_label: Label = $Inventory


func _process(_delta: float) -> void:
	_comfort_label.text = "Комфорт: %d" % player.current_comfort()
	var stamina := player.stamina
	_debug_label.text = (
		"Выносливость %.0f / %.0f · усталость %.1f%s%s"
		% [
			stamina.value,
			stamina.available_max(),
			stamina.fatigue,
			" · истощение" if stamina.is_exhausted() else "",
			" · отдых" if player.is_resting else "",
		]
	)
	_inventory_label.text = "Несёшь: " + inventory_text(player.inventory, GameData.table("items"))


## Inventory as one line: "Ветка ×3 · Листья ×4", or a dash when it is empty.
static func inventory_text(inventory: Inventory, items: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item_id in inventory.item_ids():
		parts.append("%s ×%d" % [items[item_id].name, inventory.count(item_id)])
	return " · ".join(parts) if not parts.is_empty() else "—"
