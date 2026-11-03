extends GutTest
## Hits and loot from docs/systems/gathering.md, "Действия", with real data/resource_nodes.csv.

var nodes: Dictionary
var tools: Dictionary


func before_each() -> void:
	nodes = GameData.table("resource_nodes")
	tools = GameData.table("tools")


func _inventory() -> Inventory:
	return Inventory.new(GameData.params("gathering"), GameData.table("items"))


func _hit_all(harvest: NodeHarvest) -> Array[Dictionary]:
	var loot: Array[Dictionary] = []
	while not harvest.is_depleted():
		loot.append(harvest.hit())
	return loot


func test_bush_gives_loot_on_every_hit() -> void:
	var loot := _hit_all(NodeHarvest.new(nodes.bush))
	assert_eq(loot, [{"leaves": 2}, {"leaves": 2}, {"leaves": 2}])


func test_tree_gives_everything_on_the_last_hit() -> void:
	var loot := _hit_all(NodeHarvest.new(nodes.tree))
	assert_eq(loot, [{}, {}, {}, {}, {}, {"log": 3, "stick": 2}])


func test_stick_on_the_ground_takes_one_free_hit() -> void:
	var harvest := NodeHarvest.new(nodes.ground_stick)
	assert_eq(harvest.stamina_cost, 0.0)
	assert_eq(harvest.hit(), {"stick": 1})
	assert_true(harvest.is_depleted())


func test_depleted_node_gives_nothing() -> void:
	var harvest := NodeHarvest.new(nodes.stump)
	_hit_all(harvest)
	assert_eq(harvest.hit(), {})
	assert_eq(harvest.hits_left, 0.0)


func test_tree_takes_the_strongest_tool_in_the_inventory() -> void:
	var harvest := NodeHarvest.new(nodes.tree)
	var inventory := _inventory()
	assert_eq(harvest.best_tool(inventory, tools), "", "Bare hands do not fell a tree")
	inventory.add("chopper")
	assert_eq(harvest.best_tool(inventory, tools), "chopper")
	inventory.add("stone_axe")
	assert_eq(harvest.best_tool(inventory, tools), "stone_axe", "The axe strikes harder")


func test_only_the_axe_uproots_a_stump() -> void:
	var harvest := NodeHarvest.new(nodes.stump)
	var inventory := _inventory()
	inventory.add("chopper")
	assert_eq(harvest.best_tool(inventory, tools), "")
	inventory.add("stone_axe")
	assert_eq(harvest.best_tool(inventory, tools), "stone_axe")


func test_hands_and_pickup_need_no_tool() -> void:
	var inventory := _inventory()
	assert_eq(NodeHarvest.new(nodes.bush).best_tool(inventory, tools), "hands")
	assert_eq(NodeHarvest.new(nodes.ground_stone).best_tool(inventory, tools), "pickup")


func test_chopper_fells_a_tree_in_15_strikes() -> void:
	var harvest := NodeHarvest.new(nodes.tree)
	var power := float(tools.chopper.power)
	var strikes := 0
	var loot := {}
	while not harvest.is_depleted():
		loot = harvest.hit(power)
		strikes += 1
	assert_eq(strikes, 15, "6 hits / power 0.4")
	assert_eq(loot, {"log": 3, "stick": 2}, "The whole loot drops on the last strike")


func test_weaker_strikes_still_give_the_whole_bush() -> void:
	var harvest := NodeHarvest.new(nodes.bush)
	var leaves := 0
	while not harvest.is_depleted():
		leaves += harvest.hit(0.4).get("leaves", 0)
	assert_eq(leaves, 6)


func test_tool_stats_from_data() -> void:
	var chopper := ToolStats.new("chopper", tools, 0.6)
	assert_eq(chopper.power, 0.4)
	assert_eq(chopper.hit_interval, 0.4)
	assert_eq(nodes.tree.stamina_cost * chopper.stamina_mult, 5.0, "5 stamina per strike")
	var hands := ToolStats.new("hands", tools, 0.6)
	assert_eq(hands.power, 1.0)
	assert_eq(hands.hit_interval, 0.6, "Hands keep the hands rhythm")
	assert_eq(hands.stamina_mult, 1.0)


func test_respawn_time_and_never_for_a_stump() -> void:
	assert_eq(NodeHarvest.new(nodes.tree).respawn, 300.0)
	assert_eq(NodeHarvest.new(nodes.stump).respawn, 0.0)


func test_uneven_share_adds_up_to_the_total() -> void:
	var parts: Array[int] = []
	for i in 3:
		parts.append(NodeHarvest.share(7, 3, i, i + 1))
	assert_eq(parts, [2, 2, 3])
