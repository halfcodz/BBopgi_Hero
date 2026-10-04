class_name RevealOverlay
extends Control
## 뽑기 결과 연출 (기획서 5.5).
## 1회: 캡슐 흔들림 → 등급색이 한 단계씩 "승급" → 캡슐 열림 → 드래곤 등장
## 10회: 카드 10장이 차례로 뒤집히고, 최고 등급은 마지막에 한 박자 늦게 공개

signal finished

const STEP_TIME := 0.55
const SHAKE_TIME := 0.8
const FLIP_INTERVAL := 0.16
const TIER_COLORS := [Color("#ffffff"), Color("#4fa3ff"), Color("#b36bff"), Color("#ffc23d"), Color("#ff5fa8")]

var results: Array = []
var multi := false
var t := 0.0
var phase := "shake"         # 단일: shake → escalate → open → done / 다중: flip → done
var tier := 0
var step_t := 0.0
var flipped := 0
var flip_t := 0.0
var particles: Array = []
var flash := 0.0
var shake := 0.0
var rng := RandomNumberGenerator.new()


func setup(res: Array) -> void:
	results = res.duplicate()
	multi = results.size() > 1
	if multi:
		# 최고 등급 카드를 맨 뒤로
		var best := 0
		for i in results.size():
			if results[i].rarity > results[best].rarity:
				best = i
		var b = results[best]
		results.remove_at(best)
		results.append(b)
		phase = "flip"
	else:
		phase = "shake"


func _ready() -> void:
	rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _max_rarity() -> int:
	var m := 0
	for r in results:
		m = maxi(m, r.rarity)
	return m


func _process(delta: float) -> void:
	t += delta
	step_t += delta
	flash = maxf(0.0, flash - delta * 2.5)
	shake = maxf(0.0, shake - delta * 25.0)
	match phase:
		"shake":
			if step_t >= SHAKE_TIME:
				step_t = 0.0
				phase = "escalate" if results[0].rarity > 0 else "open"
				if phase == "open":
					_open()
		"escalate":
			if step_t >= STEP_TIME:
				step_t = 0.0
				tier += 1
				_burst(_center(), TIER_COLORS[tier], 16 + tier * 8, 160 + tier * 60)
				flash = 0.25 + tier * 0.12
				shake = 4.0 + tier * 3.0
				if tier >= results[0].rarity:
					phase = "hold"
		"hold":
			if step_t >= STEP_TIME * (1.6 if tier >= 3 else 1.0):
				_open()
		"flip":
			flip_t += delta
			var interval := FLIP_INTERVAL
			if flipped == results.size() - 1:
				interval = 0.75 if _max_rarity() >= 2 else FLIP_INTERVAL
			if flipped < results.size() and flip_t >= interval:
				flip_t = 0.0
				_flip_next()
	for p in particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.94
	particles = particles.filter(func(p): return p.life > 0.0)
	queue_redraw()


func _open() -> void:
	phase = "open"
	step_t = 0.0
	var r: int = results[0].rarity
	flash = 0.6 + r * 0.1
	shake = 6.0 + r * 4.0
	_burst(_center(), Balance.RARITY_COLORS[r], 30 + r * 20, 300 + r * 80)


func _flip_next() -> void:
	var r: Dictionary = results[flipped]
	var rect := _card_rect(flipped)
	_burst(rect.get_center(), Balance.RARITY_COLORS[r.rarity], 6 + r.rarity * 6, 120 + r.rarity * 50)
	if r.rarity >= 3:
		flash = 0.5
		shake = 8.0
	flipped += 1
	if flipped >= results.size():
		phase = "done_multi"


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	accept_event()
	match phase:
		"shake", "escalate", "hold":
			tier = results[0].rarity
			_open()
		"open":
			if step_t > 0.4:
				_close()
		"flip":
			while flipped < results.size():
				_flip_next()
		"done_multi":
			_close()


func _close() -> void:
	finished.emit()
	queue_free()


func _center() -> Vector2:
	return Vector2(size.x / 2, size.y * 0.42)


func _burst(pos: Vector2, color: Color, n: int, speed: float) -> void:
	for i in n:
		var a := rng.randf() * TAU
		particles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * rng.randf_range(speed * 0.4, speed),
			"life": rng.randf_range(0.5, 1.1), "color": color, "r": rng.randf_range(3, 8)})


