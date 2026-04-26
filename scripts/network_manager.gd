# scripts/network_manager.gd
# Handles host/join multiplayer via ENet and player ID assignment
extends Node

const PORT := 7777
const MAX_PLAYERS := 3

# Maps peer_id -> player_id (1=red, 2=blue, 3=green)
var player_ids: Dictionary = {}

# Local player's assigned slot (1-3)
var local_player_id: int = 0

# Maps peer_id -> character_id (1=Crimson Ace, 2=Azure Guardian, 3=Gilded Striker)
var character_choices: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)


# ── Host ──────────────────────────────────────────────────────────────────────

func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: failed to create server (error %d)" % err)
		return

	multiplayer.multiplayer_peer = peer

	# Host is always player 1 (red)
	local_player_id = 1
	player_ids[multiplayer.get_unique_id()] = local_player_id

	print("NetworkManager: hosting on port %d (player_id=%d)" % [PORT, local_player_id])
	SignalBus.player_connected.emit(local_player_id)


# ── Join ──────────────────────────────────────────────────────────────────────

func join_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		push_error("NetworkManager: failed to connect to %s (error %d)" % [ip, err])
		return

	multiplayer.multiplayer_peer = peer
	print("NetworkManager: connecting to %s:%d …" % [ip, PORT])


# ── Peer callbacks ────────────────────────────────────────────────────────────

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	# Assign next available slot (2 or 3)
	var next_slot := _next_free_slot()
	if next_slot == -1:
		push_warning("NetworkManager: server full, rejecting peer %d" % peer_id)
		return

	player_ids[peer_id] = next_slot
	_sync_player_ids.rpc()

	print("NetworkManager: peer %d assigned player_id=%d" % [peer_id, next_slot])
	SignalBus.player_connected.emit(next_slot)


func _on_peer_disconnected(peer_id: int) -> void:
	var pid: int = player_ids.get(peer_id, -1)
	if pid != -1:
		player_ids.erase(peer_id)
		print("NetworkManager: peer %d (player_id=%d) disconnected" % [peer_id, pid])
		SignalBus.player_disconnected.emit(pid)


func _on_connected_to_server() -> void:
	# Client receives its player_id via _sync_player_ids RPC from host
	print("NetworkManager: connected to server as peer %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	push_error("NetworkManager: connection failed")
	multiplayer.multiplayer_peer = null


# ── RPC – keep all clients in sync ───────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _sync_player_ids() -> void:
	# Host sends its full player_ids dict to all clients
	_receive_player_ids.rpc(player_ids)


@rpc("authority", "call_remote", "reliable")
func _receive_player_ids(ids: Dictionary) -> void:
	player_ids = ids
	var my_peer := multiplayer.get_unique_id()
	if player_ids.has(my_peer):
		local_player_id = player_ids[my_peer]
		print("NetworkManager: I am player_id=%d" % local_player_id)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _next_free_slot() -> int:
	var used := player_ids.values()
	for slot in range(1, MAX_PLAYERS + 1):
		if slot not in used:
			return slot
	return -1


# ── Character selection ───────────────────────────────────────────────────────

## Called by CharacterSelect when the local player picks a character.
## Works for solo (no peer), host, and clients.
func submit_character_choice(character_id: int) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		# Solo or host: store directly and broadcast
		var peer := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		character_choices[peer] = character_id
		if multiplayer.has_multiplayer_peer():
			_broadcast_choices.rpc(character_choices)
		SignalBus.character_choices_updated.emit()
	else:
		# Client: tell server, server will broadcast back
		_client_submit_choice.rpc_id(1, character_id)


@rpc("any_peer", "reliable")
func _client_submit_choice(character_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	character_choices[sender] = character_id
	_broadcast_choices.rpc(character_choices)


@rpc("authority", "call_local", "reliable")
func _broadcast_choices(choices: Dictionary) -> void:
	character_choices = choices
	SignalBus.character_choices_updated.emit()


## Returns the character_id the local player chose, falling back to their slot.
func get_my_character_id() -> int:
	var peer := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	return character_choices.get(peer, local_player_id if local_player_id > 0 else 1)


func get_player_color(player_id: int) -> Color:
	match player_id:
		1: return Color.RED
		2: return Color.BLUE
		3: return Color.GREEN
	return Color.WHITE
