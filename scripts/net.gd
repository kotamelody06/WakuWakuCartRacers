extends Node
## LAN対戦の通信（自動読み込みノード）。
## 親機（ホスト）がレースを計算し、子機は操作を送って結果の状態を表示する。
## 同じWi-Fiの中だけで動き、インターネットのサーバーは使わない。

signal lobby_changed
signal hosts_changed
signal status_changed(text: String)

const PORT := 47777
const DISC_PORT := 47778
const MAX_PLAYERS := 4
const MAGIC := "WKART1"

var active := false
var is_host := false
var my_id := 1
var players := {}        # peer_id -> {name, ci, ki, assist, fast}
var room := {"course": 0, "difficulty": 1, "cpu": true}
var roster: Array = []   # レース開始時に決まる人の並び [{peer, name, ci, ki, assist, fast}]
var found_hosts := {}    # ip -> {name, room, t}
var status := ""
var loaded := {}         # レース画面の準備ができた子機
var leave_reason := ""   # タイトルに戻ったときに表示する文

var _peer: ENetMultiplayerPeer
var _udp_send: PacketPeerUDP
var _udp_recv: PacketPeerUDP
var _beacon_t := 0.0
var _search := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)


func _set_status(t: String) -> void:
	status = t
	status_changed.emit(t)


# ------------------------------------------------------------------ 自分の情報
func my_info() -> Dictionary:
	return {"name": Game.settings.get("player_name", "プレイヤー"), "ci": Game.character_index, "ki": Game.kart_index,
		"assist": Game.handicap.assist, "fast": Game.handicap.fast}


## このスマホのWi-Fi内のアドレス（192.168.x.x など）
static func lan_ip() -> String:
	var best := ""
	for a in IP.get_local_addresses():
		if a.contains(":"):
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and int(a.split(".")[1]) >= 16 and int(a.split(".")[1]) <= 31):
			if best == "" or a.begins_with("192.168."):
				best = a
	return best


## 部屋番号 = アドレスの最後の数字
static func room_number() -> String:
	var ip := lan_ip()
	return ip.get_slice(".", 3) if ip != "" else "?"


# ------------------------------------------------------------------ 部屋をつくる / はいる
func host() -> bool:
	leave()
	_peer = ENetMultiplayerPeer.new()
	_peer.set_bind_ip("*")
	var err := _peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		_set_status("部屋をつくれませんでした。少しまってからもう一度おしてね（%d）" % err)
		return false
	multiplayer.multiplayer_peer = _peer
	active = true
	is_host = true
	my_id = 1
	players = {1: my_info()}
	room = {"course": Game.course_index, "difficulty": Game.difficulty, "cpu": true}
	_udp_send = PacketPeerUDP.new()
	_udp_send.set_broadcast_enabled(true)
	_udp_send.set_dest_address("255.255.255.255", DISC_PORT)
	_set_status("部屋をつくりました")
	lobby_changed.emit()
	return true


func join(ip: String) -> void:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, PORT)
	if err != OK:
		_set_status("つなげませんでした（%d）" % err)
		return
	multiplayer.multiplayer_peer = _peer
	active = true
	is_host = false
	_set_status("%s につないでいます…" % ip)


## 部屋番号から親機のアドレスを作る（自分と同じWi-Fiの前半＋番号）
func join_room_number(num: String) -> void:
	var ip := lan_ip()
	if ip == "":
		_set_status("Wi-Fiにつながっていないようです")
		return
	var parts := ip.split(".")
	join("%s.%s.%s.%s" % [parts[0], parts[1], parts[2], num])


func leave() -> void:
	stop_search()
	if _peer:
		_peer.close()
	multiplayer.multiplayer_peer = null
	_peer = null
	_udp_send = null
	active = false
	is_host = false
	players.clear()
	roster.clear()
	loaded.clear()


func is_client() -> bool:
	return active and not is_host


# ------------------------------------------------------------------ 部屋さがし（同じWi-Fiに知らせる）
func start_search() -> void:
	found_hosts.clear()
	_udp_recv = PacketPeerUDP.new()
	if _udp_recv.bind(DISC_PORT) != OK:
		_udp_recv = null
		return
	_search = true


func stop_search() -> void:
	_search = false
	if _udp_recv:
		_udp_recv.close()
	_udp_recv = null


func _process(delta: float) -> void:
	if is_host and _udp_send and get_tree().current_scene and get_tree().current_scene.name == "LanLobby":
		_beacon_t -= delta
		if _beacon_t <= 0.0:
			_beacon_t = 1.0
			var msg := "%s|%s|%s|%d" % [MAGIC, players[1].name, room_number(), players.size()]
			_udp_send.put_packet(msg.to_utf8_buffer())
	if _search and _udp_recv:
		var changed := false
		while _udp_recv.get_available_packet_count() > 0:
			var pkt := _udp_recv.get_packet().get_string_from_utf8()
			var ip := _udp_recv.get_packet_ip()
			var parts := pkt.split("|")
			if parts.size() >= 4 and parts[0] == MAGIC:
				if not found_hosts.has(ip):
					changed = true
				found_hosts[ip] = {"name": parts[1], "room": parts[2], "count": int(parts[3]), "t": Time.get_ticks_msec()}
		for ip in found_hosts.keys():
			if Time.get_ticks_msec() - found_hosts[ip].t > 4000:
				found_hosts.erase(ip)
				changed = true
		if changed:
			hosts_changed.emit()


