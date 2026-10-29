extends SceneTree

## Dev tool: rebuilds the project UI theme from scripts/ui/ui_theme.gd.
## Run: godot --headless --path . --script res://scripts/tools/build_ui_theme.gd


func _initialize() -> void:
	var theme_script := load("res://scripts/ui/ui_theme.gd") as GDScript
	var theme: Theme = theme_script.call("build")
	var path := str(theme_script.get("THEME_PATH"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := ResourceSaver.save(theme, path)
	if err != OK:
		push_error("Could not save UI theme to %s (error %d)." % [path, err])
		quit(1)
		return
	print("UI theme saved to %s" % path)
	quit(0)
