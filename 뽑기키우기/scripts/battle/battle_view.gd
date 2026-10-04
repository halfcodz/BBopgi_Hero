class_name BattleView
extends Control
## 방치형 자동 전투 (기획서 7장).
## 일반 웨이브 4개(적 3마리) + 보스 1마리. 보스를 제한시간 안에 못 잡으면 같은 스테이지를 반복한다.
## 화면을 탭하면 추가 공격 + 피버 게이지.

signal stage_cleared(stage: int)

const HEADER_H := 64.0
const DRAGON_R := 34.0
const ENEMY_R := 34.0
const PROJECTILE_SPEED := 950.0
const ENTER_TIME := 1.6
const INTRO_TIME := 1.1

# 파티 배치 (가로 비율, 세로 비율)
const SLOT_POS := [
	Vector2(0.34, 0.66), Vector2(0.21, 0.50), Vector2(0.21, 0.82), Vector2(0.08, 0.66), Vector2(0.08, 0.38),
]
const ENEMY_POS := [Vector2(0.66, 0.58), Vector2(0.80, 0.74), Vector2(0.92, 0.56)]

var cur_stage := -1
var wave := 1
var phase := "intro"           # intro, enter, fight, clear, fail
var phase_time := 0.0
var enemies: Array = []
var party_ids: Array = []
var party_hp := 1.0
var party_max := 1.0
var atk_timers := {}
var skill_timers := {}
var dragon_flash := {}
var boss_time_left := 0.0
var boss_time_max := 1.0
var atk_buff := 0.0
var atk_buff_until := 0.0
var gold_buff := 0.0
var gold_buff_until := 0.0
var stun_until := 0.0
var fever := 0.0
var fever_until := 0.0
var banner := ""
var banner_color := Color.WHITE
var banner_time := 0.0
var shake := 0.0
var now := 0.0

var projectiles: Array = []
var popups: Array = []
var particles: Array = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	Game.stage_changed.connect(_on_stage_changed)
	Game.party_changed.connect(_refresh_party)
	Game.dragons_changed.connect(_refresh_party)
	_refresh_party()
	start_stage(Game.stage)


# ── 상태 전환 ───────────────────────────────────────
func start_stage(s: int, after_clear := false) -> void:
	cur_stage = s
	wave = 1
	enemies.clear()
	projectiles.clear()
	party_hp = party_max
	_set_phase("intro")
	if after_clear:
		_show_banner("CLEAR!  다음은 " + Balance.stage_label(s), Color("#ffe066"), INTRO_TIME)
	else:
		_show_banner("STAGE " + Balance.stage_label(s), Color.WHITE, INTRO_TIME)


func _on_stage_changed() -> void:
	if Game.stage != cur_stage:
		start_stage(Game.stage, phase == "clear")


func _refresh_party() -> void:
	var ratio := party_hp / party_max if party_max > 0 else 1.0
	party_ids = Game.active_party()
	party_max = Game.party_max_hp()
	party_hp = clampf(party_max * ratio, 1.0, party_max)
	for id in party_ids:
		if not atk_timers.has(id):
			atk_timers[id] = rng.randf() * Balance.ATTACK_INTERVAL
		var sk: Dictionary = DragonDB.get_dragon(id).get("skill", {})
		if not skill_timers.has(id) and not sk.is_empty():
			skill_timers[id] = sk.cd * 0.5


func _set_phase(p: String) -> void:
	phase = p
	phase_time = 0.0


func _is_boss_wave() -> bool:
	return wave == Balance.WAVES_PER_STAGE


