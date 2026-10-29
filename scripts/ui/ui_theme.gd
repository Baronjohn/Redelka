class_name UiTheme
extends RefCounted

## Builds Redelka's project-wide UI theme (gothic, matching the title cards).
## Saved to THEME_PATH by scripts/tools/build_ui_theme.gd and set as `gui/theme/custom`
## in project.godot, so every Control picks it up. Change the look here, then rebuild:
##   godot --headless --path . --script res://scripts/tools/build_ui_theme.gd
##
## Type variations (set `theme_type_variation` on a node):
##   WordmarkLabel   blackletter "Redelka"
##   HeaderLabel     screen titles        SubheaderLabel  section titles, speaker names
##   OverlineLabel   small spaced caps    HintLabel       quiet helper text
##   HudLabel        outlined explore text over the 3D view
##   ObjectiveLabel  the explore objective line
##   MainMenuButton  main-menu entries    TabButton       character-menu tabs (toggle)
##   ChoiceButton    dialog choices       DialogLine      RichTextLabel for spoken lines

const THEME_PATH: String = "res://assets/ui/redelka_theme.tres"

const BLACKLETTER: FontFile = preload("res://assets/fonts/unifraktur_maguntia.ttf")
const FELL: FontFile = preload("res://assets/fonts/im_fell_english.ttf")
const FELL_ITALIC: FontFile = preload("res://assets/fonts/im_fell_english_italic.ttf")
const BODY: FontFile = preload("res://assets/fonts/alegreya_sans_regular.ttf")
const BODY_MEDIUM: FontFile = preload("res://assets/fonts/alegreya_sans_medium.ttf")
const BODY_ITALIC: FontFile = preload("res://assets/fonts/alegreya_sans_italic.ttf")

const P := preload("res://scripts/ui/ui_palette.gd")


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = BODY
	theme.default_font_size = 19
	_labels(theme)
	_buttons(theme)
	_panels(theme)
	_lists(theme)
	_inputs(theme)
	_tabs(theme)
	_scrollbars(theme)
	_dialogs(theme)
	return theme


static func _spaced(font: Font, spacing: int) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = font
	variation.spacing_glyph = spacing
	return variation


static func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", P.BONE)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	_variation(theme, "WordmarkLabel", "Label")
	theme.set_font("font", "WordmarkLabel", BLACKLETTER)
	theme.set_font_size("font_size", "WordmarkLabel", 128)
	theme.set_color("font_color", "WordmarkLabel", P.BONE)

	_variation(theme, "HeaderLabel", "Label")
	theme.set_font("font", "HeaderLabel", FELL)
	theme.set_font_size("font_size", "HeaderLabel", 38)

	_variation(theme, "SubheaderLabel", "Label")
	theme.set_font("font", "SubheaderLabel", FELL)
	theme.set_font_size("font_size", "SubheaderLabel", 26)

	_variation(theme, "OverlineLabel", "Label")
	theme.set_font("font", "OverlineLabel", _spaced(FELL, 3))
	theme.set_font_size("font_size", "OverlineLabel", 19)
	theme.set_color("font_color", "OverlineLabel", P.FOG)

	_variation(theme, "HintLabel", "Label")
	theme.set_font("font", "HintLabel", BODY_ITALIC)
	theme.set_font_size("font_size", "HintLabel", 18)
	theme.set_color("font_color", "HintLabel", P.FOG)

	_variation(theme, "HudLabel", "Label")
	theme.set_font_size("font_size", "HudLabel", 20)
	theme.set_color("font_outline_color", "HudLabel", Color(P.INK, 0.9))
	theme.set_constant("outline_size", "HudLabel", 6)

	_variation(theme, "ObjectiveLabel", "Label")
	theme.set_font("font", "ObjectiveLabel", FELL_ITALIC)
	theme.set_font_size("font_size", "ObjectiveLabel", 24)
	theme.set_color("font_outline_color", "ObjectiveLabel", Color(P.INK, 0.85))
	theme.set_constant("outline_size", "ObjectiveLabel", 6)

	theme.set_font("normal_font", "RichTextLabel", BODY)
	theme.set_font("italics_font", "RichTextLabel", BODY_ITALIC)
	theme.set_font("bold_font", "RichTextLabel", BODY_MEDIUM)
	theme.set_color("default_color", "RichTextLabel", P.BONE)

	_variation(theme, "DialogLine", "RichTextLabel")
	theme.set_font("normal_font", "DialogLine", FELL)
	theme.set_font("italics_font", "DialogLine", FELL_ITALIC)
	theme.set_font_size("normal_font_size", "DialogLine", 26)
	theme.set_font_size("italics_font_size", "DialogLine", 26)


