class_name CpuBrain
extends RefCounted
## CPUレーサーの頭脳：通常走行・カーブ（ドリフト）・アイテム使用・プレイヤー追跡・障害物よけ。

var lane := 0.0          # 好みの走行ライン（-1〜1）
var phase := 0.0
var skill := 1.0
var drift_release := 2.0
var drift_cd := 0.0
var item_wait := 0.0
var t := 0.0
var item_wait_range := [0.8, 3.0]
var mistake_rate := 0.12     # 数秒ごとにミスする確率
var _mistake_t := 0.0
var _mistake_steer := 0.0
var _next_check := 3.0


func _init() -> void:
	lane = randf_range(-0.45, 0.45)
	phase = randf() * TAU
	skill = randf_range(0.93, 1.0)
	item_wait = randf_range(0.6, 2.5)


## 難易度に合わせて性格を変える
func configure(d: Dictionary) -> void:
	item_wait_range = d.get("item_wait", [0.8, 3.0])
	mistake_rate = d.get("mistake", 0.12)
	item_wait = randf_range(item_wait_range[0], item_wait_range[1])


func think(k: Kart, dt: float) -> void:
	t += dt
	# ときどきハンドル操作をまちがえる
	_next_check -= dt
	if _next_check <= 0.0:
		_next_check = randf_range(2.5, 4.5)
		if randf() < mistake_rate:
			_mistake_t = randf_range(0.5, 1.0)
			_mistake_steer = randf_range(0.5, 0.9) * (1.0 if randf() < 0.5 else -1.0)
	_mistake_t = maxf(0.0, _mistake_t - dt)
	drift_cd = max(0.0, drift_cd - dt)
	var tr := k.track
	var look := 8.0 + absf(k.speed) * 0.42
	var want_lat := (lane + sin(t * 0.35 + phase) * 0.2) * tr.hw
	# 落下ゾーンでは真ん中寄りを走る
	var ahead_i := tr.wrap_i(k.idx + int(look / tr.ds))
	if tr.edge[ahead_i] == Track.Edge.FALL or tr.edge[k.idx] == Track.Edge.FALL:
		want_lat *= 0.3
	# 前方の「すべすべボール」をよける
	for h in k.race.hazards:
		var hd: float = fposmod(h.d - k.d, tr.length)
		if hd > 2.0 and hd < 28.0 and absf(h.lat - want_lat) < 3.2:
			want_lat = h.lat + (4.0 if h.lat < 0.0 else -4.0)
	# コースの障害物をよける
	for ob in k.race.obstacles:
		var obd: float = fposmod(ob.d - k.d, tr.length)
		if obd > 1.0 and obd < 22.0 and absf(ob.lat - want_lat) < 3.4:
			want_lat = ob.lat + (4.2 if ob.lat < 0.0 else -4.2)
	# 近くのカートをよけて追い抜く
	for o in k.race.karts:
		if o == k:
			continue
		var od: float = fposmod(o.d - k.d, tr.length)
		if od > 0.5 and od < 10.0 and absf(o.lat - want_lat) < 2.6:
			want_lat = o.lat + (3.0 if want_lat >= o.lat else -3.0)
	want_lat = clampf(want_lat, -tr.hw * 0.8, tr.hw * 0.8)
	var target := tr.point_at(k.d + look, want_lat)
	var to := target - k.position
	var desired := atan2(-to.x, -to.z)
	var diff := wrapf(desired - k.yaw, -PI, PI)
	var far := tr.point_at(k.d + look * 2.4, want_lat * 0.5)
	var to2 := far - k.position
	var fdiff := wrapf(atan2(-to2.x, -to2.z) - k.yaw, -PI, PI)

	k.in_steer = clampf(-diff * 2.6, -1.0, 1.0)
	if _mistake_t > 0.0:
		k.in_steer = clampf(k.in_steer + _mistake_steer, -1.0, 1.0)
	k.in_accel = true
	k.in_brake = false
	if absf(diff) > 0.85 and k.speed > 16.0:
		k.in_accel = false
	if tr.edge[ahead_i] == Track.Edge.FALL and absf(fdiff) > 0.55 and k.speed > 24.0:
		k.in_accel = false
	if absf(diff) > 1.7:
		k.in_brake = true
		k.in_accel = false

	# ドリフト
	if k.drift_dir == 0:
		if k.in_drift and k.hop_air:
			k.in_steer = -signf(fdiff) if absf(fdiff) > 0.05 else k.in_steer
		elif k.in_drift and not k.hop_air:
			k.in_drift = false
		elif not k.in_drift and drift_cd <= 0.0 and _mistake_t <= 0.0 and tr.edge[ahead_i] != Track.Edge.FALL and k.grounded and k.speed > 18.0 and absf(fdiff) > 0.42 and absf(diff) > 0.12 and not k.on_ice:
			k.in_drift = true
			k.in_steer = -signf(fdiff)
			drift_release = randf_range(1.7, 3.0)
	else:
		if k.drift_time > drift_release or absf(fdiff) < 0.1 or signf(-fdiff) != float(k.drift_dir) and absf(fdiff) > 0.2:
			k.in_drift = false
			drift_cd = randf_range(0.5, 1.2)

	# アイテム
	k.in_item = false
	if k.item != "" and k.roulette <= 0.0:
		item_wait -= dt
		if item_wait <= 0.0 and _should_use(k):
			k.in_item = true
			item_wait = randf_range(item_wait_range[0], item_wait_range[1])


func _should_use(k: Kart) -> bool:
	match k.item:
		"boost", "rocket", "barrier":
			return true
		"spin":
			for o in k.race.karts:
				if o != k and o.rank == k.rank - 1:
					return o.progress - k.progress < 70.0 or item_wait < -5.0
			return item_wait < -3.0
		"slip":
			for o in k.race.karts:
				if o != k:
					var gap: float = k.progress - o.progress
					if gap > 3.0 and gap < 25.0:
						return true
			return item_wait < -8.0
	return true
