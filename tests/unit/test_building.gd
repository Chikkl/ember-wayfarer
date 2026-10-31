extends GutTest
## Blueprints and buildings from docs/systems/crafting.md, "Постройки",
## with real data/recipes.csv and data/buildings.csv.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const FIRE_SCENE := preload("res://src/camp/campfire.tscn")
const NODE_SCENE := preload("res://src/world/resource_node.tscn")
const FPS := 60

var world: Node2D
var inventory: Inventory


func before_each() -> void:
	world = Node2D.new()
	add_child_autofree(world)
	inventory = Inventory.new(GameData.params("gathering"), GameData.table("items"))


func after_each() -> void:
	Input.action_release("interact")


func _blueprint(recipe_id: String, at := Vector2.ZERO) -> Building:
	var building := Building.blueprint(recipe_id, at)
	world.add_child(building)
	return building


func test_footprint_stands_on_its_bottom_center() -> void:
	var bedroll := _blueprint("bedroll", Vector2(100, 200))
	assert_eq(bedroll.footprint(), Rect2(Vector2(68, 168), Vector2(64, 32)), "2 by 1 tiles")
	assert_eq(bedroll.distance_to(Vector2(100, 190)), 0.0, "Inside")
	assert_eq(bedroll.distance_to(Vector2(100, 210)), 10.0, "Below the bottom edge")


func test_materials_go_in_and_the_share_counts_by_weight() -> void:
	var bedroll := _blueprint("bedroll")
	inventory.add("stick", 6)
	assert_eq(bedroll.deliver_from(inventory), {"stick": 4}, "Only what is needed")
	assert_eq(inventory.count("stick"), 2)
	assert_eq(bedroll.missing(), {"plait": 3, "leaves": 10})
	assert_almost_eq(bedroll.delivered_share(), 4.0 / 17.0, 0.001, "4 of 17 by weight")


func test_assembly_starts_only_when_all_is_in() -> void:
	var seat := _blueprint("log_seat")
	assert_false(seat.assemble(5.0), "No log yet")
	assert_eq(seat.assembled, 0.0)
	inventory.add("log")
	seat.deliver_from(inventory)
	assert_false(seat.assemble(1.0))
	assert_almost_eq(seat.progress(), 1.0 / 1.5, 0.001, "The ring shows the assembly now")
	assert_true(seat.assemble(0.5), "1.5 s of assembly")


func test_a_finished_comfort_building_counts_for_the_camp() -> void:
	var bedroll := _blueprint("bedroll")
	assert_false(bedroll.is_in_group(ComfortItem.GROUP), "A blueprint gives no comfort")
	bedroll.complete()
	assert_false(bedroll.is_blueprint)
	assert_true(bedroll.is_in_group(ComfortItem.GROUP))
	var basket := _blueprint("basket", Vector2(200, 0))
	basket.complete()
	assert_false(basket.is_in_group(ComfortItem.GROUP), "The basket is storage, not comfort")


func test_camp_comfort_with_one_more_item() -> void:
	var fire: Node2D = FIRE_SCENE.instantiate()
	world.add_child(fire)
	var camp: Camp = fire.get_node("Camp")
	assert_eq(camp.comfort(), 2)
	assert_eq(camp.comfort_with("bedroll"), 4)
	assert_eq(camp.comfort_with("campfire"), 2, "The fire group already has a fire")


func test_building_experience_only_for_the_first_time() -> void:
	var tree := RecipeTree.new(GameData.table("recipe_tree"))
	var crafting := Crafting.new(GameData.table("recipes"), inventory, tree)
	assert_eq(crafting.finish_building("hut"), 25)
	assert_eq(crafting.finish_building("hut"), 0)


func test_blueprint_needs_free_ground_near_the_player() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	var fire: Node2D = FIRE_SCENE.instantiate()
	fire.position = Vector2(-300, 0)
	world.add_child(fire)
	var tree: ResourceNode = NODE_SCENE.instantiate()
	tree.node_id = "tree"
	tree.position = Vector2(80, 16)
	world.add_child(tree)
	var mode := BuildMode.new()
	world.add_child(mode)
	mode.setup(player, fire)
	await wait_physics_frames(2)
	assert_true(mode.can_place(Rect2(-64, 32, 32, 32)), "Clear ground")
	assert_false(mode.can_place(Rect2(64, 0, 32, 32)), "The tree base is there")
	assert_false(mode.can_place(Rect2(-16, -16, 32, 32)), "The player stands there")
	assert_false(mode.can_place(Rect2(320, 0, 32, 32)), "Farther than 4 tiles")


func test_holding_e_delivers_and_builds() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.inventory.add("log")
	var seat := _blueprint("log_seat", Vector2(0, 40))
	Input.action_press("interact")
	await wait_physics_frames(roundi(1.7 * FPS))
	Input.action_release("interact")
	assert_false(seat.is_blueprint, "Delivered and assembled in 1.5 s")
	assert_eq(player.inventory.count("log"), 0)
	assert_eq(player.progression.xp, 4, "First seat")


func test_no_materials_no_progress() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	var seat := _blueprint("log_seat", Vector2(0, 40))
	Input.action_press("interact")
	await wait_physics_frames(roundi(2.0 * FPS))
	Input.action_release("interact")
	assert_true(seat.is_blueprint)
	assert_eq(seat.assembled, 0.0)
