extends SceneTree

func _initialize() -> void:
	push_error("deliberate gate control: runtime error with zero exit")
	print("REACHED gd-env push_error_zero assertions=1")
	print("PASS gd-env push_error_zero")
	quit(0)
