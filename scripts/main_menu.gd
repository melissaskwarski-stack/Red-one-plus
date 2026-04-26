# scripts/main_menu.gd
# Main menu — host or join, shows live player count, launches Level1 via RPC
extends Control

var _is_hosting: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	SignalBus.player_connected.connect(_on_player_connected)
	_show_main_buttons()


# ── Panel visibility helpers ──────────────────────────────────────────────────

func _show_main_buttons() -> void:
	$CenterBox/MainButtons.visible = true
	$CenterBox/HostPanel.visible   = false
	$CenterBox/JoinPanel.visible   = false


func _show_host_panel() -> void:
	$CenterBox/MainButtons.visible                  = false
	$CenterBox/HostPanel.visible                    = true
	$CenterBox/JoinPanel.visible                    = false
	$CenterBox/HostPanel/StatusLabel.text           = "Waiting for players... (1/3)"
	$CenterBox/HostPanel/StartButton.visible        = true
	$CenterBox/HostPanel/StartButton.text           = "START  (solo)"


func _show_join_panel() -> void:
	$CenterBox/MainButtons.visible                  = false
	$CenterBox/HostPanel.visible                    = false
	$CenterBox/JoinPanel.visible                    = true
	$CenterBox/JoinPanel/JoinStatusLabel.visible    = false
	$CenterBox/JoinPanel/ConnectButton.disabled     = false


# ── Button signals ────────────────────────────────────────────────────────────

func _on_host_button_pressed() -> void:
	_is_hosting = true
	NetworkManager.host_game()
	_show_host_panel()


func _on_join_button_pressed() -> void:
	_show_join_panel()


func _on_connect_button_pressed() -> void:
	var ip: String = $CenterBox/JoinPanel/IPInput.text.strip_edges()
	if ip.is_empty():
		return

	NetworkManager.join_game(ip)
	$CenterBox/JoinPanel/ConnectButton.disabled    = true
	$CenterBox/JoinPanel/JoinStatusLabel.visible   = true
	$CenterBox/JoinPanel/JoinStatusLabel.text      = "Connecting to %s…" % ip

	# Listen for server response directly on the multiplayer object
	multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed,     CONNECT_ONE_SHOT)


func _on_start_button_pressed() -> void:
	_start_game.rpc()


# ── Multiplayer callbacks ─────────────────────────────────────────────────────

func _on_player_connected(player_id: int) -> void:
	if not _is_hosting:
		return

	var count: int = NetworkManager.player_ids.size()
	var status: Label = $CenterBox/HostPanel/StatusLabel
	var start:  Button = $CenterBox/HostPanel/StartButton

	status.text = "Waiting for players… (%d/3)" % count

	if count >= 2:
		start.text = "START GAME  (%d players)" % count
	else:
		start.text = "START  (solo)"


func _on_connected_to_server() -> void:
	$CenterBox/JoinPanel/JoinStatusLabel.text = "Connected!  Waiting for host to start…"


func _on_connection_failed() -> void:
	$CenterBox/JoinPanel/JoinStatusLabel.text = "Connection failed — check the IP and try again."
	$CenterBox/JoinPanel/ConnectButton.disabled = false


# ── Scene transition — called via RPC so all devices switch simultaneously ────

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	# Go to character selection before loading Level1
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")
