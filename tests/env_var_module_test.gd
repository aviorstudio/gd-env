extends SceneTree

const EnvVarModule = preload("res://src/env_var_module.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_has_helper(failures)
	_test_parse_bool_edges(failures)

	if failures.is_empty():
		print("PASS gd-env env_var_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_has_helper(failures: Array[String]) -> void:
	if not EnvVarModule.has("PATH"):
		failures.append("Expected PATH environment variable to exist")
	if EnvVarModule.has("GD_ENV_TEST_VARIABLE_SHOULD_NOT_EXIST_8D87D"): 
		failures.append("Expected unknown environment variable to be absent")

func _test_parse_bool_edges(failures: Array[String]) -> void:
	if not EnvVarModule.parse_bool(" yes ", false):
		failures.append("Expected parse_bool(' yes ') to return true")
	if EnvVarModule.parse_bool("off", true):
		failures.append("Expected parse_bool('off') to return false")
	if not EnvVarModule.parse_bool("not-a-bool", true):
		failures.append("Expected parse_bool fallback default to be returned")
