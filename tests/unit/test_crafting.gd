extends GutTest
## Crafting from docs/systems/crafting.md with real data/recipes.csv.

var inventory: Inventory
var tree: RecipeTree
var crafting: Crafting


func before_each() -> void:
	inventory = Inventory.new(GameData.params("gathering"), GameData.table("items"))
	tree = RecipeTree.new(GameData.table("recipe_tree"))
	crafting = Crafting.new(GameData.table("recipes"), inventory, tree)


func _open(node_id: String) -> void:
	var progression := Progression.new(GameData.params("progression"))
	progression.points = 1
	tree.open(node_id, progression)


func test_starting_recipes_are_there_from_the_first_minute() -> void:
	assert_eq(crafting.available(), ["chopper", "shaped_stick", "plait"])


func test_open_nodes_add_their_recipes() -> void:
	_open("stonework")
	assert_has(crafting.available(), "stone_axe")
	_open("weaving")
	assert_has(crafting.available(), "bedroll")
	assert_eq(crafting.problem("bedroll"), Crafting.Problem.BUILDING, "Buildings come later")


func test_what_is_missing() -> void:
	assert_eq(crafting.problem("chopper"), Crafting.Problem.MATERIALS)
	inventory.add("stick")
	assert_eq(crafting.problem("shaped_stick"), Crafting.Problem.TOOL, "The chopper is needed")
	inventory.add("chopper")
	assert_eq(crafting.problem("shaped_stick"), Crafting.Problem.NONE)


func test_no_room_after_the_materials_are_taken() -> void:
	inventory.add("log", 7)
	inventory.add("stone", 3)
	inventory.add("leaves", 4)
	assert_eq(crafting.problem("plait"), Crafting.Problem.SPACE, "76 + 1 is over the cap of 75")
	inventory.remove("stone", 1)
	assert_eq(crafting.problem("plait"), Crafting.Problem.NONE)


func test_an_item_takes_its_time_and_the_materials_go_at_the_end() -> void:
	inventory.add("stone", 2)
	assert_true(crafting.start("chopper"))
	assert_eq(crafting.update(1.0), {})
	assert_eq(inventory.count("stone"), 2, "Nothing is taken before the end")
	assert_almost_eq(crafting.progress(), 0.5, 0.001)
	assert_eq(crafting.update(1.0), {"item_id": "chopper", "xp": 4})
	assert_eq(inventory.count("stone"), 0)
	assert_eq(inventory.count("chopper"), 1)
	assert_false(crafting.is_busy())


func test_experience_only_for_the_first_time() -> void:
	inventory.add("leaves", 8)
	crafting.start("plait")
	assert_eq(crafting.update(1.0).xp, 2)
	crafting.start("plait")
	assert_eq(crafting.update(1.0).xp, 0)
	assert_eq(inventory.count("plait"), 2)


func test_the_tool_stays() -> void:
	inventory.add("stick")
	inventory.add("chopper")
	crafting.start("shaped_stick")
	crafting.update(2.0)
	assert_eq(inventory.count("chopper"), 1)
	assert_eq(inventory.count("shaped_stick"), 1)


func test_the_axe_takes_the_chopper_stick_and_plait() -> void:
	_open("stonework")
	inventory.add("chopper")
	inventory.add("shaped_stick")
	inventory.add("plait")
	crafting.start("stone_axe")
	assert_eq(crafting.update(2.0), {"item_id": "stone_axe", "xp": 10})
	for item_id in ["chopper", "shaped_stick", "plait"]:
		assert_eq(inventory.count(item_id), 0, item_id)


func test_cancel_loses_nothing() -> void:
	inventory.add("stone", 2)
	crafting.start("chopper")
	crafting.update(1.5)
	crafting.cancel()
	assert_eq(inventory.count("stone"), 2)
	assert_eq(crafting.update(1.0), {})


func test_materials_gone_while_crafting_make_nothing() -> void:
	inventory.add("stone", 2)
	crafting.start("chopper")
	inventory.remove("stone", 1)
	assert_eq(crafting.update(2.0), {})
	assert_eq(inventory.count("chopper"), 0)
	assert_eq(inventory.count("stone"), 1)


func test_cannot_start_without_materials() -> void:
	assert_false(crafting.start("chopper"))
	assert_false(crafting.is_busy())
