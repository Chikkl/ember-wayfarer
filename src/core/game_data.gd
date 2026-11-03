extends Node
## Autoload with all game data. Files are read once, on first request.
## Usage: GameData.params("player"), GameData.table("comfort_items").

const DATA_DIR := "res://data/"

var _params := {}
var _tables := {}


## Parameters from data/<name>.json.
func params(file_name: String) -> Dictionary:
	if not _params.has(file_name):
		_params[file_name] = DataLoader.load_json(DATA_DIR + file_name + ".json")
	return _params[file_name]


## Rows from data/<name>.csv indexed by the id column.
func table(file_name: String) -> Dictionary:
	if not _tables.has(file_name):
		var rows := DataLoader.load_csv(DATA_DIR + file_name + ".csv")
		_tables[file_name] = DataLoader.index_by(rows, "id")
	return _tables[file_name]
