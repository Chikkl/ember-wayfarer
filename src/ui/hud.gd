class_name Hud
extends CanvasLayer
## Screen bars and hints. The comfort badge is visible from the start:
## the starting campfire already gives minimal comfort.

const STEP_DONE_TEXT := "Шаг 1 пройден: первое жилище под крышей"
## Seconds the step finale line stays before it fades.
const BANNER_TIME := 5.0

@export var player: Player
@export var build_mode: BuildMode

@onready var _comfort_badge: ComfortBadge = $Comfort
@onready var _debug_label: Label = $Debug
@onready var _hint_label: Label = $Hint
@onready var _inventory_bar: InventoryBar = $Inventory
@onready var _xp_bar: XpBar = $Experience
@onready var _tree_screen: TreeScreen = $Tree
@onready var _craft_menu: CraftMenu = $Craft


func _ready() -> void:
	_inventory_bar.setup(player.inventory)
	_inventory_bar.drop_requested.connect(player.drop_from_slot)
	_xp_bar.setup(player.progression)
	_comfort_badge.setup(player)
	_tree_screen.setup(player.recipe_tree, player.progression, GameData.table("recipes"))
	_craft_menu.setup(player, GameData.table("items"))
	_craft_menu.build_requested.connect(_on_build_requested)
	player.step_completed.connect(_on_step_completed)


## The screens read the same actions as the player, in the physics frame,
## so capture mode can open them too. One screen at a time: they overlap.
func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("tree"):
		_craft_menu.close()
		_tree_screen.toggle()
	elif Input.is_action_just_pressed("craft"):
		_tree_screen.hide()
		_craft_menu.toggle()
	elif Input.is_action_just_pressed("ui_cancel"):
		_tree_screen.hide()
		_craft_menu.close()
		build_mode.stop()


func _on_build_requested(recipe_id: String) -> void:
	_craft_menu.close()
	build_mode.start(recipe_id)


## The finale of step 1: a line at the top that fades after a while.
func _on_step_completed() -> void:
	var banner := Label.new()
	banner.text = STEP_DONE_TEXT
	banner.add_theme_font_size_override("font_size", 22)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 5)
	banner.add_theme_color_override("font_color", Color("ffd25e"))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 70
	add_child(banner)
	var tween := banner.create_tween()
	tween.tween_interval(BANNER_TIME)
	tween.tween_property(banner, "modulate:a", 0.0, 1.0)
	tween.tween_callback(banner.queue_free)


## The recipe tree screen, for capture mode clicks.
func tree_screen() -> TreeScreen:
	return _tree_screen


## The crafting menu, for capture mode clicks.
func craft_menu() -> CraftMenu:
	return _craft_menu


## The comfort badge, for a capture mode hover.
func comfort_badge() -> ComfortBadge:
	return _comfort_badge


## Capture mode keeps the bars and the comfort badge: the text lines are debug
## values and the controls hint.
func hide_text() -> void:
	_debug_label.hide()
	_hint_label.hide()


func _process(_delta: float) -> void:
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
