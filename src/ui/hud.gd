extends CanvasLayer
## Screen bars and hints. The comfort bar is visible from the start:
## the starting campfire already gives minimal comfort.

@export var player: Player

@onready var _comfort_label: Label = $Comfort
@onready var _debug_label: Label = $Debug


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
