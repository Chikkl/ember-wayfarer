class_name DataLoader
extends RefCounted
## Reads game data from data/: JSON for parameters, CSV for tables.
## Format rules: data/README.md.


## Returns the JSON object from [param path], or an empty Dictionary on error.
static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Data file not found: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		push_error("Data file is not a JSON object: %s" % path)
		return {}
	return parsed


## Returns CSV rows as dictionaries keyed by the header row.
## Cell values are converted with [method parse_cell].
static func load_csv(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Data file not found: %s" % path)
		return rows
	var header := file.get_csv_line()
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() == 1 and cells[0] == "":
			continue
		if cells.size() != header.size():
			push_error("Wrong cell count in %s: %s" % [path, cells])
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = parse_cell(cells[i])
		rows.append(row)
	return rows


## Indexes rows by the value in [param key] column.
static func index_by(rows: Array[Dictionary], key: String) -> Dictionary:
	var result := {}
	for row in rows:
		result[row[key]] = row
	return result


## Converts a CSV cell: integers, floats and true/false get their types,
## everything else stays a String. An empty cell stays an empty String.
static func parse_cell(cell: String) -> Variant:
	if cell.is_valid_int():
		return cell.to_int()
	if cell.is_valid_float():
		return cell.to_float()
	if cell == "true":
		return true
	if cell == "false":
		return false
	return cell
