# scripts/player.gd
# Aircraft CharacterBody2D — free 2D movement, networked, shoots bullets
extends CharacterBody2D

const SPEED        := 300.0
const BULLET_SCENE := preload("res://scenes/Bullet.tscn")

# Plane sprites — one per player_id, sourced from powers-and-effects branch
const PLANE_TEXTURES := {
	1: preload("res://assets/planes/red_plane.png"),
	2: preload("res://assets/planes/blue_plane.png"),
	3: preload("res://assets/planes/gold_plane.png"),
}

# Character stats ported from characters.js (powers-and-effects branch)
# speed_px  = speed_stat * 5   (stat 50-95 → 250-475 px/s)
# max_health = derived from shield stat: 40→3 hits, 60→4 hits, 90→5 hits
const CHARACTER_STATS := {
	1: {name = "Crimson Ace",     speed_px = 475, max_health = 3, attack = 60},
	2: {name = "Azure Guardian",  speed_px = 325, max_health = 5, attack = 50},
	3: {name = "Gilded Striker",  speed_px = 250, max_health = 4, attack = 95},
}

# Set by Level1 after spawning — drives color and authority
var player_id: int = 1

var health: int        = 3      # overwritten in _ready() from CHARACTER_STATS
var is_dead: bool      = false
var _base_speed: float = 300.0  # set from CHARACTER_STATS, mutated by Afterburner

# Skill state flags — written by skills.gd, read here
var is_shielded: bool = false   # Plasma Shield: absorbs next hit
var burst_mode: bool  = false   # Multi-Barrage: fires 3-shot spread


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Only the owning peer drives this node's input
	set_multiplayer_authority(player_id)

	# Apply character stats for this player_id
	var stats: Dictionary = CHARACTER_STATS[player_id]
	_base_speed = float(stats.speed_px)
	health       = stats.max_health

	# Apply the character's plane sprite (replaces placeholder Polygon2D)
	$Sprite2D.texture = PLANE_TEXTURES[player_id]

	# Register in group so enemies can locate the nearest target
	add_to_group("players")


# ── Per-frame ─────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if is_dead:
		return

	_handle_movement()
	_handle_shooting()
	_handle_skill()


# ── Movement ──────────────────────────────────────────────────────────────────

func _handle_movement() -> void:
	var dir := Vector2.ZERO

	# WASD
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0

	velocity = dir.normalized() * _base_speed
	move_and_slide()


# ── Shooting ──────────────────────────────────────────────────────────────────

var _shoot_cooldown: float = 0.0
const SHOOT_COOLDOWN := 0.25  # seconds between shots

func _handle_shooting() -> void:
	_shoot_cooldown -= get_physics_process_delta_time()
	if Input.is_key_pressed(KEY_SPACE) and _shoot_cooldown <= 0.0:
		_shoot_cooldown = SHOOT_COOLDOWN
		var origin: Vector2 = $GunPoint.global_position
		if burst_mode:
			# Multi-Barrage: 3 bullets in a spread (-15°, 0°, +15°)
			for angle_deg in [-15.0, 0.0, 15.0]:
				_fire_bullet.rpc(origin, player_id, deg_to_rad(angle_deg))
		else:
			_fire_bullet.rpc(origin, player_id, 0.0)


@rpc("any_peer", "call_local", "reliable")
func _fire_bullet(pos: Vector2, pid: int, angle_offset: float) -> void:
	var bullet: Node = BULLET_SCENE.instantiate()
	bullet.global_position = pos
	bullet.rotation        = angle_offset
	bullet.player_id       = pid
	get_tree().current_scene.add_child(bullet)
	SignalBus.bullet_fired.emit(pid, pos)


# ── Skill activation ──────────────────────────────────────────────────────────

func _handle_skill() -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		$Skills.try_activate()


# ── Damage & Death ────────────────────────────────────────────────────────────

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int) -> void:
	if is_dead:
		return

	# Plasma Shield (Azure Guardian) — absorbs one hit then breaks
	if is_shielded:
		is_shielded = false
		return

	health -= amount
	health = max(health, 0)

	SignalBus.player_health_updated.emit(player_id, health)

	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	SignalBus.player_died.emit(player_id)
	# Hide the plane; Level1 handles respawn / game-over logic
	hide()
	set_physics_process(false)
