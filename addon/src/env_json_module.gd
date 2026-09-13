## JSON loading helpers for file and HTTP configuration sources.
class_name EnvJsonModule
extends RefCounted

const DEFAULT_MAX_BODY_BYTES := 1024 * 1024
const MAX_CONFIGURABLE_BODY_BYTES := 16 * 1024 * 1024

enum ErrorCode {
	NONE,
	MISSING_OWNER,
	EMPTY_URL,
	INVALID_TIMEOUT,
	INVALID_MAX_BODY_BYTES,
	REQUEST_START_FAILED,
	REQUEST_FAILED,
	TIMEOUT,
	BODY_TOO_LARGE,
	HTTP_STATUS,
	JSON_PARSE,
	EXPECTED_DICTIONARY,
}

## Standardized JSON load result payload.
class LoadResult extends RefCounted:
	var success: bool
	var source: String
	var status_code: int
	var data: Dictionary[String, Variant]
	## HTTPRequest.Result, or -1 when no HTTP completion occurred.
	var request_result: int = -1
	var error_message: String
	var error_code: ErrorCode = ErrorCode.NONE
	var received_bytes: int = -1
	var declared_bytes: int = -1

	func _init(
		success: bool = false,
		source: String = "",
		status_code: int = 0,
		data: Dictionary[String, Variant] = {},
		error_message: String = "",
		error_code: ErrorCode = ErrorCode.NONE
	) -> void:
		self.success = success
		self.source = source
		self.status_code = status_code
		self.data = data
		self.error_message = error_message
		self.error_code = error_code

## Owns a wall-clock deadline without charging the frame before request start.
## HTTPRequest's built-in Timer can consume a stale process step on startup.
class DeadlineHttpRequest extends HTTPRequest:
	var _deadline_usec: int = 0

	func arm_deadline(timeout_s: float) -> void:
		_deadline_usec = Time.get_ticks_usec() + int(timeout_s * 1000000.0) if timeout_s > 0.0 else 0
		set_process(_deadline_usec > 0)

	func disarm_deadline() -> void:
		_deadline_usec = 0
		set_process(false)

	func _process(_delta: float) -> void:
		if _deadline_usec > 0 and Time.get_ticks_usec() >= _deadline_usec:
			disarm_deadline()
			cancel_request()
			request_completed.emit(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray())

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
	cache_bust_key: String = "v",
	max_body_bytes: int = DEFAULT_MAX_BODY_BYTES
) -> void:
	if not callback.is_valid():
		return
	if not owner:
		callback.call(LoadResult.new(false, url, 0, {}, "missing_owner", ErrorCode.MISSING_OWNER))
		return
	if url.is_empty():
		callback.call(LoadResult.new(false, url, 0, {}, "empty_url", ErrorCode.EMPTY_URL))
		return

	if not is_finite(timeout_s) or timeout_s < 0.0:
		callback.call(LoadResult.new(false, url, 0, {}, "invalid_timeout", ErrorCode.INVALID_TIMEOUT))
		return
	if max_body_bytes <= 0 or max_body_bytes > MAX_CONFIGURABLE_BODY_BYTES:
		callback.call(LoadResult.new(false, url, 0, {}, "invalid_max_body_bytes", ErrorCode.INVALID_MAX_BODY_BYTES))
		return

	var request_node := DeadlineHttpRequest.new()
	# Native threaded HTTP uses blocking reads; cancellation can wait on the peer.
	# Configuration requests use nonblocking polling on every platform.
	request_node.use_threads = false
	request_node.timeout = 0.0
	request_node.body_size_limit = max_body_bytes
	owner.add_child(request_node)

	var final_url: String = _resolve_web_relative_url(url)
	if cache_bust:
		final_url = _with_query_param(final_url, cache_bust_key, str(Time.get_unix_time_from_system()))

	var handler: Callable = func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
		request_node.disarm_deadline()
		var out := LoadResult.new(false, final_url, response_code, {}, "")
		out.request_result = result
		out.received_bytes = body.size()
		out.declared_bytes = _content_length(headers)

		if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			out.error_code = ErrorCode.BODY_TOO_LARGE
			out.error_message = "body_too_large"
		elif result == HTTPRequest.RESULT_TIMEOUT:
			out.error_code = ErrorCode.TIMEOUT
			out.error_message = "request_failed"
		elif result != HTTPRequest.RESULT_SUCCESS:
			out.error_code = ErrorCode.REQUEST_FAILED
			out.error_message = "request_failed"
		elif response_code < 200 or response_code >= 300:
			out.error_code = ErrorCode.HTTP_STATUS
			out.error_message = "http_" + str(response_code)
		else:
			var body_text: String = body.get_string_from_utf8()
			out = parse_json_dict(body_text)
			out.source = final_url
			out.status_code = response_code
			out.request_result = result

		request_node.queue_free()
		if callback.is_valid():
			callback.call(out)

	request_node.request_completed.connect(handler, CONNECT_ONE_SHOT)
	request_node.arm_deadline(timeout_s)

	var err: int = request_node.request(final_url, PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		request_node.request_completed.disconnect(handler)
		request_node.disarm_deadline()
		request_node.queue_free()
		callback.call(LoadResult.new(false, final_url, 0, {}, "request_error_" + str(err), ErrorCode.REQUEST_START_FAILED))

## Parses raw JSON text into a typed dictionary load result.
static func parse_json_dict(json_text: String) -> LoadResult:
	var json := JSON.new()
	var parse_result: int = json.parse(json_text)
	if parse_result != OK:
		return LoadResult.new(false, "", 0, {}, "parse_error: " + json.get_error_message(), ErrorCode.JSON_PARSE)

	var payload: Variant = json.data
	if not (payload is Dictionary):
		return LoadResult.new(false, "", 0, {}, "parse_error: expected_dictionary", ErrorCode.EXPECTED_DICTIONARY)

	return LoadResult.new(true, "", 0, normalize_string_keys(payload), "")

static func _content_length(headers: PackedStringArray) -> int:
	for header: String in headers:
		if header.to_lower().begins_with("content-length:"):
			var value := header.get_slice(":", 1).strip_edges()
			if value.is_valid_int():
				return value.to_int()
	return -1

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
		var override_value: Variant = overrides[key]
		var base_value: Variant = out.get(key)
		if base_value is Dictionary and override_value is Dictionary:
			out[key] = merge(normalize_string_keys(base_value), normalize_string_keys(override_value))
		else:
			out[key] = override_value
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
