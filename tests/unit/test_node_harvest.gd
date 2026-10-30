extends GutTest
## Hits and loot from docs/systems/gathering.md, "Действия", with real data/resource_nodes.csv.

var nodes: Dictionary


func before_each() -> void:
	nodes = GameData.table("resource_nodes")


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
	assert_eq(harvest.hits_left, 0)


func test_tree_needs_the_axe_in_the_inventory() -> void:
	var harvest := NodeHarvest.new(nodes.tree)
	var inventory := Inventory.new(GameData.params("gathering"), GameData.table("items"))
	assert_false(harvest.can_work(inventory))
	inventory.add("stone_axe")
	assert_true(harvest.can_work(inventory))


func test_hands_and_pickup_need_no_tool() -> void:
	var inventory := Inventory.new(GameData.params("gathering"), GameData.table("items"))
	assert_true(NodeHarvest.new(nodes.bush).can_work(inventory))
	assert_true(NodeHarvest.new(nodes.ground_stone).can_work(inventory))


func test_respawn_time_and_never_for_a_stump() -> void:
	assert_eq(NodeHarvest.new(nodes.tree).respawn, 300.0)
	assert_eq(NodeHarvest.new(nodes.stump).respawn, 0.0)


func test_uneven_share_adds_up_to_the_total() -> void:
	var parts: Array[int] = []
	for i in 3:
		parts.append(NodeHarvest.share(7, 3, i))
	assert_eq(parts, [2, 2, 3])
