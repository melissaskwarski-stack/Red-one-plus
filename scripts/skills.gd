# scripts/skills.gd
# Character skill system — ported from skills.js (powers-and-effects branch)
# Attached as a child of Player. Triggered by player.gd on Shift key press.
extends Node

# ── Skill definitions (mirrors characters.js archetypes) ─────────────────────
const SKILL_DATA := {
	1: {name = "Afterburner",   duration = 3.0, cooldown = 10.0},
	2: {name = "Plasma Shield", duration = 3.0, cooldown = 15.0},
	3: {name = "Multi-Barrage", duration = 5.0, cooldown =  8.0},
}

# ── State ─────────────────────────────────────────────────────────────────────
var cooldown_remaining: float = 0.0
var skill_active: bool        = false

# Cached reference to the owning player node
var _player: CharacterBody2D


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_player = get_parent()


func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(cooldown_remaining - delta, 0.0)
		SignalBus.skill_cooldown_updated.emit(_player.player_id, cooldown_remaining)


# ── Public API ────────────────────────────────────────────────────────────────

## Called by player.gd when the owner presses Shift.
## Returns false (with no effect) if still on cooldown.
func try_activate() -> bool:
	if cooldown_remaining > 0.0 or skill_active:
		return false
	_activate()
	return true


# ── Internal activation ───────────────────────────────────────────────────────

func _activate() -> void:
	var data: Dictionary = SKILL_DATA[_player.player_id]
	skill_active       = true
	cooldown_remaining = data.cooldown
	SignalBus.powerup_activated.emit(_player.player_id, data.name)

	match _player.player_id:
		1: _afterburner(data.duration)
		2: _plasma_shield(data.duration)
		3: _multi_barrage(data.duration)


# ── Afterburner — Crimson Ace — 2× speed for 3 s ─────────────────────────────

func _afterburner(duration: float) -> void:
	var original_speed: float = _player._base_speed
	_player._base_speed *= 2.0

	await get_tree().create_timer(duration).timeout

	_player._base_speed = original_speed
	skill_active = false
	SignalBus.powerup_expired.emit(_player.player_id, "Afterburner")


# ── Plasma Shield — Azure Guardian — absorbs 1 hit or expires after 3 s ──────

func _plasma_shield(duration: float) -> void:
	_player.is_shielded = true

	await get_tree().create_timer(duration).timeout

	# If the shield was already consumed by a hit, is_shielded is already false
	if _player.is_shielded:
		_player.is_shielded = false
	skill_active = false
	SignalBus.powerup_expired.emit(_player.player_id, "Plasma Shield")


# ── Multi-Barrage — Gilded Striker — 3-shot spread for 5 s ───────────────────

func _multi_barrage(duration: float) -> void:
	_player.burst_mode = true

	await get_tree().create_timer(duration).timeout

	_player.burst_mode = false
	skill_active = false
	SignalBus.powerup_expired.emit(_player.player_id, "Multi-Barrage")
