extends GutTest
## Data loading and the real files in data/.


func test_parse_cell_types() -> void:
	assert_eq(DataLoader.parse_cell("2"), 2)
	assert_eq(DataLoader.parse_cell("0.6"), 0.6)
	assert_eq(DataLoader.parse_cell("true"), true)
	assert_eq(DataLoader.parse_cell("false"), false)
	assert_eq(DataLoader.parse_cell("stone_axe"), "stone_axe")
	assert_eq(DataLoader.parse_cell(""), "")


func test_comfort_items_csv() -> void:
	var rows := DataLoader.load_csv("res://data/comfort_items.csv")
	assert_eq(rows.size(), 4)
	var items := DataLoader.index_by(rows, "id")
	assert_eq(items.campfire.name, "Костёр", "UTF-8 names survive")
	assert_eq(items.campfire.comfort, 2)
	assert_eq(items.campfire.creates_camp, true)


func test_player_json_has_every_spec_parameter() -> void:
	var params := DataLoader.load_json("res://data/player.json")
	for key in [
		"move_speed",
		"move_accel_time",
		"stamina_max",
		"stamina_regen",
		"stamina_regen_delay",
		"fatigue_rate",
		"fatigue_floor",
		"exhaust_duration",
		"exhaust_speed_mult",
	]:
		assert_has(params, key)


func test_data_used_by_the_prototype_exists() -> void:
	for key in ["camp_radius", "rest_fatigue_base", "rest_per_comfort", "rest_regen_per_comfort"]:
		assert_has(DataLoader.load_json("res://data/comfort.json"), key)
	assert_has(DataLoader.load_json("res://data/gathering.json"), "hit_interval")
	var nodes := DataLoader.index_by(DataLoader.load_csv("res://data/resource_nodes.csv"), "id")
	assert_has(nodes, "tree")
	assert_has(nodes.tree, "stamina_cost")


func test_game_data_caches_tables() -> void:
	var first: Dictionary = GameData.table("comfort_items")
	assert_same(first, GameData.table("comfort_items"))
	assert_has(first, "campfire")
	assert_has(GameData.params("comfort"), "camp_radius")
