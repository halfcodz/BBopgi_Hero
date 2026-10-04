extends Control
## 미션 탭: 일일 미션 4종 (기획서 10.1)

var list: VBoxContainer
var reset_label: Label
var _t := 0.0


func _ready() -> void:
	var v := UIKit.vbox(12)
	var m := UIKit.margin(v, 20, 16, 20, 12)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	var head := UIKit.hbox(8)
	v.add_child(head)
	var title := UIKit.label("일일 미션", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	reset_label = UIKit.label("", 18, UIKit.TEXT_SOFT)
	head.add_child(reset_label)
	list = UIKit.vbox(10)
	v.add_child(list)
	var tip := UIKit.label("미션 코인으로 인형뽑기를 더 할 수 있어요. 매일 오전 5시에 초기화돼요.", 18, UIKit.TEXT_SOFT)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	Game.missions_changed.connect(_rebuild)
	_rebuild()


func on_shown() -> void:
	_rebuild()


func _process(delta: float) -> void:
	_t += delta
	if _t >= 1.0:
		_t = 0.0
		var now := Time.get_datetime_dict_from_system()
		var sec_now: int = now.hour * 3600 + now.minute * 60 + now.second
		var reset_sec := Game.DAILY_RESET_HOUR * 3600
		var left := (reset_sec - sec_now + 86400) % 86400
		reset_label.text = "초기화까지 " + Num.fmt_time(left)


func _rebuild() -> void:
	if list == null or not is_inside_tree():
		return
	UIKit.clear(list)
	for mission in Game.MISSIONS:
		list.add_child(_row(mission))


func _row(mission: Dictionary) -> Control:
	var claimed: bool = Game.mission_claimed.has(mission.key)
	var value := mini(Game.mission_value(mission.key), mission.goal)
	var c := UIKit.card(UIKit.PANEL_DARK if not claimed else Color(0, 0, 0, 0.05), 18)
	var h := UIKit.hbox(12)
	c.add_child(UIKit.margin(h, 4, 4, 4, 4))
	var v := UIKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UIKit.label("%s %d회" % [mission.name, mission.goal] if mission.key != "kills" else "%s %d마리" % [mission.name, mission.goal], 22))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.max_value = mission.goal
	bar.value = value
	bar.add_theme_stylebox_override("background", UIKit.box(Color(0, 0, 0, 0.1), 8, 0))
	bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.MINT, 8, 0))
	v.add_child(bar)
	v.add_child(UIKit.label("%d / %d" % [value, mission.goal], 17, UIKit.TEXT_SOFT))
	var reward := UIKit.hbox(4)
	reward.add_child(Widgets.currency_icon("coin", 30))
	reward.add_child(UIKit.label("x%d" % mission.reward, 22))
	h.add_child(reward)
	var b := UIKit.button("완료" if claimed else "받기", UIKit.MINT, 22, Vector2(110, 60))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = claimed or not Game.can_claim_mission(mission)
	b.pressed.connect(func():
		if Game.claim_mission(mission):
			Game.toast.emit("코인 +%d" % mission.reward, Color("#ff9be0")))
	h.add_child(b)
	return c
