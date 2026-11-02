extends GutTest
## Experience and levels from docs/systems/tech-tree.md, "Опыт и уровень",
## with real data/progression.json and data/items.csv.

var progression: Progression


func before_each() -> void:
	progression = Progression.new(GameData.params("progression"))


func test_thresholds_match_the_spec_table() -> void:
	var thresholds: Array[int] = []
	for level in range(1, 6):
		thresholds.append(progression.threshold(level))
	assert_eq(thresholds, [30, 51, 87, 147, 251])


func test_start_on_level_one_with_nothing() -> void:
	assert_eq(progression.level, 1)
	assert_eq(progression.xp, 0)
	assert_eq(progression.points, 0)


func test_level_up_gives_a_point_and_keeps_the_extra_xp() -> void:
	watch_signals(progression)
	progression.add_xp(29)
	assert_eq(progression.level, 1)
	progression.add_xp(5)
	assert_eq(progression.level, 2)
	assert_eq(progression.xp, 4, "34 - 30 carries over")
	assert_eq(progression.points, 1)
	assert_signal_emitted_with_parameters(progression, "leveled_up", [2])


func test_several_levels_at_once_come_one_by_one() -> void:
	watch_signals(progression)
	progression.add_xp(30 + 51 + 10)
	assert_eq(progression.level, 3)
	assert_eq(progression.xp, 10)
	assert_eq(progression.points, 2)
	assert_signal_emit_count(progression, "leveled_up", 2)


func test_loot_xp_by_the_items_table() -> void:
	var items := GameData.table("items")
	assert_eq(Progression.loot_xp({"log": 3, "stick": 2}, items), 14, "A felled tree")
	assert_eq(Progression.loot_xp({"leaves": 2}, items), 2, "One hit on a bush")
	assert_eq(Progression.loot_xp({}, items), 0)
	assert_eq(Progression.loot_xp({"stone_axe": 1}, items), 0, "Crafted items give xp on crafting")
