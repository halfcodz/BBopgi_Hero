extends Control
## 인형뽑기 기계 (기획서 5.1).
## 1회: 집게를 좌우로 움직여 [내리기] → 집기 → 흔들리며 올라옴 → 배출구 → 결과 연출
## 10회: 집게가 캡슐 10개를 한꺼번에 쓸어 담는 연출 → 카드 10장 공개
## 결과는 [내리기] 순간 Gacha 확률표로 결정된다. 집게 위치는 퍼펙트 보너스(조각 +1)에만 쓰인다.

const AIM_TIME := 10.0
const CLAW_SPEED := 0.55          # 유리창 너비 비율 / 초
const CAPSULE_COLORS := [
	Color("#ffb3c7"), Color("#a8e6ff"), Color("#c8f7a6"), Color("#ffe29a"), Color("#d9c2ff"), Color("#ffc8a2"),
]

var state := "idle"     # idle, aim, drop, grab, rise, carry, release, sweep, reveal
var state_t := 0.0
var t := 0.0
var claw_x := 0.6       # 유리창 기준 0~1
var claw_y := 0.0       # 레일에서 내려온 거리(px)
var claw_open := 0.3
var move_dir := 0.0
var drag_active := false
var aim_left := AIM_TIME
var capsules: Array = []          # {x, y (유리창 비율), color, falling}
var held = null                   # 집은 캡슐
var target = null
var pending_results: Array = []
var perfect := false
var pre_hint := false
var wobble_popped := false
var sweep_targets: Array = []
var flying: Array = []            # 배출구로 날아가는 캡슐들
var popups: Array = []
var rng := RandomNumberGenerator.new()

var machine_area: Control
var info_label: Label
var pity_label: Label
var idle_row: HBoxContainer
var aim_row: HBoxContainer
var btn_one: Button
var btn_ten: Button
var btn_mileage: Button


func _ready() -> void:
	rng.randomize()
	_build_ui()
	_fill_capsules()
	Game.currency_changed.connect(_refresh)
	_refresh()


func _build_ui() -> void:
	var v := UIKit.vbox(8)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.margin(v, 16, 12, 16, 12))
	get_child(0).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var info := UIKit.hbox(8)
	v.add_child(info)
	info_label = UIKit.label("", 22, UIKit.TEXT)
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(info_label)
	var rates_btn := UIKit.button("확률 보기", UIKit.SKY, 20, Vector2(120, 44))
	rates_btn.pressed.connect(_show_rates)
	info.add_child(rates_btn)
	pity_label = UIKit.label("", 19, UIKit.TEXT_SOFT)
	v.add_child(pity_label)

	machine_area = Control.new()
	machine_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	machine_area.mouse_filter = Control.MOUSE_FILTER_STOP
	machine_area.gui_input.connect(_on_machine_input)
	machine_area.draw.connect(_draw_machine)
	v.add_child(machine_area)

	idle_row = UIKit.hbox(10)
	v.add_child(idle_row)
	btn_one = UIKit.button("1회 뽑기\n코인 1", UIKit.PINK, 22, Vector2(0, 84))
	btn_one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_one.pressed.connect(start_single)
	idle_row.add_child(btn_one)
	btn_ten = UIKit.button("10회 뽑기\n코인 10", Color("#b36bff"), 22, Vector2(0, 84))
	btn_ten.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ten.pressed.connect(start_multi)
	idle_row.add_child(btn_ten)
	btn_mileage = UIKit.button("", Color("#7a6cf0"), 18, Vector2(130, 84))
	btn_mileage.pressed.connect(_show_mileage)
	idle_row.add_child(btn_mileage)

	aim_row = UIKit.hbox(10)
	aim_row.visible = false
	v.add_child(aim_row)
	var left := UIKit.button("◀", UIKit.SKY, 34, Vector2(130, 84))
	left.button_down.connect(func(): move_dir = -1.0)
	left.button_up.connect(func(): move_dir = 0.0)
	aim_row.add_child(left)
	var drop := UIKit.button("내리기!", UIKit.MINT, 30, Vector2(0, 84))
	drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop.pressed.connect(do_drop)
	aim_row.add_child(drop)
	var right := UIKit.button("▶", UIKit.SKY, 34, Vector2(130, 84))
	right.button_down.connect(func(): move_dir = 1.0)
	right.button_up.connect(func(): move_dir = 0.0)
	aim_row.add_child(right)


