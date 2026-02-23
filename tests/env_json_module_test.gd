extends SceneTree

const EnvJsonModule = preload("res://src/env_json_module.gd")

var _http_callback_called: bool = false
var _http_result: EnvJsonModule.LoadResult = null

func _initialize() -> void:
	var failures: Array[String] = []
	_test_load_dict_from_file_success(failures)
	_test_load_dict_from_file_missing(failures)
	_test_parse_json_invalid_payload(failures)
	_test_load_dict_from_http_missing_owner(failures)

	if failures.is_empty():
		print("PASS gd-env env_json_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_load_dict_from_file_success(failures: Array[String]) -> void:
	var path := "user://gd_env_json_module_test.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Failed to create temp JSON file")
		return
	file.store_string('{"port":8080,"env":"test"}')
	file.close()

	var result: EnvJsonModule.LoadResult = EnvJsonModule.load_dict_from_file(path)
	if not result.success:
		failures.append("Expected load_dict_from_file to succeed for valid JSON file")
	if int(result.data.get("port", 0)) != 8080:
		failures.append("Expected numeric key from JSON payload")
	if str(result.data.get("env", "")) != "test":
		failures.append("Expected string key from JSON payload")

func _test_load_dict_from_file_missing(failures: Array[String]) -> void:
	var result: EnvJsonModule.LoadResult = EnvJsonModule.load_dict_from_file("user://missing_file_that_should_not_exist_92a2.json")
	if result.success:
		failures.append("Expected missing file load to fail")
	if result.error_message != "file_not_found":
		failures.append("Expected file_not_found error for missing file")

func _test_parse_json_invalid_payload(failures: Array[String]) -> void:
	var invalid: EnvJsonModule.LoadResult = EnvJsonModule.parse_json_dict("{not-valid-json}")
	if invalid.success:
		failures.append("Expected invalid JSON to fail parsing")
	if not invalid.error_message.begins_with("parse_error"):
		failures.append("Expected parse_error prefix for invalid JSON")

	var non_dict: EnvJsonModule.LoadResult = EnvJsonModule.parse_json_dict("[1,2,3]")
	if non_dict.success:
		failures.append("Expected non-dictionary JSON payload to fail")

func _test_load_dict_from_http_missing_owner(failures: Array[String]) -> void:
	_http_callback_called = false
	_http_result = null
	EnvJsonModule.load_dict_from_http(
		null,
		"https://example.com/config.json",
		Callable(self, "_capture_http_result")
	)

	if not _http_callback_called:
		failures.append("Expected callback to be called when owner is missing")
	if _http_result == null:
		failures.append("Expected callback result object for missing owner")
		return
	if _http_result.success:
		failures.append("Expected missing owner HTTP load result to fail")
	if _http_result.error_message != "missing_owner":
		failures.append("Expected missing_owner error from load_dict_from_http")

func _capture_http_result(result: EnvJsonModule.LoadResult) -> void:
	_http_callback_called = true
	_http_result = result
