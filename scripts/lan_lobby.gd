extends Control
## LAN対戦の部屋（ロビー）。部屋をつくる（親機）／部屋にはいる（子機）→ キャラ・カート・ハンデ → スタート

const PRESET_NAMES := ["パパ", "ママ", "おにいちゃん", "おねえちゃん", "ぼく", "わたし"]

var phase := "entry"
var root: Control
var name_edit: LineEdit
var num_label: Label
var room_input := ""
var hosts_box: VBoxContainer
var status_label: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ float s = step(0.5, fract((UV.x + UV.y) * 16.0)); COLOR = vec4(mix(vec3(0.15,0.65,0.55), vec3(0.1,0.25,0.55), UV.y) + s*0.03, 1.0);}"
	gm.shader = sh
	bg.material = gm
	add_child(bg)
	UI.header(self, "みんなで対戦（LAN）", Color(0.1, 0.6, 0.5))
	status_label = UI.label("", 24, UI.YELLOW, 8)
	status_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(-500, -160)
	status_label.size = Vector2(1000, 40)
	add_child(status_label)
	Net.lobby_changed.connect(_on_lobby)
	Net.hosts_changed.connect(_on_hosts)
	Net.status_changed.connect(func(t): status_label.text = t)
	Game.mode = "lan"
	Sfx.play_bgm("bgm_title")
	if Net.active:
		_show_room()
	else:
		_show_entry()


func _clear() -> void:
	if root:
		root.queue_free()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	move_child(root, 2)


func _bottom_button(text: String, col: Color, left: bool, cb: Callable, w := 240.0) -> Button:
	var b := UI.button(text, col, 30, Vector2(w, 84))
	b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if left else Control.PRESET_BOTTOM_RIGHT)
	b.position = Vector2(30, -110) if left else Vector2(-w - 30, -110)
	b.pressed.connect(cb)
	root.add_child(b)
	return b


# ------------------------------------------------------------------ はじめの画面
func _show_entry() -> void:
	phase = "entry"
	_clear()
	status_label.text = ""
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-520, -250)
	v.size = Vector2(1040, 440)
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 10)
	v.add_child(nr)
	nr.add_child(UI.label("なまえ", 30, Color.WHITE, 8))
	name_edit = LineEdit.new()
	name_edit.text = Game.settings.get("player_name", "プレイヤー")
	name_edit.max_length = 8
	name_edit.custom_minimum_size = Vector2(300, 64)
	name_edit.add_theme_font_size_override("font_size", 30)
	name_edit.text_changed.connect(func(t): Game.settings["player_name"] = t if t != "" else "プレイヤー")
	nr.add_child(name_edit)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	v.add_child(chips)
	for nm in PRESET_NAMES:
		var c := UI.button(nm, Color(0.3, 0.45, 0.75), 22, Vector2(160, 56))
		c.pressed.connect(func():
			name_edit.text = nm
			Game.settings["player_name"] = nm)
		chips.add_child(c)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var hb := UI.button("部屋をつくる\n（親機）", UI.RED, 36, Vector2(460, 170))
	hb.pressed.connect(_do_host)
	row.add_child(hb)
	var jb := UI.button("部屋にはいる\n（子機）", UI.BLUE, 36, Vector2(460, 170))
	jb.pressed.connect(_show_join)
	row.add_child(jb)
	var note := UI.label("みんな同じWi-Fiにつないでね。親機が1台、ほかの人は子機になります（最大4人）", 22, Color.WHITE, 6)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	_bottom_button("もどる", Color(0.4, 0.45, 0.6), true, func():
		Net.leave()
		Game.save_data()
		Game.goto_scene("res://scenes/MainMenu.tscn"))


func _do_host() -> void:
	Game.save_data()
	if Net.host():
		_show_room()