func _spawn_wave() -> void:
	enemies.clear()
	var ch := DragonDB.chapter(cur_stage)
	var kinds: Array = ch.enemies
	var hp := Balance.enemy_hp(cur_stage)
	if _is_boss_wave():
		var chapter_boss := Balance.is_chapter_boss(cur_stage)
		var mult := Balance.CHAPTER_BOSS_HP_MULT if chapter_boss else Balance.STAGE_BOSS_HP_MULT
		var kind: Dictionary = kinds[1 if chapter_boss else 0]
		var r := ENEMY_R * (2.3 if chapter_boss else 1.8)
		enemies.append(_make_enemy(kind, hp * mult, Vector2(0.78, 0.64), r, true, 1))
		boss_time_max = Balance.CHAPTER_BOSS_TIME if chapter_boss else Balance.STAGE_BOSS_TIME
		boss_time_left = boss_time_max
	else:
		for i in Balance.ENEMIES_PER_WAVE:
			var kind: Dictionary = kinds[rng.randi() % kinds.size()]
			enemies.append(_make_enemy(kind, hp, ENEMY_POS[i], ENEMY_R * rng.randf_range(0.9, 1.1), false, kinds.find(kind)))
	_set_phase("enter")


func _make_enemy(kind: Dictionary, hp: float, rel: Vector2, r: float, boss: bool, variant: int) -> Dictionary:
	var target := Vector2(size.x * rel.x, size.y * rel.y)
	return {
		"hp": hp, "max_hp": hp, "pos": target + Vector2(size.x * 0.5, 0), "target": target,
		"r": r, "boss": boss, "color": kind.color, "element": kind.element, "name": kind.name,
		"flash": 0.0, "atk_timer": 1.0, "alive": true, "variant": variant, "death": 0.0,
	}


# ── 루프 ────────────────────────────────────────────
func _process(delta: float) -> void:
	now += delta
	phase_time += delta
	var speed := 2.0 if is_fever() else 1.0

	match phase:
		"intro":
			if phase_time >= INTRO_TIME:
				_spawn_wave()
		"enter":
			var k := clampf(phase_time / ENTER_TIME, 0.0, 1.0)
			for e in enemies:
				e.pos = e.target + Vector2(size.x * 0.5 * pow(1.0 - k, 2.0), 0)
			if k >= 1.0:
				_set_phase("fight")
		"fight":
			_update_fight(delta, speed)
		"clear":
			if phase_time >= 0.6:
				_next_wave()
		"fail":
			if phase_time >= 1.6:
				start_stage(cur_stage)

	_update_effects(delta)
	queue_redraw()


func _update_fight(delta: float, speed: float) -> void:
	# 드래곤 공격
	for id in party_ids:
		atk_timers[id] -= delta * speed
		if atk_timers[id] <= 0.0:
			atk_timers[id] += Balance.ATTACK_INTERVAL
			_fire(id, 1.0, false)
		if skill_timers.has(id):
			skill_timers[id] -= delta * speed
			if skill_timers[id] <= 0.0 and _front_enemy() != null:
				var sk: Dictionary = DragonDB.get_dragon(id).skill
				skill_timers[id] = sk.cd
				_cast_skill(id, sk)
	# 적 공격 (맨 앞 적만)
	var front = _front_enemy()
	if front != null and now >= stun_until:
		front.atk_timer -= delta
		if front.atk_timer <= 0.0:
			front.atk_timer = 1.0
			var dmg := Balance.enemy_atk(cur_stage) * (Balance.BOSS_ATK_MULT if front.boss else 1.0)
			party_hp -= dmg
			_hit_random_dragon()
			if party_hp <= 0.0:
				party_hp = 0.0
				_fail("파티가 지쳤어요… 다시 도전!")
				return
	# 보스 타이머
	if _is_boss_wave():
		boss_time_left -= delta
		if boss_time_left <= 0.0 and _front_enemy() != null:
			_fail("보스 도전 실패! 레벨업 후 재도전")
			return
	if _front_enemy() == null and projectiles.is_empty():
		_set_phase("clear")