func on_shown() -> void:
	_refresh()


func _refresh() -> void:
	if info_label == null:
		return
	var lv := Gacha.machine_level()
	var next := Gacha.pulls_to_next_level()
	info_label.text = "뽑기 기계 Lv.%d" % lv + ("  (다음 Lv까지 %d회)" % next if next > 0 else "  (최고 레벨)")
	var to_sr := Balance.PITY_SR - Game.pity_sr
	var to_ssr := Balance.HARD_PITY_SSR - Game.pity_ssr
	pity_label.text = "영웅 확정까지 %d회 · 전설 확정까지 %d회 · 현재 전설 이상 %.1f%%" % [to_sr, to_ssr, Gacha.ssr_plus_rate()]
	var busy := state != "idle"
	btn_one.disabled = busy or Game.coins < 1
	btn_ten.disabled = busy or Game.coins < 10
	btn_mileage.text = "신화 교환\n%d/%d" % [mini(Game.mileage, Balance.MILEAGE_UR), Balance.MILEAGE_UR]
	btn_mileage.disabled = busy or not Gacha.can_exchange_mileage()
	idle_row.visible = state != "aim"
	aim_row.visible = state == "aim"


# ── 기하 ────────────────────────────────────────────
func _cabinet() -> Rect2:
	var s := machine_area.size
	var w := minf(s.x, 560.0)
	return Rect2((s.x - w) / 2, 0, w, s.y)


func _glass() -> Rect2:
	var c := _cabinet()
	return Rect2(c.position.x + 22, c.position.y + 52, c.size.x - 44, c.size.y - 52 - 20)


func _cap_r() -> float:
	return clampf(_glass().size.x * 0.06, 18.0, 30.0)


func _chute_w() -> float:
	return 0.2


func _to_px(nx: float, ny: float) -> Vector2:
	var g := _glass()
	return g.position + Vector2(nx * g.size.x, ny * g.size.y)


func _rail_y() -> float:
	return _glass().position.y + 16.0


func _claw_head() -> Vector2:
	return Vector2(_to_px(claw_x, 0).x, _rail_y() + 30.0 + claw_y)


func _fill_capsules() -> void:
	capsules.clear()
	# 유리창 크기가 정해지기 전에도 쓸 수 있도록 비율 좌표로 배치
	var rows := [[0.92, 7, 0.0], [0.80, 6, 0.5], [0.68, 5, 1.0]]
	for row in rows:
		for i in row[1]:
			var x: float = 0.28 + (i + row[2] * 0.5) * 0.1 + rng.randf_range(-0.012, 0.012)
			capsules.append({"x": x, "y": row[0] + rng.randf_range(-0.01, 0.01), "color": CAPSULE_COLORS[rng.randi() % CAPSULE_COLORS.size()], "drop": 0.0})


# ── 진행 ────────────────────────────────────────────
func start_single() -> void:
	if state != "idle" or not Game.spend_coins(Gacha.PULL_COST):
		return
	state = "aim"
	state_t = 0.0
	aim_left = AIM_TIME
	claw_open = 0.6
	_refresh()


func start_multi() -> void:
	if state != "idle" or not Game.spend_coins(Gacha.PULL_COST * 10):
		return
	pending_results = Gacha.pull(10)
	state = "sweep"
	state_t = 0.0
	sweep_targets = capsules.duplicate()
	sweep_targets.sort_custom(func(a, b): return a.x < b.x)
	sweep_targets = sweep_targets.slice(0, 10)
	_refresh()


