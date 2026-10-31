class_name Crafting
extends RefCounted
## Crafting from recipes: which recipes are available, what is missing, and making
## an item over time. Materials are taken at the end, so a cancel loses nothing.
## Rules: docs/systems/crafting.md. Values: data/recipes.csv.

enum Problem { NONE, MATERIALS, TOOL, SPACE, BUILDING }

## Rows of data/recipes.csv by id, in file order.
var recipes: Dictionary
## The recipe being made, "" if none.
var current := ""
## Seconds spent on [member current].
var elapsed := 0.0

var _inventory: Inventory
var _tree: RecipeTree
## Recipes made at least once: experience comes only for the first time.
var _crafted: Array[String] = []


func _init(recipe_rows: Dictionary, inventory: Inventory, tree: RecipeTree) -> void:
	recipes = recipe_rows
	_inventory = inventory
	_tree = tree


## Starting recipes and the recipes of open nodes, in the order of data/recipes.csv.
func available() -> Array[String]:
	var unlocked := _tree.unlocked_recipes()
	var ids: Array[String] = []
	for recipe_id: String in recipes:
		if is_start(recipe_id) or recipe_id in unlocked:
			ids.append(recipe_id)
	return ids


func is_start(recipe_id: String) -> bool:
	return str(recipes[recipe_id].start) == "1"


func is_building(recipe_id: String) -> bool:
	return recipes[recipe_id].kind == "building"


func is_first(recipe_id: String) -> bool:
	return recipe_id not in _crafted


func materials(recipe_id: String) -> Dictionary:
	return DataLoader.parse_amounts(recipes[recipe_id].materials)


## Tools the recipe needs in the inventory; they are not used up.
func tools(recipe_id: String) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(str(recipes[recipe_id].tools).split(";", false))
	return ids


func time(recipe_id: String) -> float:
	return float(recipes[recipe_id].time)


## Why [param recipe_id] cannot be made right now, or NONE.
## Buildings wait for the build mode, the next part of step 1.
func problem(recipe_id: String) -> Problem:
	if is_building(recipe_id):
		return Problem.BUILDING
	var needed := materials(recipe_id)
	for item_id: String in needed:
		if _inventory.count(item_id) < needed[item_id]:
			return Problem.MATERIALS
	for tool_id in tools(recipe_id):
		if _inventory.count(tool_id) < 1:
			return Problem.TOOL
	var after := _inventory.copy()
	for item_id: String in needed:
		after.remove(item_id, needed[item_id])
	if after.carry_amount(recipe_id) < 1:
		return Problem.SPACE
	return Problem.NONE


func is_busy() -> bool:
	return not current.is_empty()


## Share of the current recipe done, from 0 to 1.
func progress() -> float:
	return clampf(elapsed / time(current), 0.0, 1.0) if is_busy() else 0.0


## Starts making [param recipe_id]. False if something is missing.
func start(recipe_id: String) -> bool:
	if problem(recipe_id) != Problem.NONE:
		return false
	current = recipe_id
	elapsed = 0.0
	return true


func cancel() -> void:
	current = ""
	elapsed = 0.0


## Advances the current recipe. When it is done, takes the materials, puts the item
## into the inventory and returns {"item_id", "xp"}; xp is 0 after the first time.
## Returns {} while the item is being made, or if the inventory changed and the
## recipe can no longer be made.
func update(delta: float) -> Dictionary:
	if not is_busy():
		return {}
	elapsed += delta
	if elapsed < time(current):
		return {}
	var recipe_id := current
	cancel()
	if problem(recipe_id) != Problem.NONE:
		return {}
	var needed := materials(recipe_id)
	for item_id: String in needed:
		_inventory.remove(item_id, needed[item_id])
	_inventory.add(recipe_id)
	return {"item_id": recipe_id, "xp": _record(recipe_id)}


## Records a finished building. Returns its experience, 0 after the first time.
func finish_building(recipe_id: String) -> int:
	return _record(recipe_id)


func _record(recipe_id: String) -> int:
	if not is_first(recipe_id):
		return 0
	_crafted.append(recipe_id)
	return int(recipes[recipe_id].xp)
