# scripts/hud.gd
# HUD — health bars per player + shared score. Driven entirely by SignalBus.
extends CanvasLayer


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	SignalBus.player_health_updated.connect(_on_player_health_updated)
	SignalBus.player_died.connect(_on_player_died)
	SignalBus.score_changed.connect(_on_score_changed)
	SignalBus.skill_cooldown_updated.connect(_on_skill_cooldown_updated)


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


func _on_skill_cooldown_updated(player_id: int, seconds_remaining: float) -> void:
	var label_text: String = "SHIFT: %.1fs" % seconds_remaining if seconds_remaining > 0.0 else _skill_ready_text(player_id)
	match player_id:
		1: $P1Container/P1Skill.text = label_text
		2: $P2Container/P2Skill.text = label_text
		3: $P3Container/P3Skill.text = label_text


func _skill_ready_text(player_id: int) -> String:
	match player_id:
		1: return "SHIFT: Afterburner"
		2: return "SHIFT: Plasma Shield"
		3: return "SHIFT: Multi-Barrage"
	return "SHIFT: Skill"
