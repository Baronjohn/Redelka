class_name CombatConstants
extends RefCounted

const GRID_SIZE: int = 6
const TILE_SIZE: float = 1.4

const BASE_HIT: float = 70.0
const BASE_SPELL_HIT: float = 75.0
const HIT_FLOOR: float = 10.0
const HIT_CEILING: float = 95.0
const LUK_WEIGHT: float = 0.5
const VIT_WEIGHT: float = 0.4
const INT_FACTOR: float = 0.03
const HP_PER_VIT: int = 8
const MP_PER_RES: int = 4
const HP_BASE: int = 20
const MP_BASE: int = 10

const RETREAT_BASE: float = 40.0
const EXTRA_TURN_AGI_FACTOR: float = 1.35

const ALLY_COLOR: Color = Color(0.25, 0.55, 0.95)
const ENEMY_COLOR: Color = Color(0.9, 0.25, 0.25)
const TURN_HIGHLIGHT_COLOR: Color = Color(1.0, 0.92, 0.35)
const ENEMY_REMOVE_DELAY: float = 2.0
const TURN_ACTIVE_SCALE: float = 1.1
