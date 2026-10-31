class_name ComfortBadge
extends Control
## Camp comfort at the top left: a flame with a number. Outside the camp it fades.
## On hover it opens the comfort groups: the best item of each group and what it
## adds, so the player sees that one best item per group counts.
## Feedback rules: docs/systems/comfort.md, "Обратная связь игроку".
## Placeholder graphics until the art pass.

## Comfort groups of data/comfort_items.csv in the order they are listed.
const GROUP_NAMES := {"fire": "Огонь", "sleep": "Сон", "seat": "Сиденье", "shelter": "Укрытие"}
const BADGE_SIZE := Vector2(70, 34)
const NUMBER_SIZE := 22
const FONT_SIZE := 12
const OUTSIDE_ALPHA := 0.45
## The number glows this long after the camp comfort grows.
const PULSE_TIME := 0.8
const PANEL_TOP := 40.0
const PANEL_WIDTH := 290.0
const ROW_HEIGHT := 20.0
const PANEL_COLOR := Color(0.06, 0.07, 0.06, 0.9)
const NUMBER_COLOR := Color("ffd25e")
const MUTED_COLOR := Color(1, 1, 1, 0.55)
const FLAME_COLORS: Array[Color] = [Color("e8562a"), Color("f59a2c"), Color("ffd25e")]
const LEAF_COLOR := Color("5b8a3c")
const WOOD_COLOR := Color("6b4a2e")

var _player: Player
var _hovered := false
var _shown_comfort := -1
var _pulse := 0.0


func setup(player: Player) -> void:
	_player = player
	position = Vector2(12, 8)
	size = BADGE_SIZE
	mouse_filter = MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: _hovered = true)
	mouse_exited.connect(func() -> void: _hovered = false)


## Center of the badge on the screen, for a capture mode hover.
func center() -> Vector2:
	return get_global_rect().get_center()


func _camp() -> Camp:
	return get_tree().get_first_node_in_group(Camp.GROUP)


func _process(delta: float) -> void:
	var camp := _camp()
	if camp == null:
		return
	var comfort := camp.comfort()
	if _shown_comfort >= 0 and comfort > _shown_comfort:
		_pulse = PULSE_TIME
	_shown_comfort = comfort
	_pulse = maxf(_pulse - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var camp := _camp()
	if camp == null or _player == null:
		return
	var inside := camp.contains(_player.global_position)
	var alpha := 1.0 if inside else OUTSIDE_ALPHA
	_draw_flame(Vector2(14, 28), 1.0, alpha)
	var font := ThemeDB.fallback_font
	var glow := _pulse / PULSE_TIME
	var color := Color(NUMBER_COLOR.lightened(0.6 * glow), alpha)
	var number_size := NUMBER_SIZE + roundi(4 * glow)
	_text(font, Vector2(32, 27), str(camp.comfort()), number_size, color)
	if _hovered:
		_draw_panel(font, camp, inside)


## The comfort groups under the badge: the best item of each, or a dash.
func _draw_panel(font: Font, camp: Camp, inside: bool) -> void:
	var rows := GROUP_NAMES.size() + 2
	var panel := Rect2(0, PANEL_TOP, PANEL_WIDTH, 26 + rows * ROW_HEIGHT)
	draw_rect(panel, PANEL_COLOR)
	var title := "Комфорт лагеря: %d" % camp.comfort()
	if not inside:
		title += " · ты вне лагеря"
	_text(font, Vector2(10, PANEL_TOP + 20), title, FONT_SIZE, Color.WHITE)
	var best := camp.best_by_group()
	var items := GameData.table("comfort_items")
	var y := PANEL_TOP + 22 + ROW_HEIGHT
	for group: String in GROUP_NAMES:
		_draw_group_icon(group, Vector2(18, y - 4))
		var line := "%s: —" % GROUP_NAMES[group]
		var line_color := MUTED_COLOR
		if group in best:
			var row: Dictionary = items[best[group]]
			line = "%s: %s, +%d" % [GROUP_NAMES[group], row.name, int(row.comfort)]
			line_color = Color.WHITE
		_text(font, Vector2(34, y), line, FONT_SIZE, line_color)
		y += ROW_HEIGHT
	var rule := "Из каждой группы считается лучший предмет"
	_text(font, Vector2(10, y + 4), rule, FONT_SIZE - 1, MUTED_COLOR)


func _draw_flame(at: Vector2, scale_factor: float, alpha: float) -> void:
	for i in FLAME_COLORS.size():
		var height := (20.0 - i * 6.0) * scale_factor
		var half_width := (8.0 - i * 2.2) * scale_factor
		var flame := PackedVector2Array(
			[at + Vector2(-half_width, 0), at + Vector2(0, -height), at + Vector2(half_width, 0)]
		)
		draw_colored_polygon(flame, Color(FLAME_COLORS[i], alpha))


func _draw_group_icon(group: String, at: Vector2) -> void:
	match group:
		"fire":
			_draw_flame(at + Vector2(0, 6), 0.5, 1.0)
		"sleep":
			draw_rect(Rect2(at + Vector2(-8, -3), Vector2(16, 7)), LEAF_COLOR)
		"seat":
			draw_rect(Rect2(at + Vector2(-8, -2), Vector2(16, 6)), WOOD_COLOR)
		"shelter":
			var roof := PackedVector2Array(
				[at + Vector2(-8, 5), at + Vector2(0, -6), at + Vector2(8, 5)]
			)
			draw_colored_polygon(roof, LEAF_COLOR.darkened(0.1))


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(
		font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, color.a)
	)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