func do_drop() -> void:
	if state != "aim":
		return
	move_dir = 0.0
	target = _pick_target()
	var g := _glass()
	perfect = target != null and absf((claw_x - target.x) * g.size.x) <= Balance.PERFECT_RANGE
	pending_results = Gacha.pull(1, perfect)    # ← 결과는 여기서 결정
	pre_hint = pending_results[0].rarity >= Balance.RARITY_SSR and rng.randf() < 0.6
	if perfect:
		_popup("PERFECT!", _claw_head() + Vector2(0, -20), Color("#ffe066"), 34)
	state = "drop"
	state_t = 0.0
	wobble_popped = false
	_refresh()


func _pick_target():
	var best = null
	var best_score := INF
	for c in capsules:
		if c.drop > 0.0:
			continue
		var dx := absf(c.x - claw_x)
		var score: float = dx * 4.0 + c.y        # 가까우면서 위에 있는 캡슐
		if score < best_score:
			best_score = score
			best = c
	return best


func _process(delta: float) -> void:
	t += delta
	state_t += delta
	var g := _glass()
	match state:
		"idle":
			claw_x = lerpf(claw_x, 0.6 + sin(t * 0.7) * 0.05, delta * 2.0)
			claw_y = lerpf(claw_y, 0.0, delta * 4.0)
		"aim":
			var key := Input.get_axis("ui_left", "ui_right")
			var dir := move_dir if move_dir != 0.0 else key
			claw_x = clampf(claw_x + dir * CLAW_SPEED * delta, _chute_w() + 0.04, 0.96)
			aim_left -= delta
			if Input.is_action_just_pressed("ui_accept") or aim_left <= 0.0:
				do_drop()
		"drop":
			claw_open = minf(1.0, claw_open + delta * 3.0)
			var goal := _drop_depth()
			claw_y = move_toward(claw_y, goal, delta * 520.0)
			if is_equal_approx(claw_y, goal):
				state = "grab"
				state_t = 0.0
		"grab":
			claw_open = maxf(0.0, claw_open - delta * 4.0)
			if state_t >= 0.35:
				held = target
				if held != null:
					capsules.erase(held)
				state = "rise"
				state_t = 0.0
		"rise":
			claw_y = move_toward(claw_y, 0.0, delta * 300.0)
			# 중간에 한 번 크게 휘청 (긴장감 연출, 실패는 없음)
			if state_t > 0.45 and not wobble_popped:
				wobble_popped = true
				_popup("휘청!", _claw_head() + Vector2(50, 20), Color("#ff9aa2"), 26)
			if claw_y <= 0.5 and state_t > 0.8:
				state = "carry"
				state_t = 0.0
		"carry":
			claw_x = move_toward(claw_x, _chute_w() * 0.5, delta * 0.9)
			if absf(claw_x - _chute_w() * 0.5) < 0.005:
				state = "release"
				state_t = 0.0
				if held != null:
					flying.append({"pos": _held_pos(), "vel": Vector2(0, 50), "color": held.color, "life": 0.6})
				held = null
		"release":
			claw_open = minf(1.0, claw_open + delta * 4.0)
			if state_t >= 0.55:
				_start_reveal()
		"sweep":
			# 집게가 바닥까지 내려가 오른쪽→왼쪽으로 쓸어 담는다
			var k := clampf(state_t / 2.0, 0.0, 1.0)
			claw_open = 1.0
			claw_y = lerpf(claw_y, _floor_depth(), delta * 6.0) if k < 0.85 else lerpf(claw_y, 0.0, delta * 8.0)
			claw_x = lerpf(0.95, _chute_w() * 0.5, k)
			for c in sweep_targets:
				if capsules.has(c) and c.x > claw_x - 0.02:
					capsules.erase(c)
					flying.append({"pos": _to_px(c.x, c.y), "vel": Vector2(-rng.randf_range(250, 450), -rng.randf_range(80, 220)), "color": c.color, "life": 0.8})
			if state_t >= 2.3:
				_start_reveal()
		"reveal":
			pass
	_update_effects(delta)
	machine_area.queue_redraw()