static func _button_colors(theme: Theme, type_name: String, normal: Color, hover: Color) -> void:
	theme.set_color("font_color", type_name, normal)
	theme.set_color("font_hover_color", type_name, hover)
	theme.set_color("font_focus_color", type_name, hover)
	theme.set_color("font_pressed_color", type_name, hover)
	theme.set_color("font_hover_pressed_color", type_name, hover)
	theme.set_color("font_disabled_color", type_name, Color(P.FOG, 0.45))
	theme.set_color("font_outline_color", type_name, Color(0, 0, 0, 0))


static func _buttons(theme: Theme) -> void:
	theme.set_font("font", "Button", FELL)
	theme.set_font_size("font_size", "Button", 22)
	_button_colors(theme, "Button", P.BONE_DIM, P.BONE)
	theme.set_stylebox("normal", "Button", P.box(P.PANEL_RAISED, P.RULE, 1, 16, 6))
	theme.set_stylebox("hover", "Button", P.box(P.PANEL_RAISED.lightened(0.06), P.BONE_DIM, 1, 16, 6))
	theme.set_stylebox("pressed", "Button", P.box(Color(P.SCARF, 0.35), P.SCARF, 1, 16, 6))
	theme.set_stylebox("hover_pressed", "Button", P.box(Color(P.SCARF, 0.45), P.SCARF, 1, 16, 6))
	theme.set_stylebox("disabled", "Button", P.box(Color(P.PANEL_RAISED, 0.5), Color(P.RULE, 0.5), 1, 16, 6))
	var focus := P.box(Color.TRANSPARENT, P.SCARF, 1, 16, 6)
	focus.draw_center = false
	theme.set_stylebox("focus", "Button", focus)

	# Main-menu entries: bare text with a scarf-red bar on the left when pointed at.
	_variation(theme, "MainMenuButton", "Button")
	theme.set_font_size("font_size", "MainMenuButton", 32)
	_button_colors(theme, "MainMenuButton", P.BONE_DIM, P.BONE)
	var menu_idle := P.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 22, 4)
	var menu_hot := P.box(Color(P.BONE, 0.05), P.SCARF, 0, 22, 4)
	menu_hot.border_width_left = 3
	var menu_focus := menu_hot.duplicate() as StyleBoxFlat
	menu_focus.draw_center = false
	theme.set_stylebox("normal", "MainMenuButton", menu_idle)
	theme.set_stylebox("hover", "MainMenuButton", menu_hot)
	theme.set_stylebox("pressed", "MainMenuButton", menu_hot)
	theme.set_stylebox("hover_pressed", "MainMenuButton", menu_hot)
	theme.set_stylebox("focus", "MainMenuButton", menu_focus)
	theme.set_stylebox("disabled", "MainMenuButton", menu_idle)

	# Character-menu tabs: toggle buttons underlined in scarf red when active.
	_variation(theme, "TabButton", "Button")
	theme.set_font_size("font_size", "TabButton", 24)
	_button_colors(theme, "TabButton", P.FOG, P.BONE)
	var tab_idle := P.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 12, 4)
	var tab_hover := P.box(Color.TRANSPARENT, Color(P.BONE_DIM, 0.6), 0, 12, 4)
	tab_hover.border_width_bottom = 1
	var tab_active := P.box(Color.TRANSPARENT, P.SCARF, 0, 12, 4)
	tab_active.border_width_bottom = 2
	var tab_focus := tab_hover.duplicate() as StyleBoxFlat
	tab_focus.draw_center = false
	theme.set_stylebox("normal", "TabButton", tab_idle)
	theme.set_stylebox("hover", "TabButton", tab_hover)
	theme.set_stylebox("pressed", "TabButton", tab_active)
	theme.set_stylebox("hover_pressed", "TabButton", tab_active)
	theme.set_stylebox("focus", "TabButton", tab_focus)

	# Dialog choices: framed rows, centred, red frame on the pointed one.
	_variation(theme, "ChoiceButton", "Button")
	theme.set_font_size("font_size", "ChoiceButton", 24)
	_button_colors(theme, "ChoiceButton", P.BONE_DIM, P.BONE)
	theme.set_stylebox("normal", "ChoiceButton", P.box(P.PANEL, P.RULE, 1, 20, 8))
	var choice_hot := P.box(P.PANEL_RAISED, P.SCARF, 1, 20, 8)
	choice_hot.border_width_left = 3
	theme.set_stylebox("hover", "ChoiceButton", choice_hot)
	theme.set_stylebox("pressed", "ChoiceButton", choice_hot)
	theme.set_stylebox("focus", "ChoiceButton", choice_hot)

	for type_name: String in ["CheckBox", "CheckButton", "OptionButton"]:
		theme.set_font("font", type_name, BODY)
		theme.set_font_size("font_size", type_name, 20)
		_button_colors(theme, type_name, P.BONE_DIM, P.BONE)
	# Check boxes carry their state in the icon; keep the row itself bare.
	for type_name: String in ["CheckBox", "CheckButton"]:
		var bare := P.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 4, 4)
		var bare_hover := P.box(Color(P.BONE, 0.04), Color.TRANSPARENT, 0, 4, 4)
		for state: String in ["normal", "pressed", "disabled"]:
			theme.set_stylebox(state, type_name, bare)
		theme.set_stylebox("hover", type_name, bare_hover)
		theme.set_stylebox("hover_pressed", type_name, bare_hover)
		var check_focus := P.box(Color.TRANSPARENT, P.SCARF, 1, 4, 4)
		check_focus.draw_center = false
		theme.set_stylebox("focus", type_name, check_focus)
	theme.set_stylebox("normal", "OptionButton", P.box(P.PANEL_RAISED, P.RULE, 1, 12, 6))
	theme.set_stylebox("hover", "OptionButton", P.box(P.PANEL_RAISED, P.BONE_DIM, 1, 12, 6))


