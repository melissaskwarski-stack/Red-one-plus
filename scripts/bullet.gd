# scripts/bullet.gd
# Projectile fired by a player — travels right, destroys enemies on contact
extends Area2D

const SPEED := 600.0

# Set by player.gd at instantiation — tracks which player fired this bullet
var player_id: int = 0


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Silent self-destruct after 2 seconds if nothing was hit
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		queue_free()


# ── Movement ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Travel along local forward axis — rotation set at spawn time.
	# Player bullets (rotation 0) fly right; enemy bullets aim at nearest player.
	position += transform.x * SPEED * delta


# ── Collision ─────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	# body must be on layer 2 (enemy layer) — enforced by collision_mask in scene
	# SignalBus.enemy_destroyed is emitted from enemy.gd, not here
	if body.has_method("take_damage"):
		body.take_damage.rpc(1)
	queue_free()
