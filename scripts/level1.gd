# scripts/level1.gd
# Root level scene — spawns players, runs 3 enemy waves, manages camera zoom
extends Node2D

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE  := preload("res://scenes/Enemy.tscn")
const HUD_SCENE    := preload("res://scenes/HUD.tscn")

const WAVE_COUNT      := 3
const WAVE_INTERVAL   := 10.0   # seconds between waves
const ENEMIES_PER_WAVE := 3

# Spawn X positions staggered off the right edge
const ENEMY_SPAWN_X   := 1400.0
const ENEMY_SPAWN_YS  := [200.0, 360.0, 520.0]

# Player spawn positions (left side, spread vertically)
const PLAYER_SPAWNS   := [Vector2(150, 200), Vector2(150, 360), Vector2(150, 520)]

var _wave_timer: float = WAVE_INTERVAL
var _current_wave: int = 0
var _players: Array = []


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Add HUD
	add_child(HUD_SCENE.instantiate())

	# Spawn players for however many are connected (min 1 for solo testing)
	var connected: int = maxi(NetworkManager.player_ids.size(), 1)
	for i in range(connected):
		_spawn_player(i + 1)

	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.player_died.connect(_on_player_died)

	# Kick off wave 1 immediately
	_start_wave()


# ── Per-frame ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_tick_wave_timer(delta)
	_update_camera()


# ── Wave management ───────────────────────────────────────────────────────────

func _tick_wave_timer(delta: float) -> void:
	if _current_wave >= WAVE_COUNT:
		return
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = WAVE_INTERVAL
		_start_wave()


func _start_wave() -> void:
	_current_wave += 1
	if _current_wave > WAVE_COUNT:
		_level_complete()
		return

	SignalBus.wave_started.emit(_current_wave)

	for i in range(ENEMIES_PER_WAVE):
		var enemy: Node = ENEMY_SCENE.instantiate()
		enemy.global_position = Vector2(
			ENEMY_SPAWN_X + i * 80.0,
			ENEMY_SPAWN_YS[i % ENEMY_SPAWN_YS.size()]
		)
		add_child(enemy)


func _on_wave_started(wave_number: int) -> void:
	print("Level1: wave %d started" % wave_number)


func _level_complete() -> void:
	SignalBus.level_complete.emit()
	print("Level1: all waves complete — level done!")


# ── Player spawning ───────────────────────────────────────────────────────────

func _spawn_player(pid: int) -> void:
	var player: Node = PLAYER_SCENE.instantiate()
	player.player_id = pid
	player.global_position = PLAYER_SPAWNS[pid - 1]
	player.name = "Player%d" % pid
	add_child(player)
	_players.append(player)


func _on_player_died(player_id: int) -> void:
	# Check if all players are dead → game over
	var all_dead := _players.all(func(p): return p.is_dead)
	if all_dead:
		SignalBus.game_over.emit()
		print("Level1: all players dead — game over")


# ── Dynamic camera ────────────────────────────────────────────────────────────

func _update_camera() -> void:
	var cam: Camera2D = $Camera2D
	var live := _players.filter(func(p): return not p.is_dead)
	if live.is_empty():
		return

	# Centre on the average position of all living players
	var avg := Vector2.ZERO
	for p in live:
		avg += p.global_position
	avg /= live.size()
	cam.global_position = avg

	# Zoom out the further apart players are
	var spread := 0.0
	for p in live:
		spread = max(spread, avg.distance_to(p.global_position))

	var target_zoom: float = clamp(300.0 / max(spread, 300.0), 0.4, 1.0)
	cam.zoom = cam.zoom.lerp(Vector2(target_zoom, target_zoom), 0.05)
