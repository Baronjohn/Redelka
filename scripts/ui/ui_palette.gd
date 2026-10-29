class_name UiPalette
extends RefCounted

## Shared UI colours: the game's night palette (fog, bone, Holt's lamp, Mira's scarf).
## The project theme (UiTheme) and any code-built panel take their colours from here.

const INK: Color = Color(0.045, 0.05, 0.062, 1.0)
const PANEL: Color = Color(0.07, 0.075, 0.09, 0.96)
const PANEL_RAISED: Color = Color(0.105, 0.11, 0.128, 0.96)
const RULE: Color = Color(0.22, 0.23, 0.26, 1.0)
const FOG: Color = Color(0.55, 0.59, 0.64, 1.0)
const BONE: Color = Color(0.87, 0.84, 0.78, 1.0)
const BONE_DIM: Color = Color(0.68, 0.65, 0.6, 1.0)
## Warm accent: the active unit or the selected character.
const LAMP: Color = Color(0.89, 0.63, 0.35, 1.0)
## Cold accent: focus, the selected tab or row, rules under headings.
const SCARF: Color = Color(0.66, 0.2, 0.17, 1.0)
const GOOD: Color = Color(0.6, 0.72, 0.55, 1.0)
const DANGER: Color = Color(0.84, 0.43, 0.38, 1.0)
const WATER: Color = Color(0.42, 0.55, 0.66, 1.0)


static func box(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0,
		margin_h: float = 12.0, margin_v: float = 8.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	style.anti_aliasing = false
	return style


## A card that is "the one in use": the active unit, the selected party member.
static func highlight_card(margin: float = 0.0) -> StyleBoxFlat:
	return box(Color(LAMP, 0.12), LAMP, 2, margin, margin)


## A resting card on a panel.
static func plain_card(margin: float = 0.0) -> StyleBoxFlat:
	return box(PANEL_RAISED, RULE, 1, margin, margin)
