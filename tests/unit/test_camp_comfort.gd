extends GutTest
## Comfort rules from docs/systems/comfort.md, with the step 1 item table.

const ITEMS := {
	"campfire": {"group": "fire", "comfort": 2},
	"log_seat": {"group": "seat", "comfort": 1},
	"bedroll": {"group": "sleep", "comfort": 2},
	"lean_to": {"group": "shelter", "comfort": 2},
}
const REST := {"rest_fatigue_base": 1.0, "rest_per_comfort": 2.0, "rest_regen_per_comfort": 0.5}


func test_no_items_means_no_comfort() -> void:
	assert_eq(CampComfort.compute([], ITEMS), 0)


func test_campfire_alone() -> void:
	assert_eq(CampComfort.compute(["campfire"], ITEMS), 2)


func test_groups_add_up() -> void:
	assert_eq(CampComfort.compute(["campfire", "bedroll"], ITEMS), 4)


func test_same_group_counts_once() -> void:
	var ids: Array[String] = ["campfire", "log_seat", "log_seat", "log_seat"]
	assert_eq(CampComfort.compute(ids, ITEMS), 3, "Twenty seats give as much as one")


func test_full_step_1_camp() -> void:
	var ids: Array[String] = ["campfire", "log_seat", "bedroll", "lean_to"]
	assert_eq(CampComfort.compute(ids, ITEMS), 7, "Spec: step 1 maximum is 7")


func test_unknown_item_is_ignored() -> void:
	var ids: Array[String] = ["campfire", "golden_throne"]
	assert_eq(CampComfort.compute(ids, ITEMS), 2)


func test_rest_rate_matches_spec_table() -> void:
	assert_eq(CampComfort.rest_rate(0, REST), 1.0, "Forest")
	assert_eq(CampComfort.rest_rate(2, REST), 5.0, "One campfire")
	assert_eq(CampComfort.rest_rate(7, REST), 15.0, "Full step 1 camp")


func test_rest_regen_mult_matches_spec_table() -> void:
	assert_eq(CampComfort.rest_regen_mult(0, REST), 1.0, "Forest: same as standing")
	assert_eq(CampComfort.rest_regen_mult(2, REST), 2.0, "One campfire")
	assert_eq(CampComfort.rest_regen_mult(7, REST), 4.5, "Full step 1 camp")


func test_real_data_step_1_maximum_is_7() -> void:
	var table: Dictionary = GameData.table("comfort_items")
	var ids: Array[String] = []
	ids.assign(table.keys())
	assert_eq(CampComfort.compute(ids, table), 7)


func test_real_data_rest_times_match_spec() -> void:
	var player := GameData.params("player")
	var comfort := GameData.params("comfort")
	var fatigue_to_clear := float(player.stamina_max) - float(player.fatigue_floor)
	var expected_seconds := {0: 60.0, 2: 12.0, 7: 4.0}
	for comfort_value: int in expected_seconds:
		var seconds := fatigue_to_clear / CampComfort.rest_rate(comfort_value, comfort)
		assert_almost_eq(
			seconds, expected_seconds[comfort_value], 0.5, "Comfort %d" % comfort_value
		)


func test_real_data_bar_refill_times_match_spec() -> void:
	var player := GameData.params("player")
	var comfort := GameData.params("comfort")
	var base_seconds := float(player.stamina_max) / float(player.stamina_regen)
	var expected_seconds := {0: 4.0, 2: 2.0, 7: 0.9}
	for comfort_value: int in expected_seconds:
		var seconds := base_seconds / CampComfort.rest_regen_mult(comfort_value, comfort)
		assert_almost_eq(
			seconds, expected_seconds[comfort_value], 0.1, "Comfort %d" % comfort_value
		)
