# autoloads/signal_bus.gd
# Shared event bus — all branches connect through this
extends Node

# Player events
signal player_hit(player_id: int, damage: float)
signal player_died(player_id: int)
signal player_revived(player_id: int)

# Combat
signal enemy_died(enemy_type: String, position: Vector2)
signal bullet_fired(player_id: int, position: Vector2)

# Collectibles
signal prize_collected(player_id: int, value: int)
signal powerup_activated(player_id: int, powerup_type: String)
signal powerup_expired(player_id: int, powerup_type: String)

# Game flow
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal score_changed(new_score: int)
signal game_over()
signal game_won()
