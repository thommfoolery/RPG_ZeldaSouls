# autoload/TitleCardManager.gd
extends CanvasLayer

var title_label: Label
var subtitle_label: Label
var title_queue: Array = []

# Small helper to prevent spamming the exact same title right after itself
var _last_shown_title: String = ""
var _last_shown_subtitle: String = ""

# ─── NEW: Signal for external tracing (connect in _ready() of suspect managers) ───
signal title_queued(main_text: String, subtitle_text: String, caller_path: NodePath)

func _ready() -> void:
	# Create UI manually — no race with scene tree
	_create_ui()
	print("[TitleCardManager] Ready — center title cards with subtitles")
	
	# Optional: connect this signal in _ready() of SceneEntryManager / BonfireManager / WorldManager etc.
	# Example: connect("title_queued", func(m, s, p): print("[TRACE] Title queued by ", p, " → ", m))

func is_playing() -> bool:
	return not title_queue.is_empty() or visible

func _create_ui() -> void:
	var center = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = VBoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 120)
	title_label.modulate.a = 0.0
	vbox.add_child(title_label)
	
	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 48)
	subtitle_label.modulate.a = 0.0
	vbox.add_child(subtitle_label)
	
	visible = false

func show_title(main_text: String, subtitle_text: String = "", linger: float = 4.0, warm_color: bool = false, first_visit_only: bool = false) -> void:
	# ─── HEAVY CALLER DEBUG ───
	var caller_stack = get_stack()
	var caller_info = "unknown"
	if caller_stack.size() >= 2:
		var caller = caller_stack[1]
		caller_info = "%s:%d in %s()" % [caller["source"].get_file(), caller["line"], caller["function"]]
	
	print("[TitleCardManager-CALL] show_title called from: ", caller_info)
	print("  └─ args: main=\"%s\" | sub=\"%s\" | linger=%.1f | warm=%s | first_only=%s" % [main_text, subtitle_text, linger, warm_color, first_visit_only])
	
	# Emit signal so other autoloads can trace who queues what
	title_queued.emit(main_text, subtitle_text, get_path())
	
	# Optional: you can re-enable area-first-visit check later if needed
	# if first_visit_only and WorldStateManager and ... already discovered → return
	
	# Quick deduplication: don't queue the exact same thing that's already playing or just played
	if title_label.text == main_text and subtitle_label.text == subtitle_text and visible:
		print("[TitleCardManager] Already displaying → skip duplicate: ", main_text)
		return
	
	if _last_shown_title == main_text and _last_shown_subtitle == subtitle_text:
		print("[TitleCardManager] Same title just finished → skip duplicate: ", main_text)
		return
	
	var new_entry = {
		"main": main_text,
		"sub": subtitle_text,
		"linger": linger,
		"warm": warm_color
	}
	
	title_queue.append(new_entry)
	print("[TitleCardManager] Queued title: \"%s\" (subtitle: \"%s\") | queue size now: %d" % [main_text, subtitle_text, title_queue.size()])
	
	# Only start displaying if this is the first in queue and nothing is currently visible/playing
	if title_queue.size() == 1 and not visible:
		_display_next()

func _display_next() -> void:
	if title_queue.is_empty():
		visible = false
		return
	
	var entry = title_queue[0]
	
	# ─── DEBUG PRINT ───
	var scene_file = "no_scene"
	if get_tree().current_scene:
		scene_file = get_tree().current_scene.scene_file_path.get_file()
	
	print("[TitleCard-DEBUG] START DISPLAY: \"%s\" | \"%s\" | queue was: %d | scene: %s | remaining queue: %d" % [
		entry.main, entry.sub, title_queue.size(), scene_file, title_queue.size() - 1
	])
	
	# Remember what we just showed (for deduplication)
	_last_shown_title = entry.main
	_last_shown_subtitle = entry.sub
	
	title_label.text = entry.main
	subtitle_label.text = entry.sub
	
	if entry.warm:
		title_label.modulate = Color(1.2, 0.9, 0.6, 0.0)
		subtitle_label.modulate = Color(1.1, 0.8, 0.5, 0.0)
	else:
		title_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		subtitle_label.modulate = Color(0.9, 0.9, 0.9, 0.0)
	
	visible = true
	
	var tween_in = create_tween().set_parallel()
	tween_in.tween_property(title_label, "modulate:a", 1.0, 0.8)
	tween_in.tween_property(subtitle_label, "modulate:a", 1.0, 0.8)
	await tween_in.finished
	
	await get_tree().create_timer(entry.linger).timeout
	
	var tween_out = create_tween().set_parallel()
	tween_out.tween_property(title_label, "modulate:a", 0.0, 0.8)
	tween_out.tween_property(subtitle_label, "modulate:a", 0.0, 0.8)
	await tween_out.finished
	
	title_queue.pop_front()
	
	print("[TitleCardManager] Finished displaying: \"%s\" | queue remaining: %d" % [entry.main, title_queue.size()])
	
	_display_next()
