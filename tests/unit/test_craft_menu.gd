extends GutTest
## The craft menu notes, docs/systems/comfort.md, "Обратная связь игроку".


func test_a_building_shows_its_own_comfort_and_group() -> void:
	assert_eq(CraftMenu.building_note("log_seat"), "комфорт 1 · сиденье")
	assert_eq(CraftMenu.building_note("hut"), "комфорт 4 · укрытие")
	assert_eq(CraftMenu.building_note("bedroll"), "комфорт 2 · сон")


func test_the_basket_is_storage() -> void:
	assert_eq(CraftMenu.building_note("basket"), "склад")