static func _panels(theme: Theme) -> void:
	var panel := P.box(P.PANEL, P.RULE, 1, 14, 12)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "TooltipPanel", P.box(P.PANEL_RAISED, P.RULE, 1, 10, 6))
	theme.set_color("font_color", "TooltipLabel", P.BONE)
	theme.set_font("font", "TooltipLabel", BODY)


static func _lists(theme: Theme) -> void:
	theme.set_stylebox("panel", "ItemList", P.box(Color(P.INK, 0.55), P.RULE, 1, 8, 6))
	theme.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	var selected := P.box(Color(P.SCARF, 0.22), P.SCARF, 0, 6, 2)
	selected.border_width_left = 3
	theme.set_stylebox("selected", "ItemList", selected)
	theme.set_stylebox("selected_focus", "ItemList", selected)
	theme.set_stylebox("hovered", "ItemList", P.box(Color(P.BONE, 0.05), Color.TRANSPARENT, 0, 6, 2))
	theme.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	theme.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	theme.set_color("font_color", "ItemList", P.BONE_DIM)
	theme.set_color("font_hovered_color", "ItemList", P.BONE)
	theme.set_color("font_selected_color", "ItemList", P.BONE)
	theme.set_color("guide_color", "ItemList", Color(P.RULE, 0.6))
	theme.set_constant("v_separation", "ItemList", 6)
	theme.set_font_size("font_size", "ItemList", 19)

	theme.set_stylebox("panel", "PopupMenu", P.box(P.PANEL_RAISED, P.RULE, 1, 6, 6))
	theme.set_stylebox("hover", "PopupMenu", P.box(Color(P.SCARF, 0.3), Color.TRANSPARENT, 0, 6, 2))
	theme.set_color("font_color", "PopupMenu", P.BONE_DIM)
	theme.set_color("font_hover_color", "PopupMenu", P.BONE)


