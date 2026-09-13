@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GdEnv"
const AUTOLOAD_SCRIPT := "autoload.gd"
const OWNERSHIP_SETTING := "gd_env/plugin_owns_autoload"

func _enable_plugin() -> void:
	var key: String = "autoload/" + AUTOLOAD_NAME
	if ProjectSettings.has_setting(key):
		return
	add_autoload_singleton(AUTOLOAD_NAME, _autoload_path())
	ProjectSettings.set_setting(OWNERSHIP_SETTING, true)
	ProjectSettings.save()

func _disable_plugin() -> void:
	if not bool(ProjectSettings.get_setting(OWNERSHIP_SETTING, false)):
		return
	if _autoload_setting_matches_plugin():
		remove_autoload_singleton(AUTOLOAD_NAME)
	ProjectSettings.clear(OWNERSHIP_SETTING)
	ProjectSettings.save()

func _autoload_path() -> String:
	var base_dir: String = str(get_script().resource_path).get_base_dir()
	return base_dir.path_join(AUTOLOAD_SCRIPT)

func _autoload_setting_matches_plugin() -> bool:
	var key: String = "autoload/" + AUTOLOAD_NAME
	if not ProjectSettings.has_setting(key):
		return false
	var configured_path := str(ProjectSettings.get_setting(key)).trim_prefix("*")
	if configured_path.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(configured_path)
		if ResourceUID.has_id(uid):
			configured_path = ResourceUID.get_id_path(uid)
	return configured_path == _autoload_path()
