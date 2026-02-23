extends SceneTree

const EnvVarModule = preload("res://src/env_var_module.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_has_helper(failures)
	_test_parse_bool_edges(failures)
	_test_get_required_result(failures)

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

func _test_get_required_result(failures: Array[String]) -> void:
	var found: EnvVarModule.RequiredResult = EnvVarModule.get_required("PATH")
	if not found.success:
		failures.append("Expected get_required('PATH') to succeed")
	if found.value.is_empty():
		failures.append("Expected get_required('PATH') to return a non-empty value")

	var missing: EnvVarModule.RequiredResult = EnvVarModule.get_required("GD_ENV_MISSING_4B9E2")
	if missing.success:
		failures.append("Expected get_required to fail for missing env var")
	if not missing.error_message.begins_with("missing_env:"):
		failures.append("Expected get_required missing error prefix to be missing_env:")
