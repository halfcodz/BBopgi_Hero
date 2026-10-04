extends Control
## 루트 화면: 상단 재화바 / 전투(항상 보임) / 하단 탭 패널 / 탭바 (기획서 11장)

const TABS := [
	{"key": "dragon", "name": "드래곤", "script": "res://scripts/ui/dragon_panel.gd"},
	{"key": "gacha", "name": "뽑기", "script": "res://scripts/gacha/claw_machine.gd"},
	{"key": "growth", "name": "성장", "script": "res://scripts/ui/growth_panel.gd"},
	{"key": "mission", "name": "미션", "script": "res://scripts/ui/mission_panel.gd"},
]
const BATTLE_H := 480.0

var battle: BattleView
var panel_host: Control
var panels := {}
var tab_buttons := {}
var tab_dots := {}
var current_tab := ""
var gold_label: Label
var coin_label: Label
var scale_label: Label
var toast_box: VBoxContainer
var _dot_timer := 0.0


func _ready() -> void:
	theme = UIKit.make_theme()
	_build()
	Game.currency_changed.connect(_refresh_currency)
	Game.toast.connect(show_toast)
	_refresh_currency()
	switch_tab("gacha" if Game.total_pulls == 0 else "dragon")
	if not Game.offline_report.is_empty():
		_show_offline_popup.call_deferred(Game.offline_report)
		Game.offline_report = {}


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := UIKit.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# 상단 재화바
	var top := UIKit.hbox(14)
	top.custom_minimum_size = Vector2(0, 64)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(UIKit.margin(top, 16, 6, 16, 6))
	gold_label = _currency(top, "gold")
	coin_label = _currency(top, "coin")
	scale_label = _currency(top, "scale")

	# 전투
	battle = BattleView.new()
	battle.custom_minimum_size = Vector2(0, BATTLE_H)
	root.add_child(battle)

	# 하단 패널
	var panel_bg := PanelContainer.new()
	panel_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := UIKit.box(UIKit.PANEL, 0, 0)
	sb.corner_radius_top_left = 26
	sb.corner_radius_top_right = 26
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	panel_bg.add_theme_stylebox_override("panel", sb)
	root.add_child(panel_bg)
	panel_host = Control.new()
	panel_host.clip_contents = true
	panel_bg.add_child(panel_host)

	# 탭바
	var tabs := UIKit.hbox(0)
	tabs.custom_minimum_size = Vector2(0, 96)
	var tab_bg := PanelContainer.new()
	tab_bg.add_theme_stylebox_override("panel", UIKit.box(Color("#3a3158"), 0, 0))
	tab_bg.add_child(tabs)
	root.add_child(tab_bg)
	for t in TABS:
		var b := Button.new()
		b.text = t.name
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_stylebox_override("normal", UIKit.box(Color(0, 0, 0, 0), 0, 0))
		b.add_theme_stylebox_override("hover", UIKit.box(Color(1, 1, 1, 0.05), 0, 0))
		b.add_theme_stylebox_override("pressed", UIKit.box(Color(1, 1, 1, 0.1), 0, 0))
		b.pressed.connect(switch_tab.bind(t.key))
		tabs.add_child(b)
		tab_buttons[t.key] = b
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", UIKit.box(UIKit.RED_DOT, 9, 0))
		dot.size = Vector2(18, 18)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		b.add_child(dot)
		tab_dots[t.key] = dot

	# 토스트
	toast_box = UIKit.vbox(6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_box.position = Vector2(0, 80 + BATTLE_H - 140)
	add_child(toast_box)


func _currency(parent: Control, kind: String) -> Label:
	var h := UIKit.hbox(6)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chip := UIKit.card(Color(1, 1, 1, 0.1), 24)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(Widgets.currency_icon(kind, 34))
	var l := UIKit.label("0", 24, Color.WHITE)
	h.add_child(l)
	chip.add_child(h)
	parent.add_child(chip)
	return l


func _refresh_currency() -> void:
	gold_label.text = Num.fmt(Game.gold)
	coin_label.text = str(Game.coins)
	scale_label.text = str(Game.scales)


func switch_tab(key: String) -> void:
	if current_tab == key:
		return
	current_tab = key
	for k in tab_buttons:
		tab_buttons[k].add_theme_color_override("font_color", Color.WHITE if k == key else Color(1, 1, 1, 0.5))
	for k in panels:
		panels[k].visible = k == key
	if not panels.has(key):
		var p := _make_panel(key)
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel_host.add_child(p)
		panels[key] = p
	if panels[key].has_method("on_shown"):
		panels[key].on_shown()


func _make_panel(key: String) -> Control:
	for t in TABS:
		if t.key == key and ResourceLoader.exists(t.script):
			var p = load(t.script).new()
			if p is Control:
				return p
	var l := UIKit.label("준비 중이에요", 28, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	return l


func _process(delta: float) -> void:
	_dot_timer -= delta
	if _dot_timer <= 0.0:
		_dot_timer = 0.5
		_refresh_dots()


func _refresh_dots() -> void:
	var dragon_dot := false
	for id in Game.dragons:
		if Game.can_star_up(id):
			dragon_dot = true
			break
	if not dragon_dot:
		for id in Game.active_party():
			if Game.gold >= Game.level_up_cost(id):
				dragon_dot = true
				break
	var dots := {
		"dragon": dragon_dot,
		"gacha": Game.coins >= Gacha.PULL_COST,
		"growth": Game.can_prestige() and Game.prestige_gain() >= maxi(1, Game.scales),
		"mission": Game.any_mission_claimable(),
	}
	for k in tab_dots:
		var dot: Panel = tab_dots[k]
		dot.visible = dots.get(k, false)
		var b: Button = tab_buttons[k]
		dot.position = Vector2(b.size.x * 0.5 + 44, 18)


# ── 토스트 · 팝업 ───────────────────────────────────
func show_toast(text: String, color := Color.WHITE) -> void:
	var chip := UIKit.card(Color(0.16, 0.12, 0.24, 0.88), 20)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := UIKit.label(text, 24, color, HORIZONTAL_ALIGNMENT_CENTER)
	chip.add_child(l)
	toast_box.add_child(chip)
	if toast_box.get_child_count() > 3:
		toast_box.get_child(0).queue_free()
	var tw := chip.create_tween()
	chip.modulate.a = 0.0
	tw.tween_property(chip, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.8)
	tw.tween_property(chip, "modulate:a", 0.0, 0.4)
	tw.tween_callback(chip.queue_free)


## 공용 모달: 내용 Control 과 버튼 목록을 받아 띄운다.
func show_modal(title: String, body: Control, buttons: Array = []) -> Control:
	if buttons.is_empty():
		buttons = [["확인", Callable()]]
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.05, 0.12, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(size.x - 60, 620), 0)
	center.add_child(panel)
	var v := UIKit.vbox(16)
	panel.add_child(UIKit.margin(v, 24, 22, 24, 22))
	v.add_child(UIKit.label(title, 32, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(body)
	var row := UIKit.hbox(12)
	v.add_child(row)
	for spec in buttons:
		var b := UIKit.button(spec[0], spec[2] if spec.size() > 2 else UIKit.PINK)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cb: Callable = spec[1]
		b.pressed.connect(func():
			shade.queue_free()
			if cb.is_valid():
				cb.call())
		row.add_child(b)
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.custom_minimum_size / 2
	var tw := panel.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22)
	return shade


func _show_offline_popup(report: Dictionary) -> void:
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label("자는 동안 드래곤들이 모아 왔어요!", 24, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("방치 시간 " + Num.fmt_time(report.seconds), 22, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	for pair in [["gold", Num.fmt(report.gold)], ["coin", str(report.coins)]]:
		var h := UIKit.hbox(10)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(Widgets.currency_icon(pair[0], 44))
		h.add_child(UIKit.label("+" + pair[1], 34, UIKit.TEXT))
		v.add_child(h)
	show_modal("오프라인 보상", v, [["받기", Callable(), UIKit.MINT]])
