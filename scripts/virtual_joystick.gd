extends Node2D

# ── Layout ─────────────────────────────────────────────────────────────────────
@export var base_radius: float  = 80.0   # outer ring radius
@export var knob_radius: float  = 30.0   # draggable knob radius
@export var dead_zone: float    = 0.15   # fraction of base_radius ignored

# ── Colors ─────────────────────────────────────────────────────────────────────
@export var base_color: Color = Color(1, 1, 1, 0.25)
@export var knob_color: Color = Color(1, 1, 1, 0.55)

# ── Runtime state ──────────────────────────────────────────────────────────────
var _direction: Vector2 = Vector2.ZERO   # normalized output, read by Player
var _touch_index: int   = -1             # which finger owns this joystick
var _anchor: Vector2    = Vector2.ZERO   # where the touch started
var _knob_offset: Vector2 = Vector2.ZERO # current knob draw offset


func _ready() -> void:
	# Only show on touch-capable devices; hide on desktop.
	visible = DisplayServer.is_touchscreen_available()


# ── Touch input ────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var local_pos := to_local(event.position)

	if event.pressed and _touch_index == -1:
		# Accept the touch if it starts within the base circle.
		if local_pos.length() <= base_radius * 1.5:
			_touch_index = event.index
			_anchor      = local_pos
			_knob_offset = Vector2.ZERO
	elif not event.pressed and event.index == _touch_index:
		_release()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return
	var delta: Vector2 = to_local(event.position) - _anchor
	_knob_offset = delta.limit_length(base_radius)
	_direction   = _compute_direction(delta)
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_direction   = Vector2.ZERO
	_knob_offset = Vector2.ZERO
	queue_redraw()


func _compute_direction(delta: Vector2) -> Vector2:
	var fraction := delta.length() / base_radius
	if fraction < dead_zone:
		return Vector2.ZERO
	return delta.normalized()


# ── Public API ─────────────────────────────────────────────────────────────────

## Returns the normalized direction this joystick is pushed (Vector2.ZERO at rest).
func get_direction() -> Vector2:
	return _direction


# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not visible:
		return
	# Outer base ring
	draw_circle(Vector2.ZERO, base_radius, base_color)
	draw_arc(Vector2.ZERO, base_radius, 0.0, TAU, 64, Color(1, 1, 1, 0.5), 2.0)
	# Draggable knob
	draw_circle(_knob_offset, knob_radius, knob_color)
