class_name Hud
extends CanvasLayer
## Screen bars and hints. The comfort bar is visible from the start:
## the starting campfire already gives minimal comfort.

@export var player: Player

@onready var _comfort_label: Label = $Comfort
@onready var _debug_label: Label = $Debug
@onready var _hint_label: Label = $Hint
@onready var _inventory_bar: InventoryBar = $Inventory
@onready var _xp_bar: XpBar = $Experience


func _ready() -> void:
	_inventory_bar.setup(player.inventory)
	_inventory_bar.drop_requested.connect(player.drop_from_slot)
	_xp_bar.setup(player.progression)


## Capture mode keeps only the inventory and experience bars: the text lines
## are placeholders and debug values.
func hide_text() -> void:
	_comfort_label.hide()
	_debug_label.hide()
	_hint_label.hide()


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
