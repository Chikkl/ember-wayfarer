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


func _solid_at(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	return not world.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func test_only_the_base_stops_the_player_and_a_seat_has_none() -> void:
	_blueprint("log_seat").complete()
	_blueprint("basket", Vector2(100, 0)).complete()
	_blueprint("hut", Vector2(300, 0))
	await wait_physics_frames(2)
	assert_false(_solid_at(Vector2(0, -16)), "The seat lets the player through")
	assert_true(_solid_at(Vector2(100, -16)), "The basket is solid")
	assert_true(_solid_at(Vector2(300, -16)), "The hut base, a blueprint too")
	assert_false(_solid_at(Vector2(300, -80)), "Behind the hut, above its base")


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


func test_blueprint_keeps_off_sticks_stones_and_piles() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	var fire := Node2D.new()
	world.add_child(fire)
	var stick: ResourceNode = NODE_SCENE.instantiate()
	stick.node_id = "ground_stick"
	stick.position = Vector2(-48, 48)
	world.add_child(stick)
	var pile := GroundItem.new()
	pile.item_id = "stone"
	pile.position = Vector2(48, 48)
	pile.land_at = pile.position
	world.add_child(pile)
	var mode := BuildMode.new()
	world.add_child(mode)
	mode.setup(player, fire)
	await wait_physics_frames(2)
	assert_false(mode.can_place(Rect2(-64, 32, 32, 32)), "A stick lies there")
	assert_true(mode.can_place(Rect2(-64, 64, 32, 32)), "Next to the stick")
	assert_false(mode.can_place(Rect2(32, 32, 32, 32)), "A pile lies there")


func test_a_seat_takes_its_tile_though_the_player_walks_through() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	var fire := Node2D.new()
	world.add_child(fire)
	_blueprint("log_seat", Vector2(-48, 64)).complete()
	var mode := BuildMode.new()
	world.add_child(mode)
	mode.setup(player, fire)
	await wait_physics_frames(2)
	assert_false(mode.can_place(Rect2(-64, 32, 32, 32)), "The seat stands there")
	assert_true(mode.can_place(Rect2(-32, 32, 32, 32)), "Right next to the seat")


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


func test_taking_down_gives_back_what_went_in() -> void:
	var lean_to := _blueprint("lean_to")
	inventory.add("log", 2)
	lean_to.deliver_from(inventory)
	assert_eq(lean_to.refund(1.0), {"log": 2}, "A blueprint gives back what was delivered")
	lean_to.complete()
	assert_eq(lean_to.refund(1.0), {"log": 2, "stick": 6, "plait": 2, "leaves": 8})
	assert_eq(lean_to.refund(0.5), {"log": 1, "stick": 3, "plait": 1, "leaves": 4})


func _dismantling_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	var fire := Node2D.new()
	world.add_child(fire)
	var mode := BuildMode.new()
	world.add_child(mode)
	mode.setup(player, fire)
	mode.start_dismantle()
	player.build_mode = mode
	return player


func test_holding_e_in_the_mode_takes_a_building_down() -> void:
	var player := _dismantling_player()
	var seat := _blueprint("log_seat", Vector2(0, 40))
	seat.complete()
	Input.action_press("interact")
	await wait_physics_frames(roundi(1.2 * FPS))
	Input.action_release("interact")
	assert_false(is_instance_valid(seat) and seat.is_inside_tree(), "Taken down in 1 s")
	assert_eq(player.inventory.count("log"), 1, "The log is back")


func test_what_does_not_fit_falls_on_the_ground() -> void:
	var player := _dismantling_player()
	player.inventory.add("log", 7)
	player.inventory.add("stone", 2)
	var seat := _blueprint("log_seat", Vector2(0, 40))
	seat.complete()
	Input.action_press("interact")
	await wait_physics_frames(roundi(1.2 * FPS))
	Input.action_release("interact")
	assert_eq(player.inventory.count("log"), 7, "74 of 75: the log does not fit")
	var piles := world.get_children().filter(func(node: Node) -> bool: return node is GroundItem)
	assert_eq(piles.size(), 1)