func _next_wave() -> void:
	if wave >= Balance.WAVES_PER_STAGE:
		var cleared := cur_stage
		_burst(Vector2(size.x * 0.5, size.y * 0.45), Color("#ffe066"), 30)
		Game.on_stage_cleared()      # stage_changed → start_stage 로 이어진다
		stage_cleared.emit(cleared)
		return
	wave += 1
	party_hp = minf(party_max, party_hp + party_max * Balance.WAVE_HEAL_RATIO)
	if _is_boss_wave():
		var boss_name := "챕터 보스" if Balance.is_chapter_boss(cur_stage) else "보스"
		_show_banner(boss_name + " 등장!", Color("#ff6b81"), 1.0)
		shake = 8.0
	_spawn_wave()


func _fail(msg: String) -> void:
	_show_banner(msg, Color("#ff9aa2"), 1.6)
	projectiles.clear()
	_set_phase("fail")


# ── 공격·스킬 ───────────────────────────────────────
func _front_enemy():
	for e in enemies:
		if e.alive:
			return e
	return null


func _alive_enemies() -> Array:
	return enemies.filter(func(e): return e.alive)


func dragon_pos(id: String) -> Vector2:
	var idx := party_ids.find(id)
	if idx < 0:
		return Vector2.ZERO
	var rel: Vector2 = SLOT_POS[idx]
	return Vector2(size.x * rel.x, size.y * rel.y)


func _atk_mult() -> float:
	return 1.0 + (atk_buff if now < atk_buff_until else 0.0)


func _gold_mult() -> float:
	var m := 1.0 + (gold_buff if now < gold_buff_until else 0.0)
	if is_fever():
		m *= 2.0
	return m


func _fire(id: String, power: float, big: bool) -> void:
	var target = _front_enemy()
	if target == null:
		return
	var d := DragonDB.get_dragon(id)
	projectiles.append({
		"pos": dragon_pos(id) + Vector2(DRAGON_R * 0.8, -6), "target": target,
		"id": id, "power": power, "big": big, "color": DragonDB.ELEMENT_COLORS[d.element],
		"element": d.element,
	})


func _calc_damage(id: String, power: float, target: Dictionary) -> Array:
	var d := DragonDB.get_dragon(id)
	var dmg := Game.dragon_atk(id) * power * _atk_mult() * Balance.element_mult(d.element, target.element)
	var crit := rng.randf() < Balance.CRIT_CHANCE
	if crit:
		dmg *= Balance.CRIT_MULT
	return [dmg, crit]


func _cast_skill(id: String, sk: Dictionary) -> void:
	var pos := dragon_pos(id)
	dragon_flash[id] = 1.0
	_popup(sk.name, pos + Vector2(0, -DRAGON_R - 20), Balance.RARITY_COLORS[DragonDB.get_dragon(id).rarity], 22, 1.2)
	match sk.type:
		"single":
			_fire(id, sk.power, true)
		"aoe":
			var color: Color = DragonDB.ELEMENT_COLORS[DragonDB.get_dragon(id).element]
			for e in _alive_enemies():
				var res := _calc_damage(id, sk.power, e)
				_damage_enemy(e, res[0], res[1], true)
				_burst(e.pos, color, 10)
			shake = maxf(shake, 6.0)
			if sk.has("stun"):
				stun_until = now + sk.stun
			if sk.has("gold"):
				gold_buff = sk.gold
				gold_buff_until = now + sk.dur
		"heal":
			party_hp = minf(party_max, party_hp + party_max * sk.power)
			for pid in party_ids:
				_burst(dragon_pos(pid), Color("#9ff0c0"), 5)
		"buff_atk":
			atk_buff = sk.power
			atk_buff_until = now + sk.dur
		"buff_gold":
			gold_buff = sk.power
			gold_buff_until = now + sk.dur


func _damage_enemy(e: Dictionary, dmg: float, crit: bool, big := false) -> void:
	if not e.alive:
		return
	e.hp -= dmg
	e.flash = 1.0
	var col := Color("#fff27a") if crit else Color.WHITE
	var sz := 30 if crit or big else 22
	_popup(Num.fmt(dmg) + ("!" if crit else ""), e.pos + Vector2(rng.randf_range(-20, 20), -e.r - 10), col, sz, 0.8)
	if e.hp <= 0.0:
		_kill(e)


