extends SceneTree

## Prints where user:// is under the current environment, and quits. Read by
## tools/dev/env.sh `tk_guard`.
func _init() -> void:
	print("USER_DIR=%s" % OS.get_user_data_dir())
	quit()
