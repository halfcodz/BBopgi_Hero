extends Control
## 드래곤 탭: 파티 편성 / 선택한 드래곤 상세(레벨업·승급·편성) / 도감 그리드

var selected := ""
var party_row: HBoxContainer
var power_label: Label
var detail_view: DragonView
var detail_name: Label
var detail_stats: Label
var detail_skill: Label
var shard_bar: ProgressBar
var shard_label: Label
var btn_level: Button
var btn_star: Button
var btn_party: Button
var grid: GridContainer
var _hold_t := 0.0
var _hold_interval := 0.0
var _holding := false
var _dirty := true


func _ready() -> void:
	_build()
	Game.dragons_changed.connect(_mark_dirty)
	Game.party_changed.connect(_mark_dirty)
	Game.currency_changed.connect(_refresh_buttons)
	var p := Game.active_party()
	selected = p[0] if not p.is_empty() else ""


func on_shown() -> void:
	_mark_dirty()


func _mark_dirty() -> void:
	_dirty = true


func _build() -> void:
	var v := UIKit.vbox(10)
	var m := UIKit.margin(v, 16, 14, 16, 8)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)

	# 파티
	var head := UIKit.hbox(8)
	v.add_child(head)
	power_label = UIKit.label("", 22)
	power_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(power_label)
	var auto_btn := UIKit.button("자동 편성", UIKit.MINT, 20, Vector2(130, 44))
	auto_btn.pressed.connect(func(): Game.auto_party())
	head.add_child(auto_btn)
	party_row = UIKit.hbox(8)
	v.add_child(party_row)

	# 상세
	var detail := UIKit.card(UIKit.PANEL_DARK, 20)
	v.add_child(detail)
	var dh := UIKit.hbox(10)
	detail.add_child(dh)
	detail_view = Widgets.dragon_view("", 132)
	dh.add_child(detail_view)
	var info := UIKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(info)
	detail_name = UIKit.label("", 26)
	info.add_child(detail_name)
	detail_stats = UIKit.label("", 19, UIKit.TEXT_SOFT)
	info.add_child(detail_stats)
	detail_skill = UIKit.label("", 18, UIKit.TEXT_SOFT)
	detail_skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail_skill)
	var sh := UIKit.hbox(6)
	info.add_child(sh)
	shard_bar = ProgressBar.new()
	shard_bar.show_percentage = false
	shard_bar.custom_minimum_size = Vector2(0, 14)
	shard_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shard_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shard_bar.add_theme_stylebox_override("background", UIKit.box(Color(0, 0, 0, 0.1), 7, 0))
	shard_bar.add_theme_stylebox_override("fill", UIKit.box(Color("#ffc94a"), 7, 0))
	sh.add_child(shard_bar)
	shard_label = UIKit.label("", 17, UIKit.TEXT_SOFT)
	sh.add_child(shard_label)

	var btns := UIKit.hbox(8)
	v.add_child(btns)
	btn_level = UIKit.button("", UIKit.PINK, 20, Vector2(0, 64))
	btn_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_level.size_flags_stretch_ratio = 1.6
	btn_level.button_down.connect(_on_level_down)
	btn_level.button_up.connect(func(): _holding = false)
	btns.add_child(btn_level)
	btn_star = UIKit.button("", Color("#ffb020"), 20, Vector2(0, 64))
	btn_star.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_star.pressed.connect(_on_star)
	btns.add_child(btn_star)
	btn_party = UIKit.button("", UIKit.SKY, 20, Vector2(0, 64))
	btn_party.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_party.pressed.connect(_on_party_btn)
	btns.add_child(btn_party)

	# 도감
	v.add_child(UIKit.label("도감", 22))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)


