extends Control

@onready var console: RichTextLabel = $p_MainTerminal/vb_Terminal/hb_Consol_and_News/rt_Console
@onready var input: LineEdit = $p_MainTerminal/vb_Terminal/le_UserInput

## Typewriter speed in characters per second
@export var chars_per_second := 400.0

## Easter egg: slow typing speed and timings
@export var egg_chars_per_second := 9.0
@export var egg_hold_time := 2.0
@export var egg_gap_time := 1.0

@export_group("Audio")
## Leave empty to load from CLICK_PATH
@export var click_sound: AudioStream
## Leave empty to load from KNOCK_PATH
@export var knock_sound: AudioStream
@export var click_volume_db := -6.0
@export var knock_volume_db := 0.0
## Random pitch variation so the clicks don't sound robotic (0 = off)
@export var click_pitch_variation := 0.06
## Minimum time between two clicks (keeps fast typing from turning into a buzz)
@export var click_min_interval := 0.1

const CLICK_PATH := "res://Klick.ogg"
const KNOCK_PATH := "res://KnockKnock.ogg"
const CLICK_POOL_SIZE := 4

## Easter egg text, one screen per entry. Edit freely.
## The knock sound plays after the LAST entry has been typed.
const EGG_SCREENS: Array[String] = [
	"Wake up, Neo...",
	"The Matrix has you...",
	"Follow the white rabbit.",
	"Knock, knock, Neo.",
]

var commands: Dictionary = {}

var command_history: Array[String] = []
var history_index := -1

# Typewriter state
var _queue: Array = []        # entries: [text: String, instant: bool]
var _typing := false
var _skip := false
var _generation := 0          # bumped on cls so running animations abort
var _cps_override := 0.0      # > 0 replaces chars_per_second
var _scene_running := false   # true while the easter egg plays

# Audio state
var _click_players: Array[AudioStreamPlayer] = []
var _click_index := 0
var _last_click_time := 0.0
var _knock_player: AudioStreamPlayer
var _last_input_length := 0


func _ready():

	load_commands()
	_setup_audio()

	# Keep the LineEdit focused after pressing Enter (Godot 4.3+)
	input.keep_editing_on_text_submit = true

	# Auto-scroll to the newest line
	console.scroll_following = true

	console.clear()

	print_line("LindOS Alpha 0.1")
	print_line("Connected.")
	print_line("Type HELP for available commands.")
	print_line("")

	input.text_submitted.connect(_on_command_submitted)
	input.text_changed.connect(_on_input_text_changed)

	_force_focus()


func _force_focus():

	# Wait one frame so this runs after any focus release
	await get_tree().process_frame
	input.grab_focus()


func load_commands():

	var path := "res://Assets/json/commands.json"

	if !FileAccess.file_exists(path):
		push_error("commands.json not found")
		return

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Could not open commands.json")
		return

	var json = JSON.parse_string(file.get_as_text())

	if typeof(json) == TYPE_DICTIONARY:
		commands = json


# ---------------------------------------------------------------------------
# Audio
# ---------------------------------------------------------------------------

func _setup_audio():

	if click_sound == null and ResourceLoader.exists(CLICK_PATH):
		click_sound = load(CLICK_PATH)

	if knock_sound == null and ResourceLoader.exists(KNOCK_PATH):
		knock_sound = load(KNOCK_PATH)

	if click_sound == null:
		push_warning("Click sound not found: " + CLICK_PATH)
	if knock_sound == null:
		push_warning("Knock sound not found: " + KNOCK_PATH)

	# A small pool, so quick clicks can overlap instead of cutting each other off
	for i in CLICK_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.stream = click_sound
		p.volume_db = click_volume_db
		add_child(p)
		_click_players.append(p)

	_knock_player = AudioStreamPlayer.new()
	_knock_player.stream = knock_sound
	_knock_player.volume_db = knock_volume_db
	add_child(_knock_player)


func play_click():

	if click_sound == null:
		return

	var now := Time.get_ticks_msec() / 1000.0

	if now - _last_click_time < click_min_interval:
		return

	_last_click_time = now

	var p := _click_players[_click_index]
	_click_index = (_click_index + 1) % _click_players.size()

	p.pitch_scale = 1.0 + randf_range(-click_pitch_variation, click_pitch_variation)
	p.play()


func _on_input_text_changed(new_text: String):

	# Click only when characters are added, not when deleting
	if new_text.length() > _last_input_length:
		play_click()

	_last_input_length = new_text.length()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event):

	# Ignore keyboard shortcuts while the easter egg plays
	if _scene_running:
		return

	if event is InputEventKey and event.pressed:

		match event.keycode:

			KEY_UP:
				history_up()
				get_viewport().set_input_as_handled()

			KEY_DOWN:
				history_down()
				get_viewport().set_input_as_handled()

			KEY_ESCAPE:
				# Skip the typewriter animation
				if _typing:
					_skip = true
					get_viewport().set_input_as_handled()


