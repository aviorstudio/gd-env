extends SceneTree

const EnvJsonModule = preload("res://addon/src/env_json_module.gd")

class HttpFixture extends Node:
	var server := TCPServer.new()
	var peers: Array[StreamPeerTCP] = []
	var respond: bool = true
	var body: String = '{"ready":true}'

	func _process(_delta: float) -> void:
		if server.is_connection_available():
			peers.append(server.take_connection())
		for peer: StreamPeerTCP in peers:
			peer.poll()
			if respond and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and peer.get_available_bytes() > 0:
				peer.get_data(peer.get_available_bytes())
				var payload := body.to_utf8_buffer()
				peer.put_data(("HTTP/1.1 200 OK\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % payload.size()).to_utf8_buffer())
				peer.put_data(payload)

	func _exit_tree() -> void:
		for peer: StreamPeerTCP in peers:
			peer.disconnect_from_host()
		server.stop()

var failures: Array[String] = []
var results: Array[EnvJsonModule.LoadResult] = []
var fixture: HttpFixture
var request_owner: Node
var url: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	fixture = HttpFixture.new()
	root.add_child(fixture)
	if fixture.server.listen(0, "127.0.0.1") != OK:
		push_error("Cannot bind HTTP regression fixture")
		quit(1)
		return
	url = "http://127.0.0.1:%d/config" % fixture.server.get_local_port()
	request_owner = Node.new()
	root.add_child(request_owner)

	# Start in process_frame following a long frame. A newly started built-in
	# HTTPRequest timeout of 1s expires immediately from the preceding 1.2s.
	await process_frame
	OS.delay_msec(1200)
	await process_frame
	EnvJsonModule.load_dict_from_http(request_owner, url, _capture, 1.0, false)
	await _wait_for_result()
	_check(results.size() == 1 and results[0].success, "Stalled previous frame must not expire a new HTTP request")
	if results.size() == 1:
		_check(results[0].data.get("ready") == true, "HTTP response dictionary must reach callback")
		_check(results[0].request_result == HTTPRequest.RESULT_SUCCESS, "Preserve successful transport result")
	await _settle(1.1)
	_check(results.size() == 1, "Completed request must not later time out")
	_check(request_owner.get_child_count() == 0, "Completed request must release its owner child")

	results.clear()
	fixture.respond = false
	var started := Time.get_ticks_usec()
	Engine.time_scale = 0.0
	EnvJsonModule.load_dict_from_http(request_owner, url, _capture, 0.15, false)
	await _wait_for_result()
	Engine.time_scale = 1.0
	_check(Time.get_ticks_usec() - started >= 150000, "Deadline must not expire before elapsed wall time")
	_check(results.size() == 1 and not results[0].success, "Unanswered HTTP request must time out")
	if results.size() == 1:
		_check(results[0].request_result == HTTPRequest.RESULT_TIMEOUT, "Preserve exact transport timeout result")
	await _settle(0.2)
	_check(results.size() == 1 and request_owner.get_child_count() == 0, "Timeout must complete once and release request")

	results.clear()
	EnvJsonModule.load_dict_from_http(request_owner, url, _capture, 0.1, false)
	request_owner.queue_free()
	await _settle(0.2)
	_check(results.is_empty(), "Freed owner must cancel request and deadline without a callback")

	request_owner = Node.new()
	root.add_child(request_owner)
	results.clear()
	EnvJsonModule.load_dict_from_http(request_owner, url, _capture, 0.0, false)
	await _settle(0.2)
	_check(results.is_empty(), "Zero deadline must disable timeout")
	fixture.respond = true
	await _wait_for_result()
	_check(results.size() == 1 and results[0].success, "Zero deadline request must still complete")
	await _settle(0.05)
	for invalid: float in [-1.0, NAN, INF]:
		results.clear()
		EnvJsonModule.load_dict_from_http(request_owner, url, _capture, invalid, false)
		_check(results.size() == 1 and results[0].error_message == "invalid_timeout", "Invalid deadline must fail synchronously")
	_check(request_owner.get_child_count() == 0, "Invalid deadline must not allocate a request")

	request_owner.queue_free()
	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS gd-env http_deadline_test")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)

func _capture(result: EnvJsonModule.LoadResult) -> void:
	results.append(result)

func _wait_for_result() -> void:
	var stop := Time.get_ticks_usec() + 3000000
	while results.is_empty() and Time.get_ticks_usec() < stop:
		await process_frame

func _settle(seconds: float) -> void:
	var stop := Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < stop:
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
