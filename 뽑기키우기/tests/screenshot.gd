extends Node
## 개발용 스크린샷 도구.
## xvfb-run godot --rendering-driver opengl3 --resolution 720x1280 --path . res://tests/screenshot.tscn -- tab=gacha wait=3 out=/tmp/shot.png gold=1e6 coins=50

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if args.has("fresh"):
		Game.reset_save()
		Game.offline_report = {}
	if args.has("gold"):
		Game.add_gold(float(args.gold), false)
	if args.has("coins"):
		Game.add_coins(int(args.coins))
	if args.has("stage"):
		Game.stage = int(args.stage); Game.max_stage = Game.stage; Game.best_stage = maxi(Game.best_stage, Game.stage)
	if args.has("pulls"):
		Game.spend_coins(0)
		Gacha.pull(int(args.pulls))
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	if args.has("tab"):
		main.switch_tab(args.tab)
	var actions: String = args.get("do", "")
	await get_tree().create_timer(float(args.get("wait", "2"))).timeout
	for act in actions.split(",", false):
		if main.panels.has(main.current_tab) and main.panels[main.current_tab].has_method("debug_action"):
			main.panels[main.current_tab].debug_action(act)
		await get_tree().create_timer(float(args.get("step", "1.0"))).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.get("out", "/tmp/shot.png"))
	Game.save_game()
	get_tree().quit()
