class_name FloatingText
extends Label
## Short text over the world that rises and fades: "+1 Ветка", "нужен инструмент".

const RISE_PX := 18.0
const LIFE_TIME := 0.9
const WIDTH_PX := 160.0
const FONT_SIZE := 12


## Shows [param text] centered over [param at] in [param parent] coordinates.
static func spawn(parent: Node, at: Vector2, text: String, color := Color.WHITE) -> void:
	var label := FloatingText.new()
	label.text = text
	label.modulate = color
	label.position = at - Vector2(WIDTH_PX / 2.0, 0)
	parent.add_child(label)


func _ready() -> void:
	z_index = 10
	size = Vector2(WIDTH_PX, FONT_SIZE * 2)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 3)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - RISE_PX, LIFE_TIME)
	tween.tween_property(self, "modulate:a", 0.0, LIFE_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
