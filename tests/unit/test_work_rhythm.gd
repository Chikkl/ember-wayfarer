extends GutTest
## Hold-to-work rhythm from docs/systems/gathering.md, "Действия", rule 3.

const PARAMS := {
	"stamina_max": 100,
	"stamina_regen": 25.0,
	"stamina_regen_delay": 0.8,
	"fatigue_rate": 0.03,
	"fatigue_floor": 40,
	"exhaust_duration": 1.5,
	"exhaust_speed_mult": 0.7,
}
const INTERVAL := 0.6
const COST := 8.0
const STEP := 0.05

var stamina: Stamina
var work: WorkRhythm


func before_each() -> void:
	stamina = Stamina.new(PARAMS)
	work = WorkRhythm.new(INTERVAL)


func _hits_over(seconds: float) -> int:
	var hits := 0
	for i in roundi(seconds / STEP):
		if work.update(STEP, stamina, COST):
			hits += 1
		stamina.update(STEP)
	return hits


func test_first_hit_is_immediate() -> void:
	work.start()
	assert_true(work.update(STEP, stamina, COST))


func test_holding_hits_once_per_interval() -> void:
	work.start()
	assert_eq(_hits_over(3.0), 5, "Hits at 0, 0.6, 1.2, 1.8 and 2.4 s")


func test_no_hits_without_start() -> void:
	assert_eq(_hits_over(1.0), 0)


func test_stop_ends_work() -> void:
	work.start()
	_hits_over(0.1)
	work.stop()
	assert_eq(_hits_over(1.0), 0)


func test_tapping_cannot_beat_the_rhythm() -> void:
	var hits := 0
	for i in 12:
		work.start()
		if work.update(STEP, stamina, COST):
			hits += 1
		work.stop()
		work.update(STEP, stamina, COST)
	assert_eq(hits, 2, "1.2 s of tapping gives the same 2 hits as holding")


func test_exhaustion_stops_work_until_pressed_again() -> void:
	stamina.value = 10.0
	work.start()
	assert_eq(_hits_over(0.7), 2, "Second hit empties the bar")
	assert_false(work.is_working, "Exhaustion stops work")
	assert_eq(_hits_over(3.0), 0, "Holding the button does not resume work")
	work.start()
	assert_true(work.update(STEP, stamina, COST), "Pressing again resumes work")