func _drop_depth() -> float:
	if target == null:
		return _floor_depth()
	var cap := _to_px(target.x, target.y)
	return maxf(0.0, cap.y - _cap_r() - 44.0 - (_rail_y() + 30.0))


func _floor_depth() -> float:
	var g := _glass()
	return g.end.y - _cap_r() * 2.0 - 44.0 - (_rail_y() + 30.0)


func _held_pos() -> Vector2:
	var swing := sin(state_t * 9.0) * 0.18
	if state == "rise" and state_t > 0.4 and state_t < 0.75:
		swing = sin(state_t * 30.0) * 0.45
	var slip := 10.0 if state == "rise" and state_t > 0.45 and state_t < 0.7 else 0.0
	return _claw_head() + Vector2(0, 44.0 + _cap_r() * 0.7 + slip).rotated(swing)


func _start_reveal() -> void:
	state = "reveal"
	var host := _main_host()
	var overlay := RevealOverlay.new()
	overlay.setup(pending_results)
	overlay.finished.connect(_on_reveal_done)
	host.add_child(overlay)


func _on_reveal_done() -> void:
	state = "idle"
	target = null
	# 빈자리에 새 캡슐이 위에서 떨어진다
	while capsules.size() < 18:
		var x := rng.randf_range(0.3, 0.92)
		capsules.append({"x": x, "y": rng.randf_range(0.66, 0.9), "color": CAPSULE_COLORS[rng.randi() % CAPSULE_COLORS.size()], "drop": 1.0})
	_refresh()


func _main_host() -> Node:
	var n: Node = get_parent()
	while n != null and not n.has_method("show_modal"):
		n = n.get_parent()
	return n if n != null else get_tree().root


func _on_machine_input(event: InputEvent) -> void:
	if state != "aim":
		return
	if event is InputEventMouseButton:
		drag_active = event.pressed
	if (event is InputEventMouseMotion and drag_active) or (event is InputEventMouseButton and event.pressed):
		var g := _glass()
		claw_x = clampf((event.position.x - g.position.x) / g.size.x, _chute_w() + 0.04, 0.96)


func _popup(text: String, pos: Vector2, color: Color, fs: int) -> void:
	popups.append({"text": text, "pos": pos, "color": color, "size": fs, "life": 1.0})


func _update_effects(delta: float) -> void:
	for f in flying:
		f.life -= delta
		f.vel.y += 900.0 * delta
		f.pos += f.vel * delta
	flying = flying.filter(func(f): return f.life > 0.0)
	for p in popups:
		p.life -= delta
		p.pos.y -= 40.0 * delta
	popups = popups.filter(func(p): return p.life > 0.0)
	for c in capsules:
		c.drop = maxf(0.0, c.drop - delta * 2.5)


