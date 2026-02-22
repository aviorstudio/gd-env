class_name DotenvModule
extends RefCounted

static func load_file(path: String) -> Dictionary[String, String]:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var text: String = file.get_as_text()
	file.close()
	return parse(text)

static func parse(text: String) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	if text.is_empty():
		return result

	for raw_line: String in text.split("\n", false):
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("#") or line.begins_with(";"):
			continue

		if line.begins_with("export "):
			line = line.substr(7).strip_edges()
			if line.is_empty():
				continue

		var eq_index: int = line.find("=")
		if eq_index <= 0:
			continue

		var key: String = line.substr(0, eq_index).strip_edges()
		if key.is_empty():
			continue

		var value: String = line.substr(eq_index + 1).strip_edges()
		value = _strip_wrapping_quotes(value)
		result[key] = value

	return result

static func _strip_wrapping_quotes(value: String) -> String:
	if value.length() < 2:
		return value
	var first: String = value.left(1)
	var last: String = value.right(1)
	if (first == "\"" and last == "\"") or (first == "'" and last == "'"):
		return value.substr(1, value.length() - 2)
	return value