func _process(delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		_rebuild()
	if _holding:
		_hold_t += delta
		if _hold_t >= _hold_interval:
			_hold_t = 0.0
			_hold_interval = maxf(0.05, _hold_interval * 0.8)
			if not Game.level_up(selected):
				_holding = false


func _rebuild() -> void:
	if selected == "" or not Game.has_dragon(selected):
		var p := Game.active_party()
		selected = p[0] if not p.is_empty() else ""
	_build_party()
	_build_grid()
	_refresh_detail()


func _build_party() -> void:
	UIKit.clear(party_row)
	var slots := Game.party_slots()
	var total := 0.0
	for i in 5:
		var id: String = Game.party[i] if i < slots else ""
		var locked := i >= slots
		var card := _slot_card(id, locked, Balance.SLOT_UNLOCK_STAGE[i])
		party_row.add_child(card)
		if id != "":
			total += Game.dragon_power(id)
	power_label.text = "파티 전투력 %s" % Num.fmt(total)


func _slot_card(id: String, locked: bool, unlock_stage: int) -> Control:
	var c := UIKit.card(Color("#ffe1ea") if id != "" else Color(0, 0, 0, 0.06), 16)
	c.custom_minimum_size = Vector2(0, 112)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(0)
	c.add_child(v)
	if locked:
		v.add_child(UIKit.label("잠김", 20, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UIKit.label(Balance.stage_label(unlock_stage) + "\n해금", 16, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
		v.alignment = BoxContainer.ALIGNMENT_CENTER
	elif id == "":
		v.add_child(UIKit.label("+", 40, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UIKit.label("빈 슬롯", 16, UIKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
		v.alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		var dv := Widgets.dragon_view(id, 76)
		v.add_child(dv)
		v.add_child(UIKit.label("Lv.%d" % Game.dragon_level(id), 17, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		c.gui_input.connect(_on_card_input.bind(id))
		if id == selected:
			c.add_theme_stylebox_override("panel", UIKit.box(Color("#ffe1ea"), 16, 0, 3, UIKit.PINK))
	return c


func _build_grid() -> void:
	UIKit.clear(grid)
	var ids := []
	for d in DragonDB.DRAGONS:
		ids.append(d.id)
	# 보유 → 등급 높은 순, 미보유는 뒤로
	ids.sort_custom(func(a, b):
		var ha := Game.has_dragon(a)
		var hb := Game.has_dragon(b)
		if ha != hb:
			return ha
		var ra: int = DragonDB.get_dragon(a).rarity
		var rb: int = DragonDB.get_dragon(b).rarity
		if ra != rb:
			return ra > rb
		return DragonDB.DRAGONS.find(DragonDB.get_dragon(a)) < DragonDB.DRAGONS.find(DragonDB.get_dragon(b)))
	for id in ids:
		grid.add_child(_grid_card(id))


func _grid_card(id: String) -> Control:
	var d := DragonDB.get_dragon(id)
	var owned := Game.has_dragon(id)
	var rc: Color = Balance.RARITY_COLORS[d.rarity]
	var bg := Color("#fffaf3") if owned else Color(0, 0, 0, 0.05)
	var border := UIKit.PINK if id == selected else (rc if owned else Color(0, 0, 0, 0.08))
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UIKit.box(bg, 14, 0, 3, border))
	c.custom_minimum_size = Vector2(118, 150)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(0)
	c.add_child(v)
	var top := UIKit.label(Balance.RARITY_CODES[d.rarity], 15, rc.darkened(0.15) if owned else UIKit.TEXT_SOFT)
	v.add_child(top)
	var dv := Widgets.dragon_view(id, 72, not owned)
	v.add_child(dv)
	v.add_child(UIKit.label(d.name if owned else "???", 16, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if owned:
		var stars := "★".repeat(Game.dragon_star(id))
		var badge := ""
		if Game.can_star_up(id):
			badge = " ▲"
		v.add_child(UIKit.label("Lv.%d %s%s" % [Game.dragon_level(id), stars, badge], 13, Color("#e0a020"), HORIZONTAL_ALIGNMENT_CENTER))
		c.gui_input.connect(_on_card_input.bind(id))
	return c


func _on_card_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected = id
		_mark_dirty()


func _refresh_detail() -> void:
	if selected == "":
		return
	var d := DragonDB.get_dragon(selected)
	detail_view.dragon_id = selected
	var star := Game.dragon_star(selected)
	detail_name.text = "%s  %s %s" % [d.name, Balance.RARITY_CODES[d.rarity], "★".repeat(star)]
	detail_name.add_theme_color_override("font_color", Balance.RARITY_COLORS[d.rarity].darkened(0.25))
	detail_stats.text = "Lv.%d · %s 속성 · 공격 %s · 체력 %s" % [Game.dragon_level(selected),
		DragonDB.ELEMENT_NAMES[d.element], Num.fmt(Game.dragon_atk(selected)), Num.fmt(Game.dragon_hp(selected))]
	var sk: Dictionary = d.get("skill", {})
	detail_skill.text = ("[%s] " % sk.name if not sk.is_empty() else "") + DragonDB.skill_text(sk)
	var cost := Balance.star_cost(star)
	var shards: int = Game.dragons[selected].shards
	if cost > 0:
		shard_bar.max_value = cost
		shard_bar.value = mini(shards, cost)
		shard_label.text = "★조각 %d/%d" % [shards, cost]
	else:
		shard_bar.max_value = 1
		shard_bar.value = 1
		shard_label.text = "최고 별 달성"
	_refresh_buttons()


func _refresh_buttons() -> void:
	if selected == "" or btn_level == null or not Game.has_dragon(selected):
		return
	var cost := Game.level_up_cost(selected)
	btn_level.text = "레벨업  %s 골드\n(꾹 누르면 연속)" % Num.fmt(cost)
	btn_level.disabled = Game.gold < cost
	var sc := Balance.star_cost(Game.dragon_star(selected))
	btn_star.text = "승급\n★%d → ★%d" % [Game.dragon_star(selected), Game.dragon_star(selected) + 1] if sc > 0 else "최고 별"
	btn_star.disabled = not Game.can_star_up(selected)
	var in_party := Game.is_in_party(selected)
	btn_party.text = "편성 해제" if in_party else "파티 편성"


func _on_party_btn() -> void:
	if selected != "":
		Game.toggle_party(selected)


func _on_level_down() -> void:
	if Game.level_up(selected):
		_holding = true
		_hold_t = 0.0
		_hold_interval = 0.35


func _on_star() -> void:
	if Game.star_up(selected):
		var d := DragonDB.get_dragon(selected)
		Game.toast.emit("%s ★%d 달성! 공격력 x%.1f" % [d.name, Game.dragon_star(selected), Balance.star_mult(Game.dragon_star(selected))], Color("#ffd35c"))


## 스크린샷 도구용
func debug_action(act: String) -> void:
	if act.begins_with("select:"):
		selected = act.substr(7)
		_mark_dirty()
	elif act == "auto":
		Game.auto_party()
