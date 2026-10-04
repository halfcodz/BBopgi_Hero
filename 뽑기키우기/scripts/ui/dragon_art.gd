class_name DragonArt
extends RefCounted
## 외부 에셋 없이 그리는 아기 드래곤·몬스터·재화 아이콘.
## M1에서 스프라이트로 바꿀 때는 이 파일만 교체하면 된다.

const OUTLINE := Color("#3d2f45")


static func ellipse_points(c: Vector2, rx: float, ry: float, n := 24, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func draw_ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color, rot := 0.0) -> void:
	ci.draw_colored_polygon(ellipse_points(c, rx, ry, 28, rot), color)


static func draw_star_shape(ci: CanvasItem, c: Vector2, r: float, color: Color, points := 5, inner := 0.45, rot := -PI / 2) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var rr := r if i % 2 == 0 else r * inner
		var a := rot + PI * i / points
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, color)


## 아기 드래곤. facing 1 = 오른쪽을 봄.
static func draw_dragon(ci: CanvasItem, c: Vector2, r: float, element: int, rarity: int, star: int,
		t: float, facing := 1.0, flash := 0.0, silhouette := false) -> void:
	var body: Color = DragonDB.ELEMENT_COLORS[element]
	var dark := body.darkened(0.3)
	var belly := body.lightened(0.55)
	var rare: Color = Balance.RARITY_COLORS[rarity]
	if silhouette:
		body = Color(0.25, 0.22, 0.3, 0.55)
		dark = body
		belly = body
	var bob := sin(t * 3.2) * r * 0.06
	var p := c + Vector2(0, bob)
	var f := facing

	# 오라 (★5 이상)
	if star >= 5 and not silhouette:
		var pulse := 0.22 + 0.08 * sin(t * 4.0)
		ci.draw_circle(p, r * 1.45, Color(rare.r, rare.g, rare.b, pulse * 0.6))
		ci.draw_circle(p, r * 1.25, Color(rare.r, rare.g, rare.b, pulse))

	# 꼬리
	var tip := p + Vector2(-f * r * 1.5, -r * 0.2 + sin(t * 5) * r * 0.08)
	var tail := PackedVector2Array([p + Vector2(-f * r * 0.5, r * 0.05), tip, p + Vector2(-f * r * 0.35, r * 0.65)])
	if f < 0:
		tail.reverse()
	ci.draw_colored_polygon(tail, dark)
	draw_star_shape(ci, tip, r * 0.22, dark, 3, 0.5, PI if f > 0 else 0.0)

	# 날개 (★3부터 커짐)
	var wing_scale := 0.8 if star < 3 else 1.15
	var flap := sin(t * 7.0) * 0.25
	for side in [-1.0, 1.0]:
		var base := p + Vector2(-f * r * 0.25, -r * 0.45)
		var wing := PackedVector2Array([
			base,
			base + (Vector2(-f * r * 1.25, -r * 1.05 - side * r * 0.1) * wing_scale).rotated(flap * side * f),
			base + (Vector2(-f * r * 0.8, -r * 0.45) * wing_scale).rotated(flap * side * f),
			base + (Vector2(-f * r * 1.2, -r * 0.3) * wing_scale).rotated(flap * side * f),
			base + Vector2(-f * r * 0.1, r * 0.3),
		])
		if f < 0:
			wing.reverse()
		ci.draw_colored_polygon(wing, dark if side < 0 else dark.lightened(0.15))

	# 발
	ci.draw_circle(p + Vector2(-r * 0.4, r * 0.85), r * 0.24, dark)
	ci.draw_circle(p + Vector2(r * 0.4, r * 0.85), r * 0.24, dark)

	# 몸통 (동글동글)
	ci.draw_circle(p, r * 1.02, OUTLINE if not silhouette else body)
	ci.draw_circle(p, r, body)
	draw_ellipse(ci, p + Vector2(f * r * 0.18, r * 0.32), r * 0.55, r * 0.5, belly)

	# 등 가시
	if not silhouette:
		for i in 3:
			var a := -PI / 2 - f * (0.5 + i * 0.45)
			var sp := p + Vector2(cos(a), sin(a)) * r * 0.95
			draw_star_shape(ci, sp, r * 0.16, dark, 3, 0.4, a)

	# 뿔 (★2 이상)
	if star >= 2:
		var horn := Color("#fff1c9") if not silhouette else body
		for hx in [0.05, 0.5]:
			var hb := p + Vector2(f * r * hx, -r * 0.88)
			ci.draw_colored_polygon(PackedVector2Array([
				hb + Vector2(-r * 0.12, 0), hb + Vector2(f * r * 0.08, -r * 0.42), hb + Vector2(r * 0.12, 0)]), horn)

	# 왕관 (★4 이상)
	if star >= 4 and not silhouette:
		var cb := p + Vector2(f * r * 0.15, -r * 1.05)
		var gold := Color("#ffd23f")
		ci.draw_colored_polygon(PackedVector2Array([
			cb + Vector2(-r * 0.35, 0), cb + Vector2(-r * 0.35, -r * 0.3), cb + Vector2(-r * 0.17, -r * 0.13),
			cb + Vector2(0, -r * 0.38), cb + Vector2(r * 0.17, -r * 0.13), cb + Vector2(r * 0.35, -r * 0.3),
			cb + Vector2(r * 0.35, 0)]), gold)
		ci.draw_circle(cb + Vector2(0, -r * 0.1), r * 0.06, rare)

	if silhouette:
		var font := ThemeDB.fallback_font
		ci.draw_string(font, p + Vector2(-r * 0.3, r * 0.35), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r), Color(1, 1, 1, 0.7))
		return

	# 눈 (큼직하게)
	var blink := fmod(t + element * 0.7, 4.0) > 3.85
	for ex in [0.12, 0.55]:
		var e := p + Vector2(f * r * ex, -r * 0.18)
		if blink:
			ci.draw_line(e + Vector2(-r * 0.15, 0), e + Vector2(r * 0.15, 0), OUTLINE, maxf(2.0, r * 0.07))
		else:
			ci.draw_circle(e, r * 0.21, Color.WHITE)
			ci.draw_circle(e + Vector2(f * r * 0.04, r * 0.02), r * 0.14, OUTLINE)
			ci.draw_circle(e + Vector2(f * r * 0.0 - r * 0.03, -r * 0.05), r * 0.055, Color.WHITE)
	# 볼터치
	ci.draw_circle(p + Vector2(f * r * 0.0, r * 0.12), r * 0.11, Color(1, 0.45, 0.55, 0.45))
	ci.draw_circle(p + Vector2(f * r * 0.75, r * 0.1), r * 0.1, Color(1, 0.45, 0.55, 0.45))
	# 입
	ci.draw_arc(p + Vector2(f * r * 0.35, r * 0.08), r * 0.1, 0.2, PI - 0.2, 8, OUTLINE, maxf(1.5, r * 0.05))

	# 반짝이 (★6)
	if star >= 6:
		for i in 4:
			var a := t * 1.5 + TAU * i / 4
			var sp := p + Vector2(cos(a), sin(a)) * r * 1.35
			draw_star_shape(ci, sp, r * (0.12 + 0.05 * sin(t * 6 + i)), Color.WHITE, 4, 0.35)

	if flash > 0.0:
		ci.draw_circle(p, r * 1.05, Color(1, 1, 1, flash * 0.7))


