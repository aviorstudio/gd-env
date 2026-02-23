## JSON loading helpers for file and HTTP configuration sources.
class_name EnvJsonModule
extends RefCounted

## Standardized JSON load result payload.
class LoadResult extends RefCounted:
	var success: bool
	var source: String
	var status_code: int
	var data: Dictionary[String, Variant]
	var error_message: String

	func _init(
		success: bool = false,
		source: String = "",
		status_code: int = 0,
		data: Dictionary[String, Variant] = {},
		error_message: String = ""
	) -> void:
		self.success = success
		self.source = source
		self.status_code = status_code
		self.data = data
		self.error_message = error_message

## Loads the first existing file path from the provided candidate list.
static func load_dict_from_first_existing(paths: PackedStringArray) -> LoadResult:
	for path: String in paths:
		if FileAccess.file_exists(path):
			return load_dict_from_file(path)
	return LoadResult.new(false, "", 0, {}, "file_not_found")

## Loads and parses a JSON dictionary from disk.
static func load_dict_from_file(path: String) -> LoadResult:
	if path.is_empty():
		return LoadResult.new(false, path, 0, {}, "empty_path")
	if not FileAccess.file_exists(path):
		return LoadResult.new(false, path, 0, {}, "file_not_found")

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return LoadResult.new(false, path, 0, {}, "file_open_failed")

	var json_text: String = file.get_as_text()
	file.close()

	var parsed: LoadResult = parse_json_dict(json_text)
	parsed.source = path
	return parsed

## Loads and parses a JSON dictionary from HTTP asynchronously.
static func load_dict_from_http(
	owner: Node,
	url: String,
	callback: Callable,
	timeout_s: float = 10.0,
	cache_bust: bool = true,
	cache_bust_key: String = "v"
) -> void:
	if not callback.is_valid():
		return
	if not owner:
		callback.call(LoadResult.new(false, url, 0, {}, "missing_owner"))
		return
	if url.is_empty():
		callback.call(LoadResult.new(false, url, 0, {}, "empty_url"))
		return

	var request_node := HTTPRequest.new()
	request_node.use_threads = not OS.has_feature("web")
	request_node.timeout = timeout_s
	owner.add_child(request_node)

	var final_url: String = _resolve_web_relative_url(url)
	if cache_bust:
		final_url = _with_query_param(final_url, cache_bust_key, str(Time.get_unix_time_from_system()))

	var handler: Callable = func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		var out := LoadResult.new(false, final_url, response_code, {}, "")

		if result != HTTPRequest.RESULT_SUCCESS:
			out.error_message = "request_failed"
		elif response_code < 200 or response_code >= 300:
			out.error_message = "http_" + str(response_code)
		else:
			var body_text: String = body.get_string_from_utf8()
			out = parse_json_dict(body_text)
			out.source = final_url
			out.status_code = response_code

		if callback.is_valid():
			callback.call(out)
		request_node.queue_free()

	request_node.request_completed.connect(handler)

	var err: int = request_node.request(final_url, PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		request_node.queue_free()
		callback.call(LoadResult.new(false, final_url, 0, {}, "request_error_" + str(err)))

## Parses raw JSON text into a typed dictionary load result.
static func parse_json_dict(json_text: String) -> LoadResult:
	var json := JSON.new()
	var parse_result: int = json.parse(json_text)
	if parse_result != OK:
		return LoadResult.new(false, "", 0, {}, "parse_error: " + json.get_error_message())

	var payload: Variant = json.data
	if not (payload is Dictionary):
		return LoadResult.new(false, "", 0, {}, "parse_error: expected_dictionary")

	return LoadResult.new(true, "", 0, normalize_string_keys(payload), "")

## Converts dictionary keys to strings for stable typed access.
static func normalize_string_keys(raw: Dictionary) -> Dictionary[String, Variant]:
	var normalized: Dictionary[String, Variant] = {}
	for key in raw.keys():
		if key is String:
			normalized[key] = raw[key]
		else:
			normalized[str(key)] = raw[key]
	return normalized

## Deep-merges two dictionaries with overrides taking precedence.
static func merge(base: Dictionary[String, Variant], overrides: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = base.duplicate(true)
	for key: String in overrides:
		out[key] = overrides[key]
	return out

## Adds a URL query parameter with URI-encoded value.
static func _with_query_param(url: String, key: String, value: String) -> String:
	if key.is_empty():
		return url
	var separator: String = "&" if "?" in url else "?"
	return url + separator + key + "=" + value.uri_encode()

## Resolves relative web URLs against `window.location.origin`.
static func _resolve_web_relative_url(url: String) -> String:
	if url.begins_with("http://") or url.begins_with("https://"):
		return url
	if not OS.has_feature("web"):
		return url

	var origin: String = str(JavaScriptBridge.eval("window.location.origin"))
	if origin.is_empty():
		return url

	if url.begins_with("/"):
		return origin + url
	return origin + "/" + url
