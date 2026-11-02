class_name XpBar
extends Control
## Level, experience bar and unspent points at the top of the screen.
## Feedback rules: docs/systems/tech-tree.md, "Обратная связь игроку".

const WIDTH_PX := 240.0
const BAR_HEIGHT_PX := 8.0
const LABEL_HEIGHT_PX := 16.0
## The line with unspent points under the bar.
const POINTS_HEIGHT_PX := 18.0
const TOP_MARGIN_PX := 12
const FONT_SIZE := 12
## Share of the bar the shown fill moves per second towards the real one.
const FILL_SPEED := 1.5
const BACK_COLOR := Color(0.1, 0.1, 0.1, 0.55)
const XP_COLOR := Color("6fb7e8")
const POINTS_COLOR := Color("ffd25e")

var progression: Progression

var _shown := 0.0
var _shown_level := 1


func setup(player_progression: Progression) -> void:
	progression = player_progression
	_shown_level = progression.level
	size = Vector2(WIDTH_PX, LABEL_HEIGHT_PX + BAR_HEIGHT_PX + POINTS_HEIGHT_PX)
	set_anchors_and_offsets_preset(PRESET_CENTER_TOP, PRESET_MODE_KEEP_SIZE, TOP_MARGIN_PX)
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if progression == null:
		return
	if progression.level != _shown_level:
		_shown_level = progression.level
		_shown = 0.0
	var target := float(progression.xp) / progression.threshold(progression.level)
	_shown = move_toward(_shown, target, FILL_SPEED * delta)
	queue_redraw()


func _draw() -> void:
	if progression == null:
		return
	var font := ThemeDB.fallback_font
	var threshold := progression.threshold(progression.level)
	_draw_text(font, Vector2(0, LABEL_HEIGHT_PX - 4), "Уровень %d" % progression.level)
	var numbers := "%d / %d" % [progression.xp, threshold]
	var numbers_width := font.get_string_size(numbers, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_draw_text(font, Vector2(size.x - numbers_width, LABEL_HEIGHT_PX - 4), numbers)
	var bar := Rect2(0, LABEL_HEIGHT_PX, size.x, BAR_HEIGHT_PX)
	draw_rect(bar, BACK_COLOR)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _shown, bar.size.y)), XP_COLOR)
	if progression.points > 0:
		var points := "Очки развития: %d · T — дерево" % progression.points
		var points_x := (size.x - font.get_string_size(points, 0, -1, FONT_SIZE).x) / 2.0
		_draw_text(font, Vector2(points_x, size.y - 2), points, POINTS_COLOR)


func _draw_text(font: Font, at: Vector2, text: String, color := Color.WHITE) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