# ------------------------------------------------------------------ 子機：部屋をさがす
func _show_join() -> void:
	phase = "join"
	Game.save_data()
	_clear()
	Net.start_search()
	status_label.text = "部屋をさがしています…"
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.1, 0.3, 0.85), 24, 4))
	lp.position = Vector2(30, 110)
	lp.size = Vector2(560, 400)
	root.add_child(lp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	lp.add_child(lv)
	lv.add_child(UI.label("見つかった部屋", 30, UI.YELLOW, 8))
	hosts_box = VBoxContainer.new()
	hosts_box.add_theme_constant_override("separation", 8)
	lv.add_child(hosts_box)
	_on_hosts()
	# 部屋番号
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.1, 0.3, 0.85), 24, 4))
	rp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rp.position = Vector2(-640, 110)
	rp.size = Vector2(610, 400)
	root.add_child(rp)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	rp.add_child(rv)
	rv.add_child(UI.label("部屋番号ではいる", 30, UI.YELLOW, 8))
	num_label = UI.label("___", 52, Color.WHITE, 10)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(num_label)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	rv.add_child(grid)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "けす", "はいる"]:
		var b := UI.button(k, UI.GREEN if k == "はいる" else Color(0.3, 0.45, 0.75), 26, Vector2(88, 70))
		b.pressed.connect(_num_key.bind(k))
		grid.add_child(b)
	rv.add_child(UI.label("親機の画面に出ている番号を入れてね", 20, Color.WHITE, 6))
	_bottom_button("もどる", Color(0.4, 0.45, 0.6), true, func():
		Net.leave()
		_show_entry())


func _num_key(k: String) -> void:
	if k == "けす":
		room_input = room_input.left(room_input.length() - 1)
	elif k == "はいる":
		if room_input != "":
			Net.join_room_number(room_input)
	elif room_input.length() < 3:
		room_input += k
	num_label.text = room_input if room_input != "" else "___"


func _on_hosts() -> void:
	if phase != "join" or not hosts_box:
		return
	for c in hosts_box.get_children():
		c.queue_free()
	if Net.found_hosts.is_empty():
		hosts_box.add_child(UI.label("（まだ見つかりません）", 24, Color(1, 1, 1, 0.7), 6))
	for ip in Net.found_hosts:
		var h: Dictionary = Net.found_hosts[ip]
		var b := UI.button("%sの部屋  番号%s（%d人）" % [h.name, h.room, h.count], UI.BLUE, 26, Vector2(520, 72))
		b.pressed.connect(func(): Net.join(ip))
		hosts_box.add_child(b)


# ------------------------------------------------------------------ 部屋の中
func _on_lobby() -> void:
	if phase == "join" and Net.active and not Net.players.is_empty():
		Net.stop_search()
		_show_room()
	elif phase == "room":
		_show_room()


