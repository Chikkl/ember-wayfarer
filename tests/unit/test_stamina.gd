extends GutTest
## Stamina rules from docs/systems/movement-stamina.md.
## Uses fixed parameters so tests do not break when data/player.json is tuned.

const PARAMS := {
	"stamina_max": 100,
	"stamina_regen": 25.0,
	"stamina_regen_delay": 0.8,
	"fatigue_rate": 0.03,
	"fatigue_floor": 40,
	"exhaust_duration": 1.5,
	"exhaust_speed_mult": 0.7,
}
const EPS := 0.0001

var stamina: Stamina


func before_each() -> void:
	stamina = Stamina.new(PARAMS)


func test_starts_full_and_rested() -> void:
	assert_eq(stamina.value, 100.0)
	assert_eq(stamina.fatigue, 0.0)
	assert_eq(stamina.available_max(), 100.0)
	assert_true(stamina.can_work())


func test_spend_lowers_stamina_and_adds_fatigue() -> void:
	assert_true(stamina.spend(8.0))
	assert_almost_eq(stamina.value, 92.0, EPS)
	assert_almost_eq(stamina.fatigue, 0.24, EPS)
	assert_almost_eq(stamina.available_max(), 99.76, EPS)


func test_regen_starts_after_delay_at_regen_rate() -> void:
	stamina.spend(8.0)
	stamina.update(0.8)
	assert_almost_eq(stamina.value, 92.0, EPS, "No regen until the delay has passed")
	stamina.update(0.1)
	assert_almost_eq(stamina.value, 94.5, EPS, "25 per second")


func test_regen_counts_only_time_past_delay() -> void:
	stamina.spend(8.0)
	stamina.update(0.9)
	assert_almost_eq(stamina.value, 94.5, EPS, "0.1 s past the delay gives 2.5")


func test_new_spend_restarts_regen_delay() -> void:
	stamina.spend(8.0)
	stamina.update(0.7)
	stamina.spend(8.0)
	stamina.update(0.7)
	assert_almost_eq(stamina.value, 84.0, EPS)


func test_regen_stops_at_available_max() -> void:
	stamina.spend(8.0)
	stamina.update(1.0)
	stamina.update(10.0)
	assert_almost_eq(stamina.value, stamina.available_max(), EPS)


func test_free_action_changes_nothing_even_when_exhausted() -> void:
	stamina.value = 1.0
	stamina.spend(8.0)
	assert_true(stamina.spend(0.0), "Pickups are free and allowed during exhaustion")
	assert_eq(stamina.fatigue, 1.0 * 0.03)
	assert_eq(stamina.exhaust_time_left, 1.5)


func test_cost_above_remainder_empties_bar_and_exhausts() -> void:
	stamina.value = 5.0
	assert_true(stamina.spend(8.0), "Work starts with any non-zero stamina")
	assert_eq(stamina.value, 0.0)
	assert_almost_eq(stamina.fatigue, 5.0 * 0.03, EPS, "Fatigue counts only what was spent")
	assert_true(stamina.is_exhausted())
	assert_false(stamina.can_work())
	assert_almost_eq(stamina.speed_mult(), 0.7, EPS)


func test_exhaustion_lasts_its_duration() -> void:
	stamina.value = 1.0
	stamina.spend(8.0)
	stamina.update(1.49)
	assert_true(stamina.is_exhausted(), "Still exhausted at 1.49 s of 1.5 s")
	assert_false(stamina.spend(8.0))
	stamina.update(0.02)
	assert_false(stamina.is_exhausted())
	assert_eq(stamina.speed_mult(), 1.0)
	assert_true(stamina.spend(8.0), "Regen during exhaustion allows work right after it")


func test_regen_starts_when_exhaustion_ends_if_delay_is_longer() -> void:
	var params := PARAMS.duplicate()
	params.stamina_regen_delay = 2.0
	stamina = Stamina.new(params)
	stamina.value = 1.0
	stamina.spend(8.0)
	stamina.update(1.5)
	assert_false(stamina.is_exhausted())
	stamina.update(0.1)
	assert_gt(stamina.value, 0.0, "No dead time at zero after exhaustion")


func test_fatigue_never_lowers_max_below_floor() -> void:
	for i in 1000:
		stamina.value = 100.0
		stamina.exhaust_time_left = 0.0
		stamina.spend(50.0)
	assert_almost_eq(stamina.fatigue, 60.0, EPS, "Fatigue caps at max minus floor")
	assert_almost_eq(stamina.available_max(), 40.0, EPS)
	assert_true(stamina.can_work(), "Fatigue never blocks work")


func test_rising_fatigue_clamps_current_value() -> void:
	stamina.fatigue = 59.99
	stamina.value = 100.0
	stamina.spend(1.0)
	assert_almost_eq(stamina.fatigue, 60.0, EPS, "Fatigue stops at its cap")
	assert_almost_eq(stamina.value, 40.0, EPS, "Value drops to the new available max")


func test_rest_removes_fatigue_at_given_rate() -> void:
	stamina.fatigue = 10.0
	stamina.update(1.0, 2.0)
	assert_almost_eq(stamina.fatigue, 8.0, EPS)
	stamina.update(10.0, 2.0)
	assert_eq(stamina.fatigue, 0.0, "Fatigue never goes below zero")


func test_value_follows_growing_max_while_resting() -> void:
	stamina.fatigue = 30.0
	stamina.value = 70.0
	stamina.update(1.0, 2.0)
	assert_almost_eq(stamina.available_max(), 72.0, EPS)
	assert_almost_eq(stamina.value, 72.0, EPS)


func test_floor_above_max_is_reported() -> void:
	var params := PARAMS.duplicate()
	params.fatigue_floor = 150
	stamina = Stamina.new(params)
	assert_push_error("fatigue_floor")
	assert_eq(stamina.max_fatigue(), 0.0, "Fatigue cannot go negative")
