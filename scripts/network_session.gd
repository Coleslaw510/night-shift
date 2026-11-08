extends Node
## Lightweight ENet room foundation. The VM will host this on UDP 7777 later.
signal player_joined(peer_id: int, player_name: String)
signal player_left(peer_id: int)
signal pose_received(peer_id: int, position: Vector3, yaw: float)
signal status_changed(text: String)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4
var peer: ENetMultiplayerPeer
var active := false
var mode := "offline"
var roster: Dictionary = {}
var display_name := "Night Worker"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host(port := DEFAULT_PORT) -> bool:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		status_changed.emit("Could not host on UDP %d" % port)
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	mode = "host"
	roster = {1: "Host"}
	status_changed.emit("Hosting on UDP %d" % port)
	return true

func join(address: String, port := DEFAULT_PORT) -> bool:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), port)
	if err != OK:
		status_changed.emit("Could not connect to %s" % address)
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	mode = "client"
	status_changed.emit("Connecting to %s..." % address)
	return true

func register_client() -> void:
	if not active or mode != "client" or not multiplayer.has_multiplayer_peer():
		return
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	rpc_id(1, "server_register", display_name)

@rpc("any_peer", "reliable")
func server_register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	roster[id] = player_name.left(20)
	rpc("client_roster", roster)
	player_joined.emit(id, str(roster[id]))

@rpc("authority", "reliable")
func client_roster(incoming: Dictionary) -> void:
	for id in incoming.keys():
		var peer_id := int(id)
		var fresh := not roster.has(peer_id)
		roster[peer_id] = str(incoming[id])
		if fresh:
			player_joined.emit(peer_id, roster[peer_id])

func submit_pose(pos: Vector3, yaw: float) -> void:
	if not active or not multiplayer.has_multiplayer_peer():
		return
	if not multiplayer.is_server() and (peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED):
		return
	if multiplayer.is_server():
		rpc("client_pose", 1, pos, yaw)
	else:
		rpc_id(1, "server_pose", pos, yaw)

@rpc("any_peer", "unreliable")
func server_pose(pos: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	rpc("client_pose", id, pos, yaw)

@rpc("authority", "unreliable")
func client_pose(peer_id: int, pos: Vector3, yaw: float) -> void:
	pose_received.emit(peer_id, pos, yaw)

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		roster[id] = "Worker %d" % id
		player_joined.emit(id, roster[id])

func _on_peer_disconnected(id: int) -> void:
	roster.erase(id)
	player_left.emit(id)

func _on_connected() -> void:
	status_changed.emit("Connected to night shift")
	register_client()

func _on_connection_failed() -> void:
	status_changed.emit("Connection failed")
	active = false
	mode = "offline"

func _on_server_disconnected() -> void:
	status_changed.emit("Host disconnected")
	active = false
	mode = "offline"

func leave() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
	active = false
	mode = "offline"
	roster.clear()
