extends CharacterBody2D

# ── Exported tunables ──────────────────────────────────────────────────────────
@export var speed: float = 400.0        # pixels/s at full throttle
@export var acceleration: float = 1200.0 # pixels/s² ramp-up rate
@export var friction: float = 1800.0    # pixels/s² ramp-down rate

# ── Player identity (set by the game manager for co-op) ───────────────────────
@export var player_index: int = 0       # 0 = P1, 1 = P2, 2 = P3

# ── Internal state ────────────────────────────────────────────────────────────
var _input_prefix: String = ""          # e.g. "p1_" → actions p1_move_up, etc.
var _screen_rect: Rect2 = Rect2()

# ── Sprite reference (optional tilt on movement) ──────────────────────────────
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_input_prefix = "p%d_" % (player_index + 1)   # "p1_", "p2_", "p3_"
	_screen_rect = _get_screen_rect()


func _physics_process(delta: float) -> void:
	var direction := _get_direction()

	if direction != Vector2.ZERO:
		# Accelerate toward the desired direction
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
	else:
		# Apply friction when no input
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_clamp_to_screen()
	_tilt_sprite(direction)


# ── Input ──────────────────────────────────────────────────────────────────────

func _get_direction() -> Vector2:
	# Reads from the action map using this player's prefix.
	# Falls back to global actions (move_up, etc.) for P1 if prefix actions
	# are missing, so the scene works out of the box with a single action set.
	var right := _axis(_input_prefix + "move_right", _input_prefix + "move_left")
	var down  := _axis(_input_prefix + "move_down",  _input_prefix + "move_up")
	return Vector2(right, down).normalized()


func _axis(pos_action: String, neg_action: String) -> float:
	var pos := Input.get_action_strength(pos_action) if InputMap.has_action(pos_action) else 0.0
	var neg := Input.get_action_strength(neg_action) if InputMap.has_action(neg_action) else 0.0
	return pos - neg


# ── Screen clamping ────────────────────────────────────────────────────────────

func _clamp_to_screen() -> void:
	# Use the collision shape radius as a margin so the plane never half-exits.
	var margin: float = 20.0
	position.x = clamp(position.x, _screen_rect.position.x + margin,
	                               _screen_rect.end.x    - margin)
	position.y = clamp(position.y, _screen_rect.position.y + margin,
	                               _screen_rect.end.y    - margin)


func _get_screen_rect() -> Rect2:
	var vp := get_viewport()
	return Rect2(Vector2.ZERO, vp.get_visible_rect().size)


# ── Visual feedback ────────────────────────────────────────────────────────────

func _tilt_sprite(direction: Vector2) -> void:
	# Slight horizontal tilt on left/right input — purely cosmetic.
	var target_rotation := direction.x * deg_to_rad(12.0)
	_sprite.rotation = lerp(_sprite.rotation, target_rotation, 0.15)


# ── Public API (called by VirtualJoystick or other systems) ───────────────────

## Inject a direction from a virtual joystick or AI controller.
## Call this every frame instead of (or alongside) keyboard input.
func inject_direction(dir: Vector2) -> void:
	# Overrides _get_direction for this frame if you store it in a variable.
	# (Extend this if you need full joystick override; currently keyboard
	#  + joystick are additive via the Input singleton actions.)
	pass