func history_up():

	if command_history.is_empty():
		return

	if history_index == -1:
		history_index = command_history.size() - 1
	elif history_index > 0:
		history_index -= 1

	_set_input_text(command_history[history_index])


func history_down():

	if command_history.is_empty():
		return

	if history_index < command_history.size() - 1:
		history_index += 1
		_set_input_text(command_history[history_index])
	else:
		history_index = -1
		_set_input_text("")


func _set_input_text(text: String):

	input.text = text
	input.caret_column = text.length()
	_last_input_length = text.length()


func _on_command_submitted(command: String):

	if _scene_running:
		return

	command = command.strip_edges()

	input.clear()
	_last_input_length = 0

	if command.is_empty():
		_force_focus()
		return

	command_history.append(command)
	history_index = -1

	# The user's own input is echoed instantly
	print_line("> " + command, true)

	execute_command(command)

	_force_focus()


func execute_command(command: String):

	# Easter egg (works with or without the question mark)
	if command.to_lower().trim_suffix("?").strip_edges() == "what is the matrix":
		play_wake_up_scene()
		return

	var args := command.split(" ", false)

	if args.is_empty():
		return

	var cmd := args[0].to_lower()

	match cmd:

		"cls":
			_generation += 1
			_queue.clear()
			console.clear()
			console.visible_characters = -1

		"help":
			show_help()

		"start":
			print_line("Starting new game...")

			# get_tree().change_scene_to_file(
			#	"res://scenes/game.tscn"
			# )

		"load":

			if args.size() < 2:
				print_line("Usage: load <save_name>")
				return

			var save_name := args[1]

			print_line("Loading save '%s'..." % save_name)

			# SaveManager.load_game(save_name)

		"settings":
			print_line("Opening settings menu...")

			# settings window

		"info":

			print_line("LindOS Alpha 0.1")
			print_line("")
			print_line("A Matrix-inspired hacking RPG.")
			print_line("You are an Operator working for ROGAN.")
			print_line("Your goal is to awaken people trapped inside the System.")

		"quit":

			print_line("Disconnecting...")

			# Let the text finish typing, then wait a moment
			await _wait_for_typing()

			await get_tree().create_timer(1.0).timeout

			get_tree().quit()

		_:

			print_line("Unknown command: " + cmd)
			print_line("Type HELP for available commands.")


func show_help():

	print_line("Available commands:")
	print_line("")

	print_line("cls")
	print_line("help")
	print_line("start")
	print_line("load <name>")
	print_line("settings")
	print_line("info")
	print_line("quit")


# ---------------------------------------------------------------------------
# Easter egg
# ---------------------------------------------------------------------------

func play_wake_up_scene():

	_scene_running = true
	input.editable = false

	# Let anything already printing finish, then blank the screen
	await _wait_for_typing()

	_generation += 1
	_queue.clear()
	console.clear()
	console.visible_characters = -1

	_cps_override = egg_chars_per_second

	await get_tree().create_timer(1.5).timeout

	for i in EGG_SCREENS.size():

		var is_last := i == EGG_SCREENS.size() - 1

		print_line("[color=#00ff41]" + EGG_SCREENS[i] + "[/color]")

		await _wait_for_typing()

		var hold := egg_hold_time

		# The knock plays once the final line has been typed
		if is_last and knock_sound != null:
			_knock_player.play()
			hold = max(hold, knock_sound.get_length())

		await get_tree().create_timer(hold).timeout

		console.clear()

		await get_tree().create_timer(egg_gap_time).timeout

	_cps_override = 0.0

	print_line("Connection restored.")
	print_line("")

	await _wait_for_typing()

	input.editable = true
	_scene_running = false

	_force_focus()


func _wait_for_typing():

	while _typing:
		await get_tree().process_frame


# ---------------------------------------------------------------------------
# Typewriter output
# ---------------------------------------------------------------------------

## Queues a line for output. Lines are typed one after another.
func print_line(text: String, instant := false):

	_queue.append([text, instant])

	if !_typing:
		_run_queue()


func _run_queue():

	_typing = true
	_skip = false

	var gen := _generation

	while !_queue.is_empty():

		var entry: Array = _queue.pop_front()
		var text: String = entry[0]
		var instant: bool = entry[1]

		if instant or _skip or text.is_empty():
			console.visible_characters = -1
			console.append_text(text + "\n")
			continue

		# Hide the new text, append it, then reveal it character by character
		var start := console.get_total_character_count()
		console.visible_characters = start
		console.append_text(text + "\n")

		var total := console.get_total_character_count()
		var shown := float(start)
		var last_shown := start

		while shown < total:

			await get_tree().process_frame

			# console was cleared while typing
			if gen != _generation:
				_typing = false
				return

			if _skip:
				break

			var cps := _cps_override if _cps_override > 0.0 else chars_per_second
			shown += cps * get_process_delta_time()

			var now := int(shown)
			console.visible_characters = now

			# One click per newly revealed character (rate-limited in play_click)
			if now > last_shown:
				play_click()
				last_shown = now

		console.visible_characters = -1

	_typing = false
	_skip = false
