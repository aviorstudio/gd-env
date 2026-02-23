extends SceneTree

const DotenvModule = preload("res://src/dotenv_module.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_parse_supports_comments_quotes_export_and_empty_lines(failures)
	_test_load_file_reads_env_data(failures)

	if failures.is_empty():
		print("PASS gd-env dotenv_module_test")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _test_parse_supports_comments_quotes_export_and_empty_lines(failures: Array[String]) -> void:
	var text := "# comment\n" \
		+ "export API_KEY=abc123\n" \
		+ "EMPTY=\n" \
		+ "SPACED = value with spaces\n" \
		+ "QUOTED=\"quoted value\"\n" \
		+ "SINGLE='single value'\n" \
		+ "; comment\n" \
		+ "\n"
	var parsed: Dictionary[String, String] = DotenvModule.parse(text)

	if parsed.get("API_KEY", "") != "abc123":
		failures.append("Expected export-prefixed key to be parsed")
	if parsed.get("EMPTY", "missing") != "":
		failures.append("Expected empty assignment to be preserved")
	if parsed.get("SPACED", "") != "value with spaces":
		failures.append("Expected trimmed key/value parsing with spaces")
	if parsed.get("QUOTED", "") != "quoted value":
		failures.append("Expected double-quoted value to be unwrapped")
	if parsed.get("SINGLE", "") != "single value":
		failures.append("Expected single-quoted value to be unwrapped")
	if parsed.has("#"):
		failures.append("Expected comment lines to be ignored")

func _test_load_file_reads_env_data(failures: Array[String]) -> void:
	var path := "user://gd_env_dotenv_module_test.env"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("Failed to create temp dotenv file")
		return
	file.store_string("FILE_VALUE=from_file\n")
	file.close()

	var loaded: Dictionary[String, String] = DotenvModule.load_file(path)
	if loaded.get("FILE_VALUE", "") != "from_file":
		failures.append("Expected load_file to parse key from file")