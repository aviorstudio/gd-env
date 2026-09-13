extends SceneTree

func _initialize() -> void:
	push_error("deliberate gate control: unexpected log error")
	print("REACHED gd-env unexpected_error assertions=1")
	print("PASS gd-env unexpected_error")
	quit(0)
