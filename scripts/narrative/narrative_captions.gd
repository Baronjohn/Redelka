class_name NarrativeCaptions
extends CanvasLayer

## Draws one-shot cutscene lines (`actor_say`) as subtitles and gothic title cards.
## Sits above the narrative theater fade and below the dialog panel.

const TITLE_FONT: FontFile = preload("res://assets/fonts/unifraktur_maguntia.ttf")
const BODY_FONT: FontFile = preload("res://assets/fonts/im_fell_english.ttf")
const ITALIC_FONT: FontFile = preload("res://assets/fonts/im_fell_english_italic.ttf")
const SUBTITLE_FADE: float = 0.25
const TITLE_COLOR: Color = Color(0.86, 0.82, 0.74, 1.0)
const TITLE_RULE_COLOR: Color = Color(0.55, 0.12, 0.1, 1.0)

var _subtitle: Label
var _title_root: VBoxContainer
var _title_overline: Label
var _title_label: Label
var _title_rule: ColorRect
var _title_subline: Label
var _subtitle_tween: Tween
var _subtitle_serial: int = 0


func _ready() -> void:
	layer = 78
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_subtitle()
	_build_title_card()


func show_line(speaker_meta: Dictionary, text: String, internal: bool, duration: float) -> void:
	_subtitle_serial += 1
	var serial := _subtitle_serial
	if internal:
		_subtitle.text = text
		_subtitle.add_theme_font_override("font", ITALIC_FONT)
	else:
		_subtitle.text = "%s: %s" % [str(speaker_meta.get("name", "")), text]
		_subtitle.add_theme_font_override("font", BODY_FONT)
	_subtitle.modulate = (speaker_meta.get("color", TITLE_COLOR) as Color).lightened(0.25)
	_subtitle.modulate.a = 0.0
	_subtitle.visible = true
	_fade_subtitle(1.0)
	await get_tree().create_timer(maxf(duration - SUBTITLE_FADE, 0.1)).timeout
	if serial == _subtitle_serial:
		_fade_subtitle(0.0)


func clear_line() -> void:
	_subtitle_serial += 1
	_subtitle.visible = false


## Shows a title card (`overline` small caps, `title` blackletter, `subline` small) and waits
## until it has faded back out.
func show_title_card(overline: String, title: String, subline: String, hold: float, fade: float) -> void:
	_title_overline.text = overline
	_title_overline.visible = not overline.is_empty()
	_title_label.text = title
	_title_subline.text = subline
	_title_subline.visible = not subline.is_empty()
	_title_rule.visible = not subline.is_empty() or not overline.is_empty()
	_title_root.modulate.a = 0.0
	_title_root.visible = true
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_property(_title_root, "modulate:a", 1.0, fade)
	tween.tween_interval(hold)
	tween.tween_property(_title_root, "modulate:a", 0.0, fade)
	await tween.finished
	_title_root.visible = false


func _fade_subtitle(target_alpha: float) -> void:
	if _subtitle_tween != null and _subtitle_tween.is_valid():
		_subtitle_tween.kill()
	_subtitle_tween = create_tween()
	_subtitle_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_subtitle_tween.tween_property(_subtitle, "modulate:a", target_alpha, SUBTITLE_FADE)
	if target_alpha <= 0.0:
		_subtitle_tween.tween_callback(_subtitle.hide)


func _build_subtitle() -> void:
	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.anchor_left = 0.1
	_subtitle.anchor_right = 0.9
	_subtitle.offset_left = 0.0
	_subtitle.offset_right = 0.0
	_subtitle.offset_top = -120.0
	_subtitle.offset_bottom = -48.0
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_theme_font_size_override("font_size", 30)
	_subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_subtitle.add_theme_constant_override("outline_size", 8)
	_subtitle.visible = false
	add_child(_subtitle)


func _build_title_card() -> void:
	_title_root = VBoxContainer.new()
	_title_root.name = "TitleCard"
	_title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_root.add_theme_constant_override("separation", 14)
	_title_root.visible = false
	add_child(_title_root)

	_title_overline = _make_title_label(BODY_FONT, 26)
	_title_overline.uppercase = true
	_title_root.add_child(_title_overline)

	_title_label = _make_title_label(TITLE_FONT, 112)
	_title_root.add_child(_title_label)

	var rule_row := CenterContainer.new()
	rule_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_rule = ColorRect.new()
	_title_rule.color = TITLE_RULE_COLOR
	_title_rule.custom_minimum_size = Vector2(260.0, 2.0)
	_title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_row.add_child(_title_rule)
	_title_root.add_child(rule_row)

	_title_subline = _make_title_label(ITALIC_FONT, 28)
	_title_root.add_child(_title_subline)


func _make_title_label(font: Font, size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TITLE_COLOR)
	return label
