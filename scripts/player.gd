# scripts/player.gd
# Aircraft CharacterBody2D — free 2D movement, networked, shoots bullets
extends CharacterBody2D

const SPEED       := 300.0
const BULLET_SCENE := preload("res://scenes/Bullet.tscn")

# Set by Level1 after spawning — drives color and authority
var player_id: int = 1

var health: int = 3
var is_dead: bool = false


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Only the owning peer drives this node's input
	set_multiplayer_authority(player_id)

	# Tint the plane sprite to the player's assigned color
	$Sprite2D.modulate = NetworkManager.get_player_color(player_id)


# ── Per-frame ─────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if is_dead:
		return

	_handle_movement()
	_handle_shooting()


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

	velocity = dir.normalized() * SPEED
	move_and_slide()


# ── Shooting ──────────────────────────────────────────────────────────────────

var _shoot_cooldown: float = 0.0
const SHOOT_COOLDOWN := 0.25  # seconds between shots

func _handle_shooting() -> void:
	_shoot_cooldown -= get_physics_process_delta_time()
	if Input.is_key_pressed(KEY_SPACE) and _shoot_cooldown <= 0.0:
		_shoot_cooldown = SHOOT_COOLDOWN
		_fire_bullet.rpc(global_position, player_id)


@rpc("any_peer", "call_local", "reliable")
func _fire_bullet(pos: Vector2, pid: int) -> void:
	var bullet: Node = BULLET_SCENE.instantiate()
	bullet.global_position = pos
	bullet.player_id = pid
	get_tree().current_scene.add_child(bullet)
	SignalBus.bullet_fired.emit(pid, pos)


# ── Damage & Death ────────────────────────────────────────────────────────────

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int) -> void:
	if is_dead:
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
