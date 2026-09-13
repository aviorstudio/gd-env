extends SceneTree

func _initialize() -> void:
	push_error("deliberate gate control: assertion failure before overwritten quit")
	quit(1)
	quit(0)