func _card_rect(i: int) -> Rect2:
	var cols := 5
	var w := minf((size.x - 60) / cols, 130.0)
	var h := w * 1.45
	var total_w := w * cols + 10 * (cols - 1)
	var x0 := (size.x - total_w) / 2
	var y0 := size.y * 0.2
	return Rect2(x0 + (i % cols) * (w + 10), y0 + (i / cols) * (h + 16), w, h)


# ── 그리기 ──────────────────────────────────────────
func _draw() -> void:
	var font := get_theme_default_font()
	var off := Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake)) if shake > 0.5 else Vector2.ZERO
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.04, 0.12, 0.88))
	draw_set_transform(off)
	if multi:
		_draw_multi(font)
	else:
		_draw_single(font)
	for p in particles:
		var c: Color = p.color
		c.a = clampf(p.life * 1.5, 0.0, 1.0)
		DragonArt.draw_star_shape(self, p.pos, p.r, c, 4, 0.4, t * 3.0)
	draw_set_transform(Vector2.ZERO)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, minf(flash, 0.85)))


func _tier_color() -> Color:
	if tier >= 4:
		return Color.from_hsv(fmod(t * 0.8, 1.0), 0.55, 1.0)
	return TIER_COLORS[tier]


func _draw_single(font: Font) -> void:
	var c := _center()
	var r: Dictionary = results[0]
	if phase in ["shake", "escalate", "hold"]:
		var col := _tier_color()
		var wob := sin(t * 40.0) * (0.12 + 0.04 * tier)
		var glow := 1.0 + 0.1 * sin(t * 8.0)
		for k in 4:
			draw_circle(c, (110 + k * 40) * glow, Color(col.r, col.g, col.b, 0.12 - k * 0.025))
		_draw_capsule(c, 90.0, col, wob)
		var hint := "두근두근…"
		if tier >= 3:
			hint = "!!!"
		elif tier >= 2:
			hint = "오…?!"
		_text(font, Vector2(0, c.y + 190), hint, 34, Color.WHITE)
		return
	# 열림
	var k := clampf(step_t / 0.35, 0.0, 1.0)
	var rcol: Color = Balance.RARITY_COLORS[r.rarity]
	if r.rarity >= 4:
		rcol = Color.from_hsv(fmod(t * 0.8, 1.0), 0.6, 1.0)
	if r.rarity >= 2:
		for i in 12:
			var a := t * 0.6 + TAU * i / 12.0
			var pts := PackedVector2Array([c, c + Vector2(cos(a - 0.08), sin(a - 0.08)) * 520, c + Vector2(cos(a + 0.08), sin(a + 0.08)) * 520])
			draw_colored_polygon(pts, Color(rcol.r, rcol.g, rcol.b, 0.18))
	draw_circle(c, 150, Color(rcol.r, rcol.g, rcol.b, 0.25))
	# 캡슐 반쪽이 날아감
	if k < 1.0:
		var top_c := c + Vector2(-k * 160, -k * 200)
		var bot_c := c + Vector2(k * 160, k * 120)
		draw_circle(top_c, 90 * (1.0 - k * 0.5), Color(rcol.r, rcol.g, rcol.b, 1.0 - k))
		draw_circle(bot_c, 90 * (1.0 - k * 0.5), Color(1, 1, 1, 1.0 - k))
	var d := DragonDB.get_dragon(r.id)
	var scale_k := minf(1.0, step_t / 0.3)
	scale_k = 1.0 + 0.25 * sin(scale_k * PI) if step_t < 0.3 else 1.0
	DragonArt.draw_dragon(self, c, 95.0 * scale_k, d.element, d.rarity, Game.dragon_star(r.id), t)
	var y := c.y + 170
	_text(font, Vector2(0, y), "%s · %s" % [Balance.RARITY_CODES[r.rarity], Balance.RARITY_NAMES[r.rarity]], 30, rcol)
	_text(font, Vector2(0, y + 52), d.name, 48, Color.WHITE)
	var sub := "NEW!" if r.new else "중복 → ★조각 +1"
	if r.get("perfect", false):
		sub += "   PERFECT 보너스 ★조각 +1"
	_text(font, Vector2(0, y + 100), sub, 28, Color("#ffe066") if r.new else Color("#c9c3ff"))
	_text(font, Vector2(0, y + 150), DragonDB.ELEMENT_NAMES[d.element] + " 속성 · " + DragonDB.skill_text(d.get("skill", {})), 22, Color(1, 1, 1, 0.75))
	if step_t > 0.4:
		_text(font, Vector2(0, size.y - 60), "화면을 눌러 계속", 24, Color(1, 1, 1, 0.5 + 0.3 * sin(t * 4)))


