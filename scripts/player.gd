# scripts/player.gd
# Aircraft CharacterBody2D — merged: networking + health from main,
# acceleration-based movement + screen clamp + sprite tilt from movement branch
extends CharacterBody2D

# ── Tunables ──────────────────────────────────────────────────────────────────
@export var speed: float        = 400.0    # pixels/s at full throttle
@export var acceleration: float = 1200.0   # pixels/s² ramp-up
@export var friction: float     = 1800.0   # pixels/s² ramp-down

const BULLET_SCENE   := preload("res://scenes/Bullet.tscn")
const SHOOT_COOLDOWN := 0.25

# ── Player identity (set by Level1 after spawning) ────────────────────────────
var player_id: int = 1       # 1=red  2=blue  3=green — drives authority + color

# ── Health / death ────────────────────────────────────────────────────────────
var health: int  = 3
var is_dead: bool = false

# ── Internal movement state ───────────────────────────────────────────────────
var _input_prefix: String = ""              # "p1_", "p2_", "p3_"
var _screen_rect: Rect2   = Rect2()
var _shoot_cooldown: float = 0.0

# Virtual-joystick / AI injection (set each frame, reset after _physics_process)
var _injected_direction: Vector2 = Vector2.ZERO
var _has_injected_input: bool    = false

@onready var _sprite: Node = $Sprite2D


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_multiplayer_authority(player_id)
	_input_prefix = "p%d_" % player_id        # matches action-map names p1_move_up etc.
	_screen_rect  = _get_screen_rect()
	_sprite.modulate = NetworkManager.get_player_color(player_id)
	add_to_group("players")


# ── Per-frame ─────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		return

	var direction := _get_direction()

	# Acceleration-based movement (collaborator improvement)
	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_clamp_to_screen()
	_tilt_sprite(direction)

	# Reset injection flag — falls back to keyboard next frame if joystick goes silent
	_has_injected_input = false

	_handle_shooting(delta)


# ── Input ─────────────────────────────────────────────────────────────────────

func _get_direction() -> Vector2:
	# Virtual joystick / AI takes priority when injected this frame
	if _has_injected_input and _injected_direction != Vector2.ZERO:
		return _injected_direction

	# Keyboard: WASD + Arrow keys via action map, with raw-key fallback
	var right := _axis(_input_prefix + "move_right", _input_prefix + "move_left")
	var down  := _axis(_input_prefix + "move_down",  _input_prefix + "move_up")

	# Raw key fallback (works even without a configured InputMap)
	if right == 0.0:
		right = float(Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right")) \
		      - float(Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"))
	if down == 0.0:
		down  = float(Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down")) \
		      - float(Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"))

	return Vector2(right, down).normalized()


func _axis(pos_action: String, neg_action: String) -> float:
	var pos := Input.get_action_strength(pos_action) if InputMap.has_action(pos_action) else 0.0
	var neg := Input.get_action_strength(neg_action) if InputMap.has_action(neg_action) else 0.0
	return pos - neg


# ── Screen clamping ───────────────────────────────────────────────────────────

func _clamp_to_screen() -> void:
	var margin := 20.0
	position.x = clamp(position.x, _screen_rect.position.x + margin, _screen_rect.end.x - margin)
	position.y = clamp(position.y, _screen_rect.position.y + margin, _screen_rect.end.y - margin)


func _get_screen_rect() -> Rect2:
	return Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)


# ── Visual feedback ───────────────────────────────────────────────────────────

func _tilt_sprite(direction: Vector2) -> void:
	var target_rotation := direction.x * deg_to_rad(12.0)
	_sprite.rotation = lerp(_sprite.rotation, target_rotation, 0.15)


# ── Shooting ──────────────────────────────────────────────────────────────────

func _handle_shooting(delta: float) -> void:
	_shoot_cooldown -= delta
	if Input.is_key_pressed(KEY_SPACE) and _shoot_cooldown <= 0.0:
		_shoot_cooldown = SHOOT_COOLDOWN
		_fire_bullet.rpc($GunPoint.global_position, player_id)


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
	health = max(health - amount, 0)
	SignalBus.player_health_updated.emit(player_id, health)
	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	SignalBus.player_died.emit(player_id)
	hide()
	set_physics_process(false)


# ── Public API — Virtual Joystick / AI controller ─────────────────────────────

## Inject a direction from a virtual joystick or AI controller each frame.
## If the joystick stops calling this, the player automatically falls back to keyboard.
func inject_direction(dir: Vector2) -> void:
	_injected_direction = dir
	_has_injected_input = true
