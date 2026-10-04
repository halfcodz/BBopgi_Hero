extends Control
## 개발용: 드래곤 20종 × 별 단계를 한 화면에 그린다.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/gallery.png")
	get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#fff4e6"))
	var font := get_theme_default_font()
	for i in DragonDB.DRAGONS.size():
		var d: Dictionary = DragonDB.DRAGONS[i]
		var c := Vector2(80 + (i % 4) * 175, 90 + (i / 4) * 175)
		DragonArt.draw_dragon(self, c, 42, d.element, d.rarity, 1 + (i % 4) + (1 if i >= 16 else 0), 1.0)
		draw_string(font, c + Vector2(-60, 78), "%s %s" % [Balance.RARITY_CODES[d.rarity], d.name], HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color("#4a3b52"))
	for s in 6:
		DragonArt.draw_dragon(self, Vector2(70 + s * 115, 1060), 40, 0, 3, s + 1, 2.0, -1.0 if s % 2 else 1.0)
		draw_string(font, Vector2(20 + s * 115, 1140), "★%d" % (s + 1), HORIZONTAL_ALIGNMENT_CENTER, 100, 20, Color("#4a3b52"))