func _draw_multi(font: Font) -> void:
	_text(font, Vector2(0, size.y * 0.12), "10회 뽑기 결과", 38, Color.WHITE)
	for i in results.size():
		var rect := _card_rect(i)
		var r: Dictionary = results[i]
		if i >= flipped:
			var pulse := 0.0
			if i == results.size() - 1 and i == flipped and _max_rarity() >= 2:
				pulse = 0.5 + 0.5 * sin(t * 18.0)
			var back := Color("#5a4b7a").lerp(Color("#ffe066"), pulse * 0.5)
			draw_style_box(UIKit.box(back, 14), rect)
			_draw_capsule(rect.get_center(), rect.size.x * 0.28, Color(1, 1, 1, 0.9), sin(t * 10 + i) * 0.1)
			continue
		var col: Color = Balance.RARITY_COLORS[r.rarity]
		if r.rarity >= 4:
			col = Color.from_hsv(fmod(t * 0.8 + i * 0.1, 1.0), 0.6, 1.0)
		draw_style_box(UIKit.box(col, 14), rect)
		draw_style_box(UIKit.box(Color("#fff7ee"), 10), rect.grow(-5))
		if r.rarity >= 3:
			draw_circle(rect.get_center() + Vector2(0, -rect.size.y * 0.1), rect.size.x * 0.42, Color(col.r, col.g, col.b, 0.3))
		var d := DragonDB.get_dragon(r.id)
		DragonArt.draw_dragon(self, rect.get_center() + Vector2(0, -rect.size.y * 0.1), rect.size.x * 0.24,
			d.element, d.rarity, Game.dragon_star(r.id), t + i)
		var fs := 18 if d.name.length() < 4 else 16
		draw_string(font, Vector2(rect.position.x, rect.end.y - 34), d.name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, UIKit.TEXT)
		draw_string(font, Vector2(rect.position.x, rect.end.y - 12), Balance.RARITY_CODES[r.rarity], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, col.darkened(0.2))
		if r.new:
			var badge := Rect2(rect.position + Vector2(-6, -8), Vector2(48, 24))
			draw_style_box(UIKit.box(Color("#ff4d6d"), 10), badge)
			draw_string(font, badge.position + Vector2(0, 18), "NEW", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 15, Color.WHITE)
	if phase == "done_multi":
		var counts := [0, 0, 0, 0, 0]
		var news := 0
		for r in results:
			counts[r.rarity] += 1
			if r.new:
				news += 1
		var summary := []
		for i in range(4, -1, -1):
			if counts[i] > 0:
				summary.append("%s %d" % [Balance.RARITY_CODES[i], counts[i]])
		_text(font, Vector2(0, _card_rect(9).end.y + 60), "  ".join(PackedStringArray(summary)) + ("   ·   새 드래곤 %d" % news if news > 0 else ""), 26, Color("#ffe066"))
		_text(font, Vector2(0, size.y - 60), "화면을 눌러 계속", 24, Color(1, 1, 1, 0.5 + 0.3 * sin(t * 4)))
	else:
		_text(font, Vector2(0, size.y - 60), "화면을 누르면 모두 공개", 22, Color(1, 1, 1, 0.5))


func _draw_capsule(c: Vector2, r: float, top_color: Color, rot: float) -> void:
	draw_set_transform(c, rot)
	draw_circle(Vector2.ZERO, r * 1.04, Color(0.25, 0.18, 0.3))
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		top.append(Vector2(cos(a), sin(a)) * r)
		bottom.append(Vector2(cos(a), -sin(a)) * r)
	draw_colored_polygon(top, top_color)
	draw_colored_polygon(bottom, Color("#f7f3ff"))
	draw_line(Vector2(-r, 0), Vector2(r, 0), Color(0.25, 0.18, 0.3), maxf(2.0, r * 0.08))
	draw_circle(Vector2(-r * 0.4, -r * 0.45), r * 0.16, Color(1, 1, 1, 0.7))
	draw_set_transform(Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake)) if shake > 0.5 else Vector2.ZERO)


func _text(font: Font, pos: Vector2, text: String, fs: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 6, Color(0.1, 0.05, 0.15, color.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, color)