func _kill(e: Dictionary) -> void:
	e.alive = false
	e.hp = 0.0
	var g := Balance.kill_gold(cur_stage) * Balance.scale_mult(Game.scales) * _gold_mult()
	if e.boss:
		g *= Balance.BOSS_GOLD_MULT
		Game.add_mission_progress("bosses", 1)
		shake = 12.0
		_burst(e.pos, Color("#ffd23f"), 40)
	Game.add_gold(g)
	Game.on_kill(1)
	_popup("+" + Num.fmt(g), e.pos + Vector2(0, -e.r - 40), Color("#ffd23f"), 26, 1.0, true)
	_burst(e.pos, e.color, 14)


func _hit_random_dragon() -> void:
	if party_ids.is_empty():
		return
	var id: String = party_ids[rng.randi() % party_ids.size()]
	dragon_flash[id] = 0.6


# ── 탭 · 피버 ───────────────────────────────────────
func is_fever() -> bool:
	return now < fever_until


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap(event.position)
		accept_event()


func _tap(at: Vector2) -> void:
	_burst(at, Color.WHITE, 4)
	if not is_fever():
		fever = minf(1.0, fever + Balance.FEVER_PER_TAP)
		if fever >= 1.0:
			fever = 0.0
			fever_until = now + Balance.FEVER_DURATION
			_show_banner("FEVER TIME!", Color("#ff8fd8"), 1.0)
			shake = 10.0
	if phase != "fight":
		return
	var e = _front_enemy()
	if e == null:
		return
	var dmg := Game.party_atk_sum() * Balance.TAP_DAMAGE_RATIO * _atk_mult()
	_damage_enemy(e, dmg, false)


# ── 이펙트 ──────────────────────────────────────────
func _show_banner(text: String, color: Color, dur: float) -> void:
	banner = text
	banner_color = color
	banner_time = dur


func _popup(text: String, pos: Vector2, color: Color, font_size: int, life: float, rise := false) -> void:
	popups.append({"text": text, "pos": pos, "color": color, "size": font_size, "life": life, "max": life,
		"vel": Vector2(rng.randf_range(-15, 15), -90.0 if rise else -55.0)})
	if popups.size() > 60:
		popups.pop_front()


func _burst(pos: Vector2, color: Color, n: int) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var sp := rng.randf_range(80, 260)
		particles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * sp, "life": rng.randf_range(0.3, 0.7),
			"color": color, "r": rng.randf_range(3, 7)})
	if particles.size() > 300:
		particles = particles.slice(particles.size() - 300)


func _update_effects(delta: float) -> void:
	# 투사체
	var keep := []
	for p in projectiles:
		var target = p.target
		if not target.alive:
			target = _front_enemy()
			if target == null:
				continue
			p.target = target
		var to: Vector2 = target.pos - p.pos
		var step := PROJECTILE_SPEED * delta
		if to.length() <= step + target.r * 0.5:
			var res := _calc_damage(p.id, p.power, target)
			_damage_enemy(target, res[0], res[1], p.big)
			if p.big:
				_burst(target.pos, p.color, 16)
				shake = maxf(shake, 5.0)
		else:
			p.pos += to.normalized() * step
			keep.append(p)
	projectiles = keep
	# 팝업·파티클
	for p in popups:
		p.life -= delta
		p.pos += p.vel * delta
	popups = popups.filter(func(p): return p.life > 0.0)
	for p in particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.9
	particles = particles.filter(func(p): return p.life > 0.0)
	for e in enemies:
		e.flash = maxf(0.0, e.flash - delta * 5.0)
		if not e.alive:
			e.death += delta
	for id in dragon_flash.keys():
		dragon_flash[id] = maxf(0.0, dragon_flash[id] - delta * 3.0)
	banner_time -= delta
	shake = maxf(0.0, shake - delta * 30.0)