static func _inputs(theme: Theme) -> void:
	theme.set_stylebox("normal", "LineEdit", P.box(Color(P.INK, 0.8), P.RULE, 1, 10, 6))
	theme.set_stylebox("focus", "LineEdit", P.box(Color.TRANSPARENT, P.LAMP, 1, 10, 6))
	theme.set_color("font_color", "LineEdit", P.BONE)
	var track := P.box(P.RULE, Color.TRANSPARENT, 0, 0, 2)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", P.box(P.SCARF, Color.TRANSPARENT, 0, 0, 2))
	theme.set_stylebox("grabber_area_highlight", "HSlider", P.box(P.SCARF.lightened(0.15), Color.TRANSPARENT, 0, 0, 2))
	theme.set_stylebox("background", "ProgressBar", P.box(Color(P.INK, 0.8), P.RULE, 1, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", P.box(P.SCARF, Color.TRANSPARENT, 0, 0, 0))


static func _tabs(theme: Theme) -> void:
	theme.set_stylebox("panel", "TabContainer", P.box(Color(P.INK, 0.4), P.RULE, 1, 12, 10))
	theme.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	var unselected := P.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 12, 4)
	var hovered := P.box(Color(P.BONE, 0.04), Color.TRANSPARENT, 0, 12, 4)
	var selected := P.box(Color.TRANSPARENT, P.SCARF, 0, 12, 4)
	selected.border_width_bottom = 2
	for type_name: String in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_unselected", type_name, unselected)
		theme.set_stylebox("tab_hovered", type_name, hovered)
		theme.set_stylebox("tab_selected", type_name, selected)
		theme.set_stylebox("tab_focus", type_name, StyleBoxEmpty.new())
		theme.set_font("font", type_name, FELL)
		theme.set_font_size("font_size", type_name, 22)
		theme.set_color("font_selected_color", type_name, P.BONE)
		theme.set_color("font_unselected_color", type_name, P.FOG)
		theme.set_color("font_hovered_color", type_name, P.BONE)


static func _scrollbars(theme: Theme) -> void:
	for type_name: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type_name, P.box(Color(P.INK, 0.4), Color.TRANSPARENT, 0, 4, 4))
		theme.set_stylebox("grabber", type_name, P.box(Color(P.BONE, 0.18), Color.TRANSPARENT, 0, 4, 4))
		theme.set_stylebox("grabber_highlight", type_name, P.box(Color(P.BONE, 0.32), Color.TRANSPARENT, 0, 4, 4))
		theme.set_stylebox("grabber_pressed", type_name, P.box(Color(P.SCARF, 0.6), Color.TRANSPARENT, 0, 4, 4))


static func _dialogs(theme: Theme) -> void:
	var window := P.box(P.PANEL, P.RULE, 1, 14, 12)
	theme.set_stylebox("panel", "AcceptDialog", window)
	theme.set_stylebox("embedded_border", "Window", P.box(P.PANEL, P.RULE, 1, 0, 0))
	theme.set_stylebox("embedded_unfocused_border", "Window", P.box(P.PANEL, P.RULE, 1, 0, 0))
	theme.set_font("title_font", "Window", FELL)
	theme.set_color("title_color", "Window", P.BONE)


static func _variation(theme: Theme, variation: String, base: String) -> void:
	theme.set_type_variation(variation, base)
