extends GutTest
## Moving stacks between the inventory and a basket, docs/systems/gathering.md,
## "Инвентарь", rule 7, and "Корзина".

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const FPS := 60

var inventory: Inventory
var basket: Inventory


func before_each() -> void:
	inventory = Inventory.new(GameData.params("gathering"), GameData.table("items"))
	var params := GameData.params("gathering").duplicate()
	params.inventory_slots = params.basket_slots
	basket = Inventory.new(params, GameData.table("items"))
	basket.limit_weight = false


func after_each() -> void:
	Input.action_release("interact")


func test_a_stack_moves_into_an_empty_slot() -> void:
	inventory.add("stick", 5)
	assert_eq(SlotMoves.move(inventory, 0, inventory, 3), 5)
	assert_eq(inventory.slots[0], {})
	assert_eq(inventory.slots[3], {"item_id": "stick", "count": 5})


func test_the_same_items_merge_up_to_stack_max() -> void:
	inventory.add("log", 20)
	inventory.add("log", 15)
	assert_eq(SlotMoves.move(inventory, 1, inventory, 0), 0, "The first stack is full")
	assert_eq(SlotMoves.move(inventory, 0, inventory, 1), 5, "Only 5 more fit on 15")
	assert_eq(inventory.slots[1].count, 20)
	assert_eq(inventory.slots[0].count, 15)


func test_different_items_swap_places() -> void:
	inventory.add("stick", 3)
	inventory.add("stone", 2)
	SlotMoves.move(inventory, 0, inventory, 1)
	assert_eq(inventory.slots[0], {"item_id": "stone", "count": 2})
	assert_eq(inventory.slots[1], {"item_id": "stick", "count": 3})


func test_a_basket_takes_any_weight() -> void:
	basket.add("log", 20)
	assert_eq(basket.carry_amount("log", 20), 20, "No load cap in a basket")


func test_from_the_basket_only_what_the_load_allows() -> void:
	inventory.add("log", 7)
	basket.add("log", 5)
	assert_eq(SlotMoves.move(basket, 0, inventory, 1), 0, "70 of 75: a log does not fit")
	inventory.remove("log", 2)
	assert_eq(SlotMoves.move(basket, 0, inventory, 1), 2, "50 of 75: two logs fit")
	assert_eq(basket.slots[0].count, 3)


func test_a_swap_that_breaks_the_load_cap_does_not_happen() -> void:
	inventory.add("log", 7)
	inventory.add("stick")
	basket.add("log", 5)
	assert_eq(SlotMoves.move(basket, 0, inventory, 1), 0, "5 logs for a stick: 119 of 75")
	assert_eq(inventory.slots[1], {"item_id": "stick", "count": 1})


func test_shift_moves_a_stack_onto_the_stacks_first() -> void:
	basket.add("stick", 3)
	inventory.add("stone")
	inventory.add("stick", 4)
	assert_eq(SlotMoves.quick_move(inventory, 1, basket), 4)
	assert_eq(basket.slots[0], {"item_id": "stick", "count": 7})


func _built_basket(world: Node2D, at: Vector2) -> Building:
	var building := Building.blueprint("basket", at)
	world.add_child(building)
	building.complete()
	return building


func test_a_basket_with_things_cannot_be_taken_down() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var building := _built_basket(world, Vector2.ZERO)
	assert_true(building.can_dismantle())
	building.storage.add("stick")
	assert_false(building.can_dismantle())


func test_e_opens_the_nearest_basket_and_walking_away_closes_it() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var player: Player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	var building := _built_basket(world, Vector2(0, 40))
	watch_signals(player)
	Input.action_press("interact")
	await wait_physics_frames(2)
	Input.action_release("interact")
	assert_eq(player.open_basket, building)
	assert_signal_emitted(player, "basket_opened")
	player.position = Vector2(300, 0)
	await wait_physics_frames(2)
	assert_null(player.open_basket)
	assert_signal_emitted(player, "basket_closed")
