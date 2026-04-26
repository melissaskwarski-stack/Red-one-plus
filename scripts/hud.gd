# scripts/hud.gd
# HUD — health bars per player + shared score. Driven entirely by SignalBus.
extends CanvasLayer


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	SignalBus.player_health_updated.connect(_on_player_health_updated)
	SignalBus.player_died.connect(_on_player_died)
	SignalBus.score_changed.connect(_on_score_changed)


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_player_health_updated(player_id: int, health_remaining: int) -> void:
	match player_id:
		1: $P1Container/P1Health.value = health_remaining
		2: $P2Container/P2Health.value = health_remaining
		3: $P3Container/P3Health.value = health_remaining


func _on_player_died(player_id: int) -> void:
	match player_id:
		1: $P1Container/P1Dead.visible = true
		2: $P2Container/P2Dead.visible = true
		3: $P3Container/P3Dead.visible = true


func _on_score_changed(new_score: int) -> void:
	$ScoreLabel.text = "SCORE: %d" % new_score
