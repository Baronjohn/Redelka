class_name BattleUI
extends Control

signal action_requested(action: String)
signal sub_action_requested(action: String)
signal wait_requested
signal spell_selected(spell_id: String)
signal item_selected(item_id: String)
signal back_requested

@onready var main_menu: HBoxContainer = $CommandPanel/Margin/VBox/CommandBar/MainMenu
@onready var action_menu: HBoxContainer = $CommandPanel/Margin/VBox/CommandBar/ActionMenu
@onready var spell_menu: ItemList = $CommandPanel/Margin/VBox/SpellMenu
@onready var item_menu: ItemList = $CommandPanel/Margin/VBox/ItemMenu
@onready var back_button: Button = $CommandPanel/Margin/VBox/CommandBar/BackButton
@onready var log_label: RichTextLabel = $LogPanel/LogLabel
@onready var turn_order_label: Label = $TopLeftHud/TurnOrderPanel/Margin/TurnOrderLabel
@onready var ally_status_box: VBoxContainer = $TopLeftHud/AllyStatusPanel/Margin/AllyStatusBox
@onready var turn_order_panel: PanelContainer = $TopLeftHud/TurnOrderPanel
@onready var ally_status_panel: PanelContainer = $TopLeftHud/AllyStatusPanel
@onready var top_left_hud: VBoxContainer = $TopLeftHud
@onready var command_panel: PanelContainer = $CommandPanel

@onready var move_button: Button = $CommandPanel/Margin/VBox/CommandBar/MainMenu/MoveButton
@onready var action_button: Button = $CommandPanel/Margin/VBox/CommandBar/MainMenu/ActionButton
@onready var wait_button: Button = $CommandPanel/Margin/VBox/CommandBar/MainMenu/WaitButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	top_left_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_order_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_order_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ally_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ally_status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$LogPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	command_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	main_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	action_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	spell_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	item_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	move_button.pressed.connect(func() -> void: action_requested.emit("move"))
	action_button.pressed.connect(func() -> void: action_requested.emit("action"))
	wait_button.pressed.connect(func() -> void: wait_requested.emit())
	$CommandPanel/Margin/VBox/CommandBar/ActionMenu/AttackButton.pressed.connect(func() -> void: sub_action_requested.emit("attack"))
	$CommandPanel/Margin/VBox/CommandBar/ActionMenu/SpellButton.pressed.connect(func() -> void: sub_action_requested.emit("spell"))
	$CommandPanel/Margin/VBox/CommandBar/ActionMenu/SkillButton.pressed.connect(func() -> void: sub_action_requested.emit("skill"))
	$CommandPanel/Margin/VBox/CommandBar/ActionMenu/ItemButton.pressed.connect(func() -> void: sub_action_requested.emit("item"))
	$CommandPanel/Margin/VBox/CommandBar/ActionMenu/RetreatButton.pressed.connect(func() -> void: sub_action_requested.emit("retreat"))
	back_button.pressed.connect(func() -> void: back_requested.emit())
	spell_menu.item_selected.connect(_on_spell_selected)
	item_menu.item_selected.connect(_on_item_selected)
	hide_menus()


func show_main_menu(unit: CombatUnit, allow_retreat: bool) -> void:
	hide_menus()
	main_menu.visible = true
	move_button.disabled = unit.has_moved
	action_button.disabled = unit.has_acted
	$CommandPanel/Margin/VBox/CommandBar/ActionMenu/RetreatButton.disabled = not allow_retreat
	_set_back_visible(false)


func show_action_submenu(unit: CombatUnit, allow_retreat: bool, can_attack: bool) -> void:
	hide_menus()
	action_menu.visible = true
	$CommandPanel/Margin/VBox/CommandBar/ActionMenu/AttackButton.disabled = unit.has_acted or not can_attack
	$CommandPanel/Margin/VBox/CommandBar/ActionMenu/SpellButton.disabled = unit.has_acted
	$CommandPanel/Margin/VBox/CommandBar/ActionMenu/SkillButton.disabled = unit.has_acted or unit.skill == null
	$CommandPanel/Margin/VBox/CommandBar/ActionMenu/ItemButton.disabled = unit.has_acted
	$CommandPanel/Margin/VBox/CommandBar/ActionMenu/RetreatButton.disabled = unit.has_acted or not allow_retreat
	_set_back_visible(true)