# ── 그리기 ──────────────────────────────────────────
func _draw() -> void:
	var font := get_theme_default_font()
	var ch := DragonDB.chapter(maxi(cur_stage, 0))
	var off := Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake)) if shake > 0.5 else Vector2.ZERO
	draw_set_transform(off)

	# 배경 그라데이션 + 언덕
	var top: Color = ch.bg_top
	var bottom: Color = ch.bg_bottom
	draw_polygon(PackedVector2Array([Vector2(-20, -20), Vector2(size.x + 20, -20), Vector2(size.x + 20, size.y + 20), Vector2(-20, size.y + 20)]),
		PackedColorArray([top, top, bottom, bottom]))
	for i in 3:
		var hx := fmod(i * 310.0 + 40.0, size.x + 200.0) - 100.0
		DragonArt.draw_ellipse(self, Vector2(hx, size.y * 0.42), 220, 70, top.lerp(bottom, 0.35 + i * 0.05))
	draw_rect(Rect2(-20, size.y * 0.42, size.x + 40, size.y), bottom.lerp(top, 0.15))
	for i in 8:
		var gx := fmod(i * 97.0 + 13.0, size.x)
		DragonArt.draw_ellipse(self, Vector2(gx, size.y * (0.5 + 0.06 * (i % 4))), 18, 6, bottom.darkened(0.08))

	if is_fever():
		var a := 0.25 + 0.15 * sin(now * 10.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.55, 0.85, a), false, 10.0)

	# 드래곤
	for id in party_ids:
		var d := DragonDB.get_dragon(id)
		var p := dragon_pos(id)
		DragonArt.draw_ellipse(self, p + Vector2(0, DRAGON_R * 1.05), DRAGON_R * 0.9, DRAGON_R * 0.22, Color(0, 0, 0, 0.18))
		DragonArt.draw_dragon(self, p, DRAGON_R, d.element, d.rarity, Game.dragon_star(id), now + p.y * 0.01, 1.0,
			dragon_flash.get(id, 0.0))
		if skill_timers.has(id):
			var sk: Dictionary = d.skill
			var k := 1.0 - clampf(skill_timers[id] / sk.cd, 0.0, 1.0)
			draw_arc(p + Vector2(0, DRAGON_R + 16), 7, -PI / 2, -PI / 2 + TAU * k, 16, Balance.RARITY_COLORS[d.rarity], 3.0)

	# 적
	for e in enemies:
		if not e.alive and e.death > 0.35:
			continue
		var scale_k := 1.0 if e.alive else maxf(0.0, 1.0 - e.death / 0.35)
		DragonArt.draw_monster(self, e.pos, e.r * scale_k, e.color, now, e.boss, e.flash, e.variant)
		if e.alive:
			var w: float = e.r * 1.8
			var bar := Rect2(e.pos + Vector2(-w / 2, e.r + 14), Vector2(w, 8))
			draw_rect(bar, Color(0, 0, 0, 0.35))
			draw_rect(Rect2(bar.position, Vector2(w * e.hp / e.max_hp, 8)), Color("#ff6b81"))

	# 투사체
	for p in projectiles:
		var r := 14.0 if p.big else 7.0
		draw_circle(p.pos, r * 1.6, Color(p.color.r, p.color.g, p.color.b, 0.3))
		draw_circle(p.pos, r, p.color)
		draw_circle(p.pos, r * 0.45, Color.WHITE)
	for p in particles:
		draw_circle(p.pos, p.r * clampf(p.life * 2.0, 0.0, 1.0), p.color)
	for p in popups:
		var alpha := clampf(p.life / p.max * 1.6, 0.0, 1.0)
		var c: Color = p.color
		c.a = alpha
		draw_string_outline(font, p.pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, -1, p.size, 6, Color(0.2, 0.12, 0.25, alpha))
		draw_string(font, p.pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, -1, p.size, c)

	draw_set_transform(Vector2.ZERO)
	_draw_hud(font)