# ── 그리기 ──────────────────────────────────────────
func _draw_machine() -> void:
	var ci := machine_area
	var font := get_theme_default_font()
	var cab := _cabinet()
	var g := _glass()
	var cr := _cap_r()
	# 본체
	ci.draw_style_box(UIKit.box(Color("#ff8fb1"), 28), cab)
	ci.draw_style_box(UIKit.box(Color("#ffb3c9"), 24), cab.grow(-6))
	# 간판
	var sign_r := Rect2(cab.position.x + 40, cab.position.y + 8, cab.size.x - 80, 38)
	ci.draw_style_box(UIKit.box(Color("#4a3b52"), 14), sign_r)
	for i in 14:
		var lx := sign_r.position.x + 10 + i * (sign_r.size.x - 20) / 13.0
		var on := int(t * 6.0 + i) % 2 == 0
		ci.draw_circle(Vector2(lx, sign_r.position.y + 4), 3, Color("#ffe066") if on else Color("#ff8fb1"))
	ci.draw_string(font, Vector2(sign_r.position.x, sign_r.position.y + 29), "DRAGON CATCHER", HORIZONTAL_ALIGNMENT_CENTER, sign_r.size.x, 22, Color.WHITE)
	# 유리창
	ci.draw_style_box(UIKit.box(Color("#dff3ff"), 16), g)
	var chute_r := Rect2(g.position.x, g.end.y - g.size.y * 0.3, g.size.x * _chute_w(), g.size.y * 0.3)
	ci.draw_rect(chute_r, Color("#c7b6d6"))
	ci.draw_rect(Rect2(chute_r.position, Vector2(chute_r.size.x, 8)), Color("#8f7aa8"))
	ci.draw_rect(Rect2(chute_r.end.x - 6, chute_r.position.y, 6, chute_r.size.y), Color("#8f7aa8"))
	ci.draw_string(font, Vector2(chute_r.position.x, chute_r.position.y + 40), "OUT", HORIZONTAL_ALIGNMENT_CENTER, chute_r.size.x, 18, Color("#6d5a85"))
	# 캡슐 더미 (뒤 → 앞)
	var sorted := capsules.duplicate()
	sorted.sort_custom(func(a, b): return a.y < b.y)
	var aim_target = _pick_target() if state == "aim" else null
	for c in sorted:
		var p := _to_px(c.x, c.y) + Vector2(0, -c.drop * g.size.y * 0.6)
		var hi: bool = aim_target != null and is_same(c, aim_target)
		_draw_capsule(ci, p, cr, c.color, 0.0, hi)
	# 조준 가이드
	if state == "aim":
		var hx := _to_px(claw_x, 0).x
		var y := _claw_head().y + 40
		while y < g.end.y - 8:
			ci.draw_line(Vector2(hx, y), Vector2(hx, y + 10), Color(1, 0.4, 0.6, 0.6), 2.0)
			y += 20
	# 레일 + 집게
	ci.draw_rect(Rect2(g.position.x + 6, _rail_y() - 5, g.size.x - 12, 10), Color("#8f7aa8"))
	var head := _claw_head()
	ci.draw_rect(Rect2(head.x - 22, _rail_y() - 12, 44, 22), Color("#6d5a85"))
	ci.draw_line(Vector2(head.x, _rail_y()), head, Color("#6d5a85"), 3.0)
	if held != null:
		_draw_capsule(ci, _held_pos(), cr, held.color, sin(state_t * 9.0) * 0.2, false)
		if pre_hint and state in ["rise", "carry"]:
			for i in 3:
				var a := t * 4.0 + TAU * i / 3.0
				DragonArt.draw_star_shape(ci, _held_pos() + Vector2(cos(a), sin(a)) * cr * 1.6, 7, Color("#ffd23f"), 4, 0.35)
	_draw_claw(ci, head)
	for f in flying:
		_draw_capsule(ci, f.pos, cr * 0.9, f.color, f.life * 6.0, false)
	# 유리 반사광
	ci.draw_colored_polygon(PackedVector2Array([g.position + Vector2(g.size.x * 0.6, 4), g.position + Vector2(g.size.x * 0.72, 4),
		g.position + Vector2(g.size.x * 0.42, g.size.y - 4), g.position + Vector2(g.size.x * 0.3, g.size.y - 4)]), Color(1, 1, 1, 0.18))
	# 상태 문구
	if state == "aim":
		var txt := "집게를 움직여 캡슐 위에서 [내리기]!  %d" % ceili(aim_left)
		ci.draw_string_outline(font, Vector2(g.position.x, g.position.y + g.size.y * 0.38), txt, HORIZONTAL_ALIGNMENT_CENTER, g.size.x, 20, 5, Color.WHITE)
		ci.draw_string(font, Vector2(g.position.x, g.position.y + g.size.y * 0.38), txt, HORIZONTAL_ALIGNMENT_CENTER, g.size.x, 20, UIKit.TEXT)
	elif state == "idle" and Game.coins < 1:
		ci.draw_string(font, Vector2(g.position.x, g.position.y + 66), "스테이지를 돌면 코인이 모여요", HORIZONTAL_ALIGNMENT_CENTER, g.size.x, 20, UIKit.TEXT_SOFT)
	for p in popups:
		var c: Color = p.color
		c.a = clampf(p.life * 2.0, 0.0, 1.0)
		ci.draw_string_outline(font, p.pos - Vector2(150, 0), p.text, HORIZONTAL_ALIGNMENT_CENTER, 300, p.size, 7, Color(0.25, 0.15, 0.3, c.a))
		ci.draw_string(font, p.pos - Vector2(150, 0), p.text, HORIZONTAL_ALIGNMENT_CENTER, 300, p.size, c)


