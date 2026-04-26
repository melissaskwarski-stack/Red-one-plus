# scripts/character_select.gd
# Character selection screen — each player picks a pilot before Level1 loads.
# UI is built entirely in code (no extra .tscn nodes needed).
extends Control

const PLANE_TEXTURES := {
	1: preload("res://assets/planes/red_plane.png"),
	2: preload("res://assets/planes/blue_plane.png"),
	3: preload("res://assets/planes/gold_plane.png"),
}

const CHARACTER_STATS := {
	1: {char_name = "Crimson Ace",    speed_px = 475, max_health = 3, attack = 60, color = Color(1.0, 0.35, 0.35)},
	2: {char_name = "Azure Guardian", speed_px = 325, max_health = 5, attack = 50, color = Color(0.35, 0.65, 1.0)},
	3: {char_name = "Gilded Striker", speed_px = 250, max_health = 4, attack = 95, color = Color(1.0, 0.82, 0.25)},
}

var _status_label: Label
var _selected: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	SignalBus.character_choices_updated.connect(_on_choices_updated)


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Root vbox — fills the screen
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 24)
	add_child(root)

	# Title
	var title := Label.new()
	title.text = "CHOOSE YOUR PILOT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(title)

	# Cards row
	var cards_row := HBoxContainer.new()
	cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_row.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	cards_row.alignment             = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 48)
	root.add_child(cards_row)

	for char_id in [1, 2, 3]:
		cards_row.add_child(_build_card(char_id))

	# Status / waiting label
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	root.add_child(_status_label)


func _build_card(char_id: int) -> Control:
	var stats: Dictionary = CHARACTER_STATS[char_id]

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 320)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Plane sprite
	var tex := TextureRect.new()
	tex.texture                 = PLANE_TEXTURES[char_id]
	tex.stretch_mode            = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size     = Vector2(190, 130)
	tex.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	vbox.add_child(tex)

	# Character name
	var name_lbl := Label.new()
	name_lbl.text                      = stats.char_name
	name_lbl.horizontal_alignment      = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", stats.color)
	vbox.add_child(name_lbl)

	# Stats
	for pair in [
		["Speed",  "%d px/s" % stats.speed_px],
		["Health", "%d HP"   % stats.max_health],
		["Attack", str(stats.attack)],
	]:
		var lbl := Label.new()
		lbl.text                 = "%s:  %s" % [pair[0], pair[1]]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)

	# Select button
	var btn := Button.new()
	btn.text = "SELECT"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_select.bind(char_id))
	vbox.add_child(btn)

	return card


# ── Selection logic ───────────────────────────────────────────────────────────

func _on_select(char_id: int) -> void:
	if _selected:
		return  # prevent double-click
	_selected = true

	NetworkManager.submit_character_choice(char_id)

	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		# Solo or host: check immediately whether everyone has chosen
		_check_all_ready()
	else:
		_status_label.text = "Waiting for other players to choose…"


func _on_choices_updated() -> void:
	# Only the host decides when to launch
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_check_all_ready()


func _check_all_ready() -> void:
	var total: int = maxi(NetworkManager.player_ids.size(), 1)
	if NetworkManager.character_choices.size() >= total:
		_launch_level.rpc()


# ── Scene transition ──────────────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _launch_level() -> void:
	get_tree().change_scene_to_file("res://scenes/Level1.tscn")