func _show_room() -> void:
	phase = "room"
	_clear()
	status_label.text = ""
	# 左：部屋番号と参加者
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.1, 0.3, 0.85), 24, 4))
	lp.position = Vector2(24, 104)
	lp.size = Vector2(600, 420)
	lp.clip_contents = true
	root.add_child(lp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	lp.add_child(lv)
	if Net.is_host:
		var rn := UI.label("部屋番号  %s" % Net.room_number(), 44, UI.YELLOW, 10)
		lv.add_child(rn)
		if Net.lan_ip() == "":
			lv.add_child(UI.label("Wi-Fiにつながっていないようです", 20, Color(1, 0.6, 0.5), 6))
		else:
			lv.add_child(UI.label("子機はこの番号を入れてね（%s）" % Net.lan_ip(), 18, Color.WHITE, 6))
	else:
		var host_name: String = Net.players.get(1, {}).get("name", "親機")
		lv.add_child(UI.label("%sの部屋" % host_name, 40, UI.YELLOW, 10))
	var ids := Net.players.keys()
	ids.sort()
	for slot in Net.MAX_PLAYERS:
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(0, 62)
		h.add_theme_constant_override("separation", 10)
		lv.add_child(h)
		if slot >= ids.size():
			h.add_child(UI.label("  あき（CPU）" if Net.room.cpu else "  あき", 26, Color(1, 1, 1, 0.45), 6))
			continue
		var id: int = ids[slot]
		var p: Dictionary = Net.players[id]
		var sw := ColorRect.new()
		sw.color = Game.CHARACTERS[p.ci].color
		sw.custom_minimum_size = Vector2(26, 26)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		var me := id == Net.my_id
		var nm := UI.label(str(p.name), 28, UI.YELLOW if me else Color.WHITE, 8)
		nm.custom_minimum_size = Vector2(160, 0)
		h.add_child(nm)
		var det := "%s%s\n%s" % ["親機・" if id == 1 else "", Game.CHARACTERS[p.ci].name, Game.KARTS[p.ki].name]
		var dl := UI.label(det, 16, Color(0.85, 0.95, 1), 5)
		dl.custom_minimum_size = Vector2(170, 0)
		dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dl)
		if p.assist:
			h.add_child(_badge("補助", Color(0.3, 0.75, 0.4)))
		if p.fast:
			h.add_child(_badge("速", Color(0.95, 0.5, 0.15)))

	# 右上：自分の設定
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.1, 0.3, 0.85), 24, 4))
	mp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mp.position = Vector2(-620, 104)
	mp.size = Vector2(590, 250)
	root.add_child(mp)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 6)
	mp.add_child(mv)
	mv.add_child(UI.label("じぶんの設定", 26, UI.YELLOW, 8))
	mv.add_child(_selector("キャラ", Game.CHARACTERS[Game.character_index].name, func(dirn):
		Game.character_index = posmod(Game.character_index + dirn, Game.CHARACTERS.size())
		_changed_me()))
	mv.add_child(_selector("カート", Game.KARTS[Game.kart_index].name, func(dirn):
		var k := Game.kart_index
		for t in Game.KARTS.size():
			k = posmod(k + dirn, Game.KARTS.size())
			if Game.is_kart_unlocked(k):
				break
		Game.kart_index = k
		_changed_me()))
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 10)
	mv.add_child(hr)
	hr.add_child(UI.label("ハンデ", 24, Color.WHITE, 6))
	hr.add_child(_toggle("ハンドル補助", Game.handicap.assist, func(on):
		Game.handicap.assist = on
		_changed_me()))
	hr.add_child(_toggle("はやいカート", Game.handicap.fast, func(on):
		Game.handicap.fast = on
		_changed_me()))

	# 右下：コース（親機だけ変えられる）
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.1, 0.3, 0.85), 24, 4))
	cp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cp.position = Vector2(-620, 364)
	cp.size = Vector2(590, 200)
	root.add_child(cp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	cp.add_child(cv)
	var course: Dictionary = Game.COURSES[Net.room.course]
	var dname: String = Game.DIFFICULTIES[Net.room.difficulty].name
	if Net.is_host:
		cv.add_child(_selector("コース", course.name, func(dirn):
			Net.set_room("course", posmod(int(Net.room.course) + dirn, Game.COURSES.size()))))
		cv.add_child(_selector("CPUの強さ", dname, func(dirn):
			Net.set_room("difficulty", posmod(int(Net.room.difficulty) + dirn, Game.DIFFICULTIES.size()))))
		var cr := HBoxContainer.new()
		cv.add_child(cr)
		cr.add_child(_toggle("あいている所はCPUが走る", Net.room.cpu, func(on): Net.set_room("cpu", on)))
	else:
		cv.add_child(UI.label("コース  " + course.name, 28, Color.WHITE, 8))
		cv.add_child(UI.label("CPUの強さ  " + dname + ("" if Net.room.cpu else "（CPUなし）"), 26, Color.WHITE, 8))
		cv.add_child(UI.label("コースは親機がえらびます", 20, Color(1, 1, 1, 0.7), 6))

	_bottom_button("ぬける", Color(0.4, 0.45, 0.6), true, func():
		Net.leave()
		_show_entry())
	if Net.is_host:
		var go := _bottom_button("スタート！", UI.RED, false, func(): Net.start_race(), 300.0)
		go.add_theme_font_size_override("font_size", 40)
	else:
		var w := UI.label("親機がスタートするのを待っています…", 26, Color.WHITE, 8)
		w.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		w.position = Vector2(-520, -90)
		root.add_child(w)


func _changed_me() -> void:
	Game.save_data()
	Net.update_me()
	_show_room()


func _badge(t: String, c: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(c, 14, 2, Color.WHITE, 0))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UI.label(t, 18, Color.WHITE, 4, c.darkened(0.5))
	p.add_child(l)
	return p


func _selector(title: String, value: String, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var t := UI.label(title, 24, Color.WHITE, 6)
	t.custom_minimum_size = Vector2(130, 0)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(t)
	var l := UI.button("◀", Color(0.3, 0.45, 0.75), 26, Vector2(64, 58))
	l.pressed.connect(func(): cb.call(-1))
	h.add_child(l)
	var v := UI.label(value, 26, UI.YELLOW, 8)
	v.custom_minimum_size = Vector2(250, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	var r := UI.button("▶", Color(0.3, 0.45, 0.75), 26, Vector2(64, 58))
	r.pressed.connect(func(): cb.call(1))
	h.add_child(r)
	return h


func _toggle(text: String, on: bool, cb: Callable) -> Button:
	var b := UI.button(("● " if on else "○ ") + text, UI.GREEN if on else Color(0.35, 0.37, 0.45), 22, Vector2(0, 56))
	b.pressed.connect(func(): cb.call(not on))
	return b
