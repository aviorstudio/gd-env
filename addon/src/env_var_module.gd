## Typed environment variable access helpers.
class_name EnvVarModule
extends RefCounted

## Result payload returned by `get_required`.
class RequiredResult extends RefCounted:
	## True when the requested environment variable is present and non-empty.
	var success: bool
	## The resolved environment variable value.
	var value: String
	## Failure reason when `success == false`.
	var error_message: String

	func _init(success: bool = false, value: String = "", error_message: String = "") -> void:
		self.success = success
		self.value = value
		self.error_message = error_message

## Returns true when the environment variable exists and is non-empty.
static func has(name: String) -> bool:
	return not OS.get_environment(name).is_empty()

## Returns a string environment variable or the provided default.
static func get_string(name: String, default_value: String = "") -> String:
	var raw: String = OS.get_environment(name)
	if raw.is_empty():
		return default_value
	return raw

## Returns a required environment variable as a typed result.
##
## When missing, returns `RequiredResult(success=false, error_message="missing_env:<NAME>")`.
static func get_required(name: String) -> RequiredResult:
	if name.is_empty():
		return RequiredResult.new(false, "", "empty_name")
	var raw: String = OS.get_environment(name)
	if raw.is_empty():
		return RequiredResult.new(false, "", "missing_env:%s" % name)
	return RequiredResult.new(true, raw, "")

## Returns an int environment variable or default when missing/invalid.
static func get_int(name: String, default_value: int = 0) -> int:
	var raw: String = OS.get_environment(name)
	if raw.is_empty():
		return default_value
	if not raw.is_valid_int():
		return default_value
	return int(raw)

## Returns a float environment variable or default when missing/invalid.
static func get_float(name: String, default_value: float = 0.0) -> float:
	var raw: String = OS.get_environment(name)
	if raw.is_empty():
		return default_value
	if not raw.is_valid_float():
		return default_value
	return float(raw)

## Returns a bool environment variable using tolerant bool parsing.
static func get_bool(name: String, default_value: bool = false) -> bool:
	var raw: String = OS.get_environment(name)
	if raw.is_empty():
		return default_value
	return parse_bool(raw, default_value)

## Parses common boolean string values with fallback default.
static func parse_bool(raw: String, default_value: bool = false) -> bool:
	var normalized: String = raw.strip_edges().to_lower()
	if normalized == "1" or normalized == "true" or normalized == "yes" or normalized == "y" or normalized == "on":
		return true
	if normalized == "0" or normalized == "false" or normalized == "no" or normalized == "n" or normalized == "off":
		return false
	return default_value

