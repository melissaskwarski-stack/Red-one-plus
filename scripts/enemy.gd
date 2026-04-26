# scripts/enemy.gd
# Enemy aircraft — enters from right, patrols, shoots toward nearest player
extends CharacterBody2D

const SPEED_ENTRY   := 150.0
const SPEED_PATROL  := 80.0
const PATROL_RANGE  := 200.0
const SHOOT_INTERVAL := 3.0

const BULLET_SCENE := preload("res://scenes/Bullet.tscn")

var health: int = 3
var is_dead: bool = false

# Patrol state
var patrol_active: bool = false
var patrol_origin: Vector2 = Vector2.ZERO
var patrol_direction: float = -1.0   # -1 = left, 1 = right

# Shoot timer
var _shoot_timer: float = SHOOT_INTERVAL

# Shared score across all enemy instances — level1.gd may also track this
static var total_score: int = 0


# ── Per-frame ─────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not patrol_active:
		_enter_screen()
	else:
		_patrol()
		_tick_shoot(delta)

	move_and_slide()


# ── Entry ─────────────────────────────────────────────────────────────────────

func _enter_screen() -> void:
	# Fly leftward until on screen, then lock in patrol origin
	velocity = Vector2(-SPEED_ENTRY, 0.0)
	if global_position.x < 800.0:
		patrol_origin = global_position
		patrol_active = true
		_shoot_timer = SHOOT_INTERVAL   # first shot after full interval


# ── Patrol ────────────────────────────────────────────────────────────────────

func _patrol() -> void:
	velocity = Vector2(patrol_direction * SPEED_PATROL, 0.0)

	if global_position.x <= patrol_origin.x - PATROL_RANGE:
		patrol_direction = 1.0    # hit left edge — turn right
	elif global_position.x >= patrol_origin.x + PATROL_RANGE:
		patrol_direction = -1.0   # hit right edge — turn left


# ── Shooting ──────────────────────────────────────────────────────────────────

func _tick_shoot(delta: float) -> void:
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = SHOOT_INTERVAL
		_shoot_at_nearest_player()


func _shoot_at_nearest_player() -> void:
	var target: Node2D = _get_nearest_player() as Node2D
	if target == null:
		return

	var dir: Vector2 = (target.global_position - global_position).normalized()

	var bullet: Node = BULLET_SCENE.instantiate()
	bullet.global_position = global_position
	bullet.rotation = dir.angle()   # bullet.gd uses transform.x so this aims it
	bullet.player_id = 0            # 0 = enemy bullet
	get_tree().current_scene.add_child(bullet)


func _get_nearest_player() -> Node:
	var nearest: Node = null
	var nearest_dist := INF
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_dead:
			continue
		var d := global_position.distance_to(p.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = p
	return nearest


# ── Damage & Death ────────────────────────────────────────────────────────────

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount
	health = max(health, 0)

	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true

	total_score += 100
	SignalBus.enemy_destroyed.emit(global_position)
	SignalBus.score_changed.emit(total_score)

	queue_free()
