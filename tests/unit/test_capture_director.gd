extends GutTest
## Capture mode from docs/captures.md: launch argument, walking input and takes.


func after_each() -> void:
	for action in CaptureDirector.HELD_ACTIONS:
		Input.action_release(action)


func test_take_comes_from_user_args() -> void:
	var args := PackedStringArray(["--verbose", "--capture=reel-intro"])
	assert_eq(CaptureDirector.take_from_args(args), "reel-intro")


func test_no_capture_argument_means_normal_game() -> void:
	assert_eq(CaptureDirector.take_from_args(PackedStringArray()), "")
	assert_eq(CaptureDirector.take_from_args(PackedStringArray(["--verbose"])), "")


func test_move_strengths_straight_and_standing() -> void:
	var right := CaptureDirector.move_strengths(Vector2(5, 0))
	assert_eq(right, {"move_left": 0.0, "move_right": 1.0, "move_up": 0.0, "move_down": 0.0})
	var still := CaptureDirector.move_strengths(Vector2.ZERO)
	assert_eq(still.values(), [0.0, 0.0, 0.0, 0.0])


func test_move_strengths_walk_at_full_speed_toward_the_direction() -> void:
	var direction := Vector2(-3, 1).normalized()
	var strengths := CaptureDirector.move_strengths(direction * 40.0)
	for action: String in strengths:
		if strengths[action] > 0.0:
			Input.action_press(action, strengths[action])
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	assert_almost_eq(input.x, direction.x, 0.001)
	assert_almost_eq(input.y, direction.y, 0.001)


func test_every_take_is_valid() -> void:
	for take: String in CaptureTakes.ALL:
		var problems := CaptureDirector.take_problems(CaptureTakes.ALL[take])
		assert_true(problems.is_empty(), "%s: %s" % [take, problems])


func test_take_problems_name_unknown_steps_targets_and_items() -> void:
	var take := {
		"items": {"golden_axe": 1},
		"steps":
		[
			{"do": "dance"},
			{"do": "walk_to", "target": "castle"},
			{"do": "work", "until": "dawn"},
			{"do": "walk_to", "target": "fire"},
		],
	}
	assert_eq(CaptureDirector.take_problems(take).size(), 4)