func _draw_claw(ci: CanvasItem, head: Vector2) -> void:
	var col := Color("#5a4b6e")
	ci.draw_circle(head, 14, col)
	ci.draw_circle(head, 7, Color("#ffd23f"))
	var o := claw_open
	for side in [-1.0, 1.0]:
		var p1 := head + Vector2(side * (10 + 18 * o), 22)
		var p2 := head + Vector2(side * (6 + 14 * o), 44)
		var p3 := head + Vector2(side * (-2 + 6 * o), 52)
		ci.draw_polyline(PackedVector2Array([head + Vector2(side * 6, 4), p1, p2, p3]), col, 6.0)


func _draw_capsule(ci: CanvasItem, c: Vector2, r: float, color: Color, rot: float, highlight: bool) -> void:
	if highlight:
		ci.draw_circle(c, r * 1.25, Color(1, 0.5, 0.7, 0.35 + 0.15 * sin(t * 8.0)))
	var outline := Color(0.32, 0.24, 0.38)
	ci.draw_circle(c, r + 2, outline)
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		top.append(c + (Vector2(cos(a), sin(a)) * r).rotated(rot))
		bottom.append(c + (Vector2(cos(a), -sin(a)) * r).rotated(rot))
	ci.draw_colored_polygon(top, color)
	ci.draw_colored_polygon(bottom, Color("#fbf8ff"))
	ci.draw_line(c + Vector2(-r, 0).rotated(rot), c + Vector2(r, 0).rotated(rot), outline, 2.0)
	ci.draw_circle(c + Vector2(-r * 0.4, -r * 0.45).rotated(rot), r * 0.18, Color(1, 1, 1, 0.75))


# ── 모달 ────────────────────────────────────────────
func _show_rates() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var l := UIKit.label(Gacha.rates_text(), 20, UIKit.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(l)
	_main_host().show_modal("확률 정보", scroll)


func _show_mileage() -> void:
	if not Gacha.can_exchange_mileage():
		return
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label("마일리지 %d를 사용해 신화 드래곤을 고르세요" % Balance.MILEAGE_UR, 22, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UIKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in DragonDB.ids_of_rarity(Balance.RARITY_UR):
		var d := DragonDB.get_dragon(id)
		var col := UIKit.vbox(4)
		col.add_child(Widgets.dragon_view(id, 150))
		col.add_child(UIKit.label(d.name, 24, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(col)
	v.add_child(row)
	var buttons := []
	for id in DragonDB.ids_of_rarity(Balance.RARITY_UR):
		buttons.append([DragonDB.get_dragon(id).name, func(): _exchange(id), Color("#ff5fa8")])
	buttons.append(["취소", Callable(), UIKit.GRAY])
	_main_host().show_modal("신화 교환", v, buttons)


func _exchange(id: String) -> void:
	var was_new := not Game.has_dragon(id)
	if Gacha.exchange_mileage(id):
		pending_results = [{"id": id, "rarity": Balance.RARITY_UR, "new": was_new}]
		_start_reveal()
		_refresh()


## 스크린샷 도구용
func debug_action(act: String) -> void:
	match act:
		"pull1": start_single()
		"pull10": start_multi()
		"left": claw_x -= 0.1
		"drop": do_drop()
