extends GutTest
## Player rules from docs/systems/movement-stamina.md: facing and rest state.


func test_facing_keeps_current_when_standing() -> void:
	assert_eq(Player.facing_for(Vector2.ZERO, Player.Facing.UP), Player.Facing.UP)


func test_facing_four_sides() -> void:
	assert_eq(Player.facing_for(Vector2.LEFT, Player.Facing.DOWN), Player.Facing.LEFT)
	assert_eq(Player.facing_for(Vector2.RIGHT, Player.Facing.DOWN), Player.Facing.RIGHT)
	assert_eq(Player.facing_for(Vector2.UP, Player.Facing.DOWN), Player.Facing.UP)
	assert_eq(Player.facing_for(Vector2.DOWN, Player.Facing.UP), Player.Facing.DOWN)


func test_diagonals_face_left_or_right() -> void:
	assert_eq(Player.facing_for(Vector2(-1, -1), Player.Facing.DOWN), Player.Facing.LEFT)
	assert_eq(Player.facing_for(Vector2(1, 1), Player.Facing.DOWN), Player.Facing.RIGHT)


func test_slight_stick_tilt_keeps_vertical_facing() -> void:
	var nearly_up := Vector2(0.1, -0.99)
	assert_eq(Player.facing_for(nearly_up, Player.Facing.DOWN), Player.Facing.UP)


func test_rest_button_toggles_sitting() -> void:
	assert_true(Player.next_resting(false, Vector2.ZERO, true))
	assert_false(Player.next_resting(true, Vector2.ZERO, true))
	assert_true(Player.next_resting(true, Vector2.ZERO, false), "Sitting stays without input")


func test_any_movement_stands_up() -> void:
	assert_false(Player.next_resting(true, Vector2(0.3, 0), false))
	assert_false(Player.next_resting(true, Vector2(0, 1), true), "Movement wins over the button")