func show_spell_menu(spells: Array) -> void:
	hide_menus()
	spell_menu.clear()
	for spell_variant: Variant in spells:
		var spell: SpellData = spell_variant as SpellData
		var index := spell_menu.item_count
		spell_menu.add_item("%s (MP %d)" % [spell.display_name, spell.mp_cost])
		spell_menu.set_item_metadata(index, spell.id)
	spell_menu.visible = true
	_set_back_visible(true)


func show_item_menu(inventory: Dictionary, item_defs: Dictionary) -> void:
	hide_menus()
	item_menu.clear()
	for item_id: String in inventory.keys():
		var count := int(inventory[item_id])
		if count <= 0:
			continue
		var item: ItemData = item_defs[item_id]
		var index := item_menu.item_count
		item_menu.add_item("%s x%d" % [item.display_name, count])
		item_menu.set_item_metadata(index, item_id)
	item_menu.visible = true
	_set_back_visible(true)


func show_back_only() -> void:
	hide_menus()
	_set_back_visible(true)


func hide_menus() -> void:
	main_menu.visible = false
	action_menu.visible = false
	spell_menu.visible = false
	item_menu.visible = false
	back_button.visible = false


func _set_back_visible(visible: bool) -> void:
	back_button.visible = visible


func append_log(text: String) -> void:
	log_label.append_text(text + "\n")
	log_label.scroll_to_line(maxi(log_label.get_line_count() - 1, 0))


func update_turn_order(order: Array[String], units: Dictionary) -> void:
	var names: PackedStringArray = []
	for runtime_id: String in order:
		if units.has(runtime_id):
			names.append(units[runtime_id].display_name)
	turn_order_label.text = "Turn: " + ", ".join(names)


func update_ally_status(allies: Array[CombatUnit], active_runtime_id: String = "") -> void:
	for child: Node in ally_status_box.get_children():
		child.queue_free()
	var characters := DataLoader.load_characters()
	for ally: CombatUnit in allies:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(48, 48)
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if characters.has(ally.source_id):
			var character: CharacterData = characters[ally.source_id]
			if not character.portrait_path.is_empty() and ResourceLoader.exists(character.portrait_path):
				portrait.texture = load(character.portrait_path)
		row.add_child(portrait)
		var label := Label.new()
		label.text = "%s  HP %d/%d  MP %d/%d%s" % [
			ally.display_name,
			ally.current_hp,
			ally.max_hp,
			ally.current_mp,
			ally.max_mp,
			" (KO)" if ally.is_ko else "",
		]
		row.add_child(label)
		if ally.runtime_id == active_runtime_id:
			var panel := PanelContainer.new()
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.95, 0.82, 0.28, 0.25)
			style.set_border_width_all(2)
			style.border_color = Color(0.95, 0.82, 0.28, 0.9)
			panel.add_theme_stylebox_override("panel", style)
			panel.add_child(row)
			ally_status_box.add_child(panel)
		else:
			ally_status_box.add_child(row)


func _on_spell_selected(index: int) -> void:
	spell_selected.emit(str(spell_menu.get_item_metadata(index)))


func _on_item_selected(index: int) -> void:
	item_selected.emit(str(item_menu.get_item_metadata(index)))


func is_pointer_over_interactive_ui(screen_pos: Vector2) -> bool:
	if back_button.visible and back_button.get_global_rect().has_point(screen_pos):
		return true
	for menu: Control in [main_menu, action_menu, spell_menu, item_menu]:
		if menu.visible and menu.get_global_rect().has_point(screen_pos):
			return true
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	var node: Node = hovered
	while node != null and node != self:
		if node is Button or node is ItemList:
			return true
		node = node.get_parent()
	return false