func _draw_hud(font: Font) -> void:
	# 상단 스테이지 정보
	draw_rect(Rect2(0, 0, size.x, HEADER_H), Color(0.15, 0.1, 0.2, 0.35))
	var title := "%s  %s" % [Balance.stage_label(maxi(cur_stage, 0)), DragonDB.chapter_title(maxi(cur_stage, 0))]
	_text(font, Vector2(16, 30), title, 24, Color.WHITE)
	for i in Balance.WAVES_PER_STAGE:
		var c := Vector2(20 + i * 30, 50)
		var filled := i < wave - 1 or (i == wave - 1 and phase != "intro")
		var col := Color("#ff6b81") if i == Balance.WAVES_PER_STAGE - 1 else Color("#ffe066")
		draw_circle(c, 9, Color(1, 1, 1, 0.35))
		if filled:
			draw_circle(c, 7, col)
	if Game.scales > 0:
		_text(font, Vector2(size.x - 16, 30), "비늘 +%d%%" % int(Game.scales * Balance.SCALE_BONUS * 100), 20, Color("#9ff0dc"), HORIZONTAL_ALIGNMENT_RIGHT)
	var buffs := []
	if now < atk_buff_until: buffs.append("공격 UP")
	if now < gold_buff_until: buffs.append("골드 UP")
	if is_fever(): buffs.append("피버 %.0f초" % (fever_until - now))
	if not buffs.is_empty():
		_text(font, Vector2(size.x - 16, 54), " · ".join(PackedStringArray(buffs)), 18, Color("#ffe066"), HORIZONTAL_ALIGNMENT_RIGHT)

	# 보스 타이머
	if _is_boss_wave() and phase == "fight":
		var w := size.x * 0.5
		var r := Rect2(size.x * 0.25, HEADER_H + 12, w, 16)
		draw_rect(r, Color(0, 0, 0, 0.35))
		var k := clampf(boss_time_left / boss_time_max, 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(w * k, 16)), Color("#ff6b81") if k < 0.3 else Color("#ffa94d"))
		_text(font, Vector2(size.x * 0.5, HEADER_H + 50), "보스 %.1f초" % maxf(boss_time_left, 0.0), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

	# 하단: 파티 체력 + 피버 게이지
	var by := size.y - 34
	var bw := size.x * 0.42
	draw_rect(Rect2(16, by, bw, 14), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(16, by, bw * clampf(party_hp / party_max, 0, 1), 14), Color("#7ee08a"))
	_text(font, Vector2(16, by - 6), "파티 체력", 16, Color.WHITE)
	var fx := size.x - 16 - bw
	draw_rect(Rect2(fx, by, bw, 14), Color(0, 0, 0, 0.35))
	var fk := (fever_until - now) / Balance.FEVER_DURATION if is_fever() else fever
	draw_rect(Rect2(fx, by, bw * clampf(fk, 0, 1), 14), Color("#ff8fd8"))
	_text(font, Vector2(fx, by - 6), "피버 (화면을 톡톡!)" if not is_fever() else "FEVER x2", 16, Color.WHITE)

	# 배너
	if banner_time > 0.0:
		var alpha := clampf(banner_time * 3.0, 0.0, 1.0)
		var c := banner_color
		c.a = alpha
		var y := size.y * 0.36
		draw_rect(Rect2(0, y - 44, size.x, 64), Color(0.15, 0.1, 0.2, 0.45 * alpha))
		draw_string_outline(font, Vector2(0, y), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, 8, Color(0.2, 0.1, 0.25, alpha))
		draw_string(font, Vector2(0, y), banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, c)


func _text(font: Font, pos: Vector2, text: String, fs: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var x := pos.x
	var w := -1.0
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		w = 400.0
		x -= w
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		w = 400.0
		x -= w / 2
	draw_string_outline(font, Vector2(x, pos.y), text, align, w, fs, 5, Color(0.2, 0.12, 0.25, 0.8))
	draw_string(font, Vector2(x, pos.y), text, align, w, fs, color)