## 슬라임형 몬스터
static func draw_monster(ci: CanvasItem, c: Vector2, r: float, color: Color, t: float, boss := false, flash := 0.0, variant := 0) -> void:
	var squish := 1.0 + sin(t * 4.0 + c.x * 0.05) * 0.06
	var rx := r * squish
	var ry := r / squish
	var base := c + Vector2(0, r * 0.15)
	# 그림자
	draw_ellipse(ci, c + Vector2(0, r * 0.95), r * 0.9, r * 0.2, Color(0, 0, 0, 0.18))
	var pts := PackedVector2Array()
	for i in 24:
		var a := PI + PI * i / 23.0
		pts.append(base + Vector2(cos(a) * rx, sin(a) * ry * 1.1))
	pts.append(base + Vector2(rx, ry * 0.75))
	pts.append(base + Vector2(-rx, ry * 0.75))
	ci.draw_colored_polygon(pts, color.darkened(0.35))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(base + (p - base) * 0.93)
	ci.draw_colored_polygon(inner, color)
	ci.draw_circle(base + Vector2(-rx * 0.4, -ry * 0.55), r * 0.14, Color(1, 1, 1, 0.55))
	if variant == 1:
		# 버섯 모자 / 귀
		draw_ellipse(ci, base + Vector2(0, -ry * 0.95), rx * 0.85, ry * 0.35, color.darkened(0.2))
		ci.draw_circle(base + Vector2(-rx * 0.3, -ry * 1.0), r * 0.1, Color(1, 1, 1, 0.8))
		ci.draw_circle(base + Vector2(rx * 0.3, -ry * 0.95), r * 0.08, Color(1, 1, 1, 0.8))
	# 눈 (왼쪽을 봄)
	var angry := boss
	for ex in [-0.45, -0.05]:
		var e := base + Vector2(rx * ex, -ry * 0.2)
		ci.draw_circle(e, r * 0.14, Color.WHITE)
		ci.draw_circle(e + Vector2(-r * 0.03, r * 0.02), r * 0.08, OUTLINE)
		if angry:
			ci.draw_line(e + Vector2(-r * 0.16, -r * 0.2), e + Vector2(r * 0.14, -r * 0.12) if ex < -0.2 else e + Vector2(r * 0.16, -r * 0.2), OUTLINE, r * 0.06)
	ci.draw_arc(base + Vector2(-rx * 0.25, ry * 0.12), r * 0.1, 0.3, PI - 0.3, 6, OUTLINE, maxf(1.5, r * 0.04))
	if boss:
		var cb := base + Vector2(0, -ry * 1.08)
		ci.draw_colored_polygon(PackedVector2Array([
			cb + Vector2(-r * 0.4, 0), cb + Vector2(-r * 0.45, -r * 0.4), cb + Vector2(-r * 0.2, -r * 0.18),
			cb + Vector2(0, -r * 0.5), cb + Vector2(r * 0.2, -r * 0.18), cb + Vector2(r * 0.45, -r * 0.4),
			cb + Vector2(r * 0.4, 0)]), Color("#ffd23f"))
	if flash > 0.0:
		ci.draw_circle(base, r * 1.05, Color(1, 1, 1, flash * 0.6))


