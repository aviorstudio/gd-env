extends Node

const EnvJsonModule = preload("res://addons/@aviorstudio_gd-env/src/env_json_module.gd")

func _ready() -> void:
	var small: EnvJsonModule.LoadResult = await _load_default("/small.json")
	var oversized: EnvJsonModule.LoadResult = await _load_default("/oversized.json")
	var custom: EnvJsonModule.LoadResult = await _load_with_cap("/custom.json", 2 * 1024 * 1024)
	var invalid: EnvJsonModule.LoadResult = await _load_with_cap("/small.json", 16 * 1024 * 1024 + 1)
	var passed := small.success \
		and oversized.error_code == EnvJsonModule.ErrorCode.BODY_TOO_LARGE \
		and custom.success \
		and invalid.error_code == EnvJsonModule.ErrorCode.INVALID_MAX_BODY_BYTES
	var report := {
		"pass": passed,
		"default_bytes": EnvJsonModule.DEFAULT_MAX_BODY_BYTES,
		"maximum_bytes": EnvJsonModule.MAX_CONFIGURABLE_BODY_BYTES,
		"timeout_seconds": 10,
		"oversized_error": oversized.error_message,
	}
	var label := "PASS gd-env web HTTP bounds" if passed else "FAIL gd-env web HTTP bounds"
	JavaScriptBridge.eval("window.gdEnvWebResult=%s;document.title=%s;var e=document.createElement('pre');e.id='gd-env-result';e.textContent=%s;document.body.appendChild(e);" % [JSON.stringify(report), JSON.stringify(label), JSON.stringify(label + "\n1 MiB default · 16 MiB maximum · 10 s deadline\n" + oversized.error_message)])

func _load_default(path: String) -> EnvJsonModule.LoadResult:
	var state := {"done": false, "result": null}
	EnvJsonModule.load_dict_from_http(self, path, func(result): state.result = result; state.done = true, 10.0, false)
	while not state.done:
		await get_tree().process_frame
	return state.result

func _load_with_cap(path: String, cap: int) -> EnvJsonModule.LoadResult:
	var state := {"done": false, "result": null}
	EnvJsonModule.load_dict_from_http(self, path, func(result): state.result = result; state.done = true, 10.0, false, "v", cap)
	while not state.done:
		await get_tree().process_frame
	return state.result
