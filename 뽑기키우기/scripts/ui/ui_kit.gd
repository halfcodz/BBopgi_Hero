class_name UIKit
extends RefCounted
## 공통 UI 생성 도우미와 테마 색.

const BG := Color("#2b2545")
const PANEL := Color("#fff4e6")
const PANEL_DARK := Color("#f3e2cf")
const TEXT := Color("#4a3b52")
const TEXT_SOFT := Color("#8a7a91")
const PINK := Color("#ff8fb1")
const MINT := Color("#5fd3b0")
const SKY := Color("#6cb6ff")
const GOLD := Color("#ffc94a")
const GRAY := Color("#c9bfc9")
const RED_DOT := Color("#ff4d6d")


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.8))
	t.set_stylebox("normal", "Button", box(PINK, 16, 3))
	t.set_stylebox("hover", "Button", box(PINK.lightened(0.1), 16, 3))
	t.set_stylebox("pressed", "Button", box(PINK.darkened(0.12), 16, 0))
	t.set_stylebox("disabled", "Button", box(GRAY, 16, 0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 22, 0))
	t.set_stylebox("panel", "Panel", box(PANEL, 22, 0))
	var grabber := box(PINK, 6, 0)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.06), 6, 0))
	return t


static func box(color: Color, radius := 16, shadow := 0, border := 0, border_color := Color.WHITE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.18)
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(0, shadow)
		sb.expand_margin_bottom = 0
		sb.border_width_bottom = shadow
		sb.border_color = color.darkened(0.2)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	return sb


static func label(text: String, size := 24, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func button(text: String, color := PINK, size := 24, min_size := Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	if color != PINK:
		b.add_theme_stylebox_override("normal", box(color, 16, 3))
		b.add_theme_stylebox_override("hover", box(color.lightened(0.1), 16, 3))
		b.add_theme_stylebox_override("pressed", box(color.darkened(0.12), 16, 0))
	return b


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func margin(child: Control, l := 16, t := 12, r := 16, b := 12) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m


static func card(color := PANEL_DARK, radius := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius, 0))
	return p


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
