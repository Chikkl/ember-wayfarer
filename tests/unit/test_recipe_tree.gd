extends GutTest
## The recipe tree from docs/systems/tech-tree.md, "Дерево", with real data/recipe_tree.csv.

var tree: RecipeTree
var progression: Progression


func before_each() -> void:
	tree = RecipeTree.new(GameData.table("recipe_tree"))
	progression = Progression.new(GameData.params("progression"))


func _give_points(count: int) -> void:
	progression.points += count


func test_two_nodes_are_available_from_the_start() -> void:
	assert_eq(tree.state("stonework"), RecipeTree.State.AVAILABLE)
	assert_eq(tree.state("weaving"), RecipeTree.State.AVAILABLE)
	for node_id in ["carpentry", "shelter", "hut"]:
		assert_eq(tree.state(node_id), RecipeTree.State.LOCKED, node_id)


func test_opening_a_node_takes_a_point_and_unlocks_its_recipes() -> void:
	_give_points(1)
	watch_signals(tree)
	assert_true(tree.open("stonework", progression))
	assert_eq(progression.points, 0)
	assert_eq(tree.state("stonework"), RecipeTree.State.OPEN)
	assert_eq(tree.unlocked_recipes(), ["stone_axe"])
	assert_signal_emitted_with_parameters(tree, "node_opened", ["stonework"])
	assert_eq(tree.state("carpentry"), RecipeTree.State.AVAILABLE, "Its requirement is open")


func test_no_points_no_node() -> void:
	assert_false(tree.open("stonework", progression))
	assert_false(tree.is_open("stonework"))


func test_locked_or_open_node_does_not_open() -> void:
	_give_points(3)
	assert_false(tree.open("carpentry", progression), "Needs stonework first")
	assert_true(tree.open("stonework", progression))
	assert_false(tree.open("stonework", progression), "Already open")
	assert_eq(progression.points, 2, "Failed attempts cost nothing")


func test_hut_needs_shelter_and_weaving() -> void:
	_give_points(4)
	tree.open("stonework", progression)
	tree.open("shelter", progression)
	assert_eq(tree.state("hut"), RecipeTree.State.LOCKED, "Weaving is missing")
	tree.open("weaving", progression)
	assert_true(tree.open("hut", progression))


func test_starting_recipes_are_not_in_the_tree() -> void:
	_give_points(5)
	for node_id: String in tree.nodes:
		tree.open(node_id, progression)
	for recipe_id in ["chopper", "shaped_stick", "plait"]:
		assert_does_not_have(tree.unlocked_recipes(), recipe_id)


func test_depth_puts_nodes_into_columns() -> void:
	assert_eq(tree.depth("stonework"), 0)
	assert_eq(tree.depth("weaving"), 0)
	assert_eq(tree.depth("shelter"), 1)
	assert_eq(tree.depth("hut"), 2, "After shelter, which is after stonework")


func test_click_on_an_available_node_opens_it() -> void:
	var screen := TreeScreen.new()
	add_child_autofree(screen)
	screen.setup(tree, progression, GameData.table("recipes"))
	_give_points(1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen.get_global_transform().affine_inverse() * screen.node_center("weaving")
	screen._gui_input(click)
	assert_true(tree.is_open("weaving"))
	click.position = Vector2(-10, -10)
	screen._gui_input(click)
	assert_eq(progression.points, 0, "A click outside the nodes does nothing")


func test_lines_between_far_columns_stay_out_of_nodes() -> void:
	var size := TreeScreen.NODE_SIZE
	var gap := TreeScreen.GAP
	var weaving := Rect2(Vector2(0, size.y + gap.y), size)
	var shelter := Rect2(Vector2(size.x + gap.x, size.y + gap.y), size)
	var hut := Rect2(Vector2(2 * (size.x + gap.x), 0), size)
	var points := TreeScreen.edge_points(weaving, hut)
	for i in points.size() - 1:
		var middle := (points[i] + points[i + 1]) / 2.0
		assert_false(shelter.has_point(middle), "Segment %d passes through shelter" % i)
	assert_eq(points[-1], Vector2(hut.position.x, hut.get_center().y))


func test_points_word() -> void:
	var words: Array[String] = []
	for count in [1, 2, 5, 11, 21, 22]:
		words.append(TreeScreen.points_word(count))
	assert_eq(words, ["очко", "очка", "очков", "очков", "очко", "очка"])


func test_spend_points() -> void:
	_give_points(2)
	assert_true(progression.spend_points(2))
	assert_false(progression.spend_points(1))
	assert_eq(progression.points, 0)