## 재화 아이콘: kind = "gold" | "coin" | "scale" | "mileage"
static func draw_currency(ci: CanvasItem, c: Vector2, r: float, kind: String) -> void:
	match kind:
		"gold":
			ci.draw_circle(c, r, Color("#e0a020"))
			ci.draw_circle(c, r * 0.82, Color("#ffd23f"))
			draw_star_shape(ci, c, r * 0.45, Color("#fff3b0"))
		"coin":
			ci.draw_circle(c, r, Color("#c25b8c"))
			ci.draw_circle(c, r * 0.82, Color("#ff8fc8"))
			# 집게 모양
			ci.draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, -r * 0.05), Color.WHITE, r * 0.16)
			ci.draw_arc(c + Vector2(0, r * 0.15), r * 0.32, PI * 0.1, PI * 0.9, 10, Color.WHITE, r * 0.16)
		"scale":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.85, -r * 0.1),
				c + Vector2(0, r), c + Vector2(-r * 0.85, -r * 0.1)])
			ci.draw_colored_polygon(pts, Color("#4fb3a0"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.6), c + Vector2(r * 0.45, -r * 0.05),
				c + Vector2(0, r * 0.55), c + Vector2(-r * 0.45, -r * 0.05)]), Color("#9ff0dc"))
		"mileage":
			ci.draw_rect(Rect2(c - Vector2(r, r * 0.6), Vector2(r * 2, r * 1.2)), Color("#7a6cf0"))
			draw_star_shape(ci, c, r * 0.45, Color.WHITE)