# ------------------------------------------------------------------ つながった・切れた
func _on_peer_connected(id: int) -> void:
	if is_host:
		if players.size() >= MAX_PLAYERS or get_tree().current_scene.name != "LanLobby":
			_peer.disconnect_peer(id)


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	players.erase(id)
	loaded.erase(id)
	_broadcast_lobby()
	var scn := get_tree().current_scene
	if scn and scn.has_method("on_peer_left"):
		scn.on_peer_left(id)


func _on_connected() -> void:
	my_id = multiplayer.get_unique_id()
	_set_status("つながりました！")
	_register.rpc_id(1, my_info())


func _on_failed() -> void:
	_set_status("つながりませんでした。部屋番号とWi-Fiをたしかめてね")
	leave()


func _on_server_lost() -> void:
	leave()
	leave_reason = "親機との接続が切れました"
	Game.goto_scene("res://scenes/MainMenu.tscn")


# ------------------------------------------------------------------ 部屋の情報
## 自分の設定（キャラ・カート・ハンデ）が変わったら呼ぶ
func update_me() -> void:
	if not active:
		return
	if is_host:
		players[1] = my_info()
		_broadcast_lobby()
	else:
		_register.rpc_id(1, my_info())


func set_room(key: String, value) -> void:
	if is_host:
		room[key] = value
		_broadcast_lobby()


@rpc("any_peer", "reliable")
func _register(info: Dictionary) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	players[id] = {"name": str(info.get("name", "?")).left(8), "ci": clampi(int(info.get("ci", 0)), 0, Game.CHARACTERS.size() - 1),
		"ki": clampi(int(info.get("ki", 1)), 0, Game.KARTS.size() - 1), "assist": bool(info.get("assist", false)), "fast": bool(info.get("fast", false))}
	_broadcast_lobby()


func _broadcast_lobby() -> void:
	_lobby_state.rpc(players, room)
	lobby_changed.emit()


@rpc("authority", "reliable")
func _lobby_state(p: Dictionary, r: Dictionary) -> void:
	players = p
	room = r
	lobby_changed.emit()


# ------------------------------------------------------------------ レース開始・結果
func start_race() -> void:
	if not is_host:
		return
	var ids := players.keys()
	ids.sort()
	var ro := []
	for id in ids:
		var p: Dictionary = players[id]
		ro.append({"peer": id, "name": p.name, "ci": p.ci, "ki": p.ki, "assist": p.assist, "fast": p.fast})
	loaded.clear()
	_start_race.rpc(ro, room.course, room.difficulty, room.cpu)
	_start_race(ro, room.course, room.difficulty, room.cpu)


@rpc("authority", "reliable")
func _start_race(ro: Array, course: int, diff: int, cpu: bool) -> void:
	roster = ro
	room.course = course
	room.difficulty = diff
	room.cpu = cpu
	Game.mode = "lan"
	Game.course_index = course
	Game.difficulty = diff
	Game.goto_scene("res://scenes/Race.tscn")


## 子機：レース画面の準備ができた
@rpc("any_peer", "reliable")
func _loaded() -> void:
	if is_host:
		loaded[multiplayer.get_remote_sender_id()] = true


func send_loaded() -> void:
	if is_client():
		_loaded.rpc_id(1)


func all_loaded() -> bool:
	for r in roster:
		if r.peer != 1 and players.has(r.peer) and not loaded.has(r.peer):
			return false
	return true


## 子機 → 親機：操作
func send_input(steer: float, accel: bool, brake: bool, drift: bool, item: bool) -> void:
	var bits := (1 if accel else 0) | (2 if brake else 0) | (4 if drift else 0) | (8 if item else 0)
	_net_input.rpc_id(1, steer, bits)


@rpc("any_peer", "unreliable_ordered")
func _net_input(steer: float, bits: int) -> void:
	var scn := get_tree().current_scene
	if is_host and scn and scn.has_method("remote_input"):
		scn.remote_input(multiplayer.get_remote_sender_id(), clampf(steer, -1.0, 1.0), bits)


## 親機 → 子機：レースの状態
func send_snapshot(data: Array) -> void:
	_snapshot.rpc(data)


@rpc("authority", "unreliable_ordered")
func _snapshot(data: Array) -> void:
	var scn := get_tree().current_scene
	if scn and scn.has_method("apply_snapshot"):
		scn.apply_snapshot(data)


func send_results(res: Array) -> void:
	_results.rpc(res)
	_results(res)


@rpc("authority", "reliable")
func _results(res: Array) -> void:
	for r in res:
		r["player"] = int(r.get("peer", 0)) == my_id
	Game.last_result = res
	Game.goto_scene("res://scenes/Result.tscn")


## 親機：みんなを部屋（ロビー）にもどす
func back_to_lobby() -> void:
	if is_host:
		_to_lobby.rpc()
		_to_lobby()


@rpc("authority", "reliable")
func _to_lobby() -> void:
	Game.goto_scene("res://scenes/LanLobby.tscn")
