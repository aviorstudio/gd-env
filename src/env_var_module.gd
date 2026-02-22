class_name EnvVarModule
extends RefCounted

static func has(name: String) -> bool:
	return not OS.get_environment(name).is_empty()

static func get_string(name: String, default_value: String = "") -> String:
	var raw: String = OS.get_environment(name)
	if raw.is_empty():
		return default_value
	return raw

static func get_int(name: String, default_value: int = 0) -> int:
	var raw: String = OS.get_environment(name)
	if raw.is_empty():
		return default_value
	if not raw.is_valid_int():
		return default_value
	return int(raw)

static func get_float(name: String, default_value: float = 0.0) -> float:
	var raw: String = OS.get_environment(name)
	if raw.is_empty():
		return default_value
	if not raw.is_valid_float():
		return default_value
	return float(raw)

static func get_bool(name: String, default_value: bool = false) -> bool:
	var raw: String = OS.get_environment(name)
	if raw.is_empty():
		return default_value
	return parse_bool(raw, default_value)

static func parse_bool(raw: String, default_value: bool = false) -> bool:
	var normalized: String = raw.strip_edges().to_lower()
	if normalized == "1" or normalized == "true" or normalized == "yes" or normalized == "y" or normalized == "on":
		return true
	if normalized == "0" or normalized == "false" or normalized == "no" or normalized == "n" or normalized == "off":
		return false
	return default_value

