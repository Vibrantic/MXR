extends Control

@onready var output: RichTextLabel = $MainPanel/Boot

enum State {
	BOOT,
	BIOS_MENU,
	BOOT_MENU,
	PAGE
}

var state := State.BOOT

var waiting_for_input := false
var hidden_code := ""

var bios_index := 0
var boot_index := 0

var current_page := ""
var hidden_unlocked := false

var bios_items := [
	"System",
	"Security",
	"Boot",
	"Matrix Interface",
	"Diagnostics",
	"Advanced",
	"Exit"
]

var boot_items := [
	"LindOS Installation",
	"Safe Mode",
	"Recovery Environment",
	"Operator Console",
	"Hidden Entries"
]

var hidden_items := [
	"Source Access",
	"Architect Session",
	"White Rabbit",
	"There Is No Spoon",
	"Wake Up"
]

var boot_lines := [
	"LindOS Systems BIOS v5.12.447",
	"Copyright (C) LindOS Systems",
	"",
	"CPU: LindCore LX-8 @ 4.20GHz",
	"Memory Test: 16384 MB OK",
	"",
	"Initializing hardware...",
	"Keyboard ............ OK",
	"Mouse ............... OK",
	"Display Adapter ..... OK",
	"Storage Controller .. OK",
	"Network Interface ... OK",
	"",
	"System Integrity Check .... PASSED",
	"",
	"Authorized Operator Detected",
	"",
	"Press DEL to enter Setup",
	"Press F12 for Boot Options"
]

func _ready():
	run_boot()

func run_boot() -> void:

	output.clear()

	for line in boot_lines:

		output.append_text(line + "\n")

		if line.contains("Press DEL"):

			waiting_for_input = true

			var timer := get_tree().create_timer(5.0)

			await timer.timeout

			if state == State.BOOT:
				continue_boot()
				return

		await get_tree().create_timer(0.08).timeout

func continue_boot() -> void:

	waiting_for_input = false

	output.append_text("\n")
	output.append_text("Booting LindOS...\n")

	await get_tree().create_timer(1.0).timeout

	output.append_text("Loading kernel...\n")

	await get_tree().create_timer(1.0).timeout

	output.append_text("Starting services...\n")

	await get_tree().create_timer(1.0).timeout

	output.append_text("Launching desktop services...\n")

	await get_tree().create_timer(1.0).timeout

	output.append_text("\nREADY.\n")

	# TODO:
	# get_tree().change_scene_to_file("res://scenes/kernel_boot.tscn")

func _input(event):

	if !(event is InputEventKey):
		return

	if !event.pressed:
		return

	match state:

		State.BOOT:
			handle_boot_input(event)

		State.BIOS_MENU:
			handle_bios_menu(event)

		State.BOOT_MENU:
			handle_boot_menu(event)

		State.PAGE:

			if event.keycode == KEY_ESCAPE:

				if current_page.begins_with("boot"):
					show_boot_menu()
				else:
					show_bios_menu()

func handle_boot_input(event: InputEventKey) -> void:

	if !waiting_for_input:
		return

	match event.keycode:

		KEY_DELETE:
			show_bios_menu()

		KEY_F12:
			show_boot_menu()

func show_bios_menu() -> void:

	state = State.BIOS_MENU
	render_bios_menu()

func render_bios_menu() -> void:

	output.clear()

	output.append_text(
		"LindOS Firmware Setup Utility v5.12\n\n"
	)

	for i in range(bios_items.size()):

		if i == bios_index:
			output.append_text("> ")
		else:
			output.append_text("  ")

		output.append_text(bios_items[i] + "\n")

	output.append_text(
		"\n↑↓ Select | ENTER Open | ESC Boot"
	)

func handle_bios_menu(event: InputEventKey) -> void:

	match event.keycode:

		KEY_UP:

			bios_index -= 1

			if bios_index < 0:
				bios_index = bios_items.size() - 1

			render_bios_menu()

		KEY_DOWN:

			bios_index += 1

			if bios_index >= bios_items.size():
				bios_index = 0

			render_bios_menu()

		KEY_ENTER, KEY_KP_ENTER:
			open_bios_page(bios_items[bios_index])

		KEY_ESCAPE:

			state = State.BOOT
			continue_boot()

func open_bios_page(page: String) -> void:

	current_page = page
	state = State.PAGE

	output.clear()

	match page:

		"System":
			output.append_text("""
System Information

CPU: LindCore LX-8
Memory: 16384 MB

Operator Status:
AUTHORIZED

Reality Layer:
UNKNOWN

Simulation Index:
REDACTED

ESC Return
""")

		"Security":
			output.append_text("""
Security Configuration

Operator Verification ...... Enabled
Neural Encryption .......... Enabled
Reality Filters ............ Enabled
Truth Suppression .......... Enabled

WARNING:
Modifying these values may
destabilize perceived reality.

ESC Return
""")

		"Boot":
			output.append_text("""
Boot Priority

1. LindOS Installation
2. Recovery Environment
3. Diagnostics
4. Zion Emergency Console

ACCESS DENIED

ESC Return
""")

		"Matrix Interface":
			output.append_text("""
Matrix Interface

Red Pill Protocol .... Disabled
Blue Pill Protocol ... Enabled
Agent Detection ...... Active
Awakening Events ..... Monitoring

Last Known Contact:
ROGAN

ESC Return
""")

		"Diagnostics":
			output.append_text("""
SYSTEM STATUS

Reality Integrity ...... 98.5%
Machine Activity ....... UNKNOWN
Operator Trace Risk .... LOW

External Signal:
DETECTED

ESC Return
""")

		"Advanced":
			output.append_text("""
Advanced Configuration

[X] Enable Debug Logs
[X] Enable Deep Scan
[X] Allow Unauthorized Truth
[ ] Disable Simulation

ERROR

Function unavailable while connected.

ESC Return
""")

		"Exit":
			show_bios_menu()

func show_boot_menu() -> void:

	state = State.BOOT_MENU
	render_boot_menu()

func render_boot_menu() -> void:

	output.clear()

	if hidden_unlocked:

		output.append_text(
			"LindBoot Hidden Entries\n\n"
		)

		for i in range(hidden_items.size()):

			if i == boot_index:
				output.append_text("> ")
			else:
				output.append_text("  ")

			output.append_text(
				hidden_items[i] + "\n"
			)

	else:

		output.append_text(
			"LindBoot Boot Manager\n\n"
		)

		for i in range(boot_items.size()):

			if i == boot_index:
				output.append_text("> ")
			else:
				output.append_text("  ")

			output.append_text(
				boot_items[i] + "\n"
			)

	output.append_text(
		"\nENTER Select | ESC Boot"
	)

func handle_boot_menu(event: InputEventKey) -> void:

	if event.unicode > 0:

		hidden_code += String.chr(event.unicode)
		hidden_code = hidden_code.to_upper()

		if hidden_code.ends_with("MATRIX"):

			hidden_unlocked = true
			boot_index = 0
			render_boot_menu()

	match event.keycode:

		KEY_UP:

			boot_index -= 1

			var max_items = hidden_items.size() if hidden_unlocked else boot_items.size()

			if boot_index < 0:
				boot_index = max_items - 1

			render_boot_menu()

		KEY_DOWN:

			boot_index += 1

			var max_items = hidden_items.size() if hidden_unlocked else boot_items.size()

			if boot_index >= max_items:
				boot_index = 0

			render_boot_menu()

		KEY_ENTER, KEY_KP_ENTER:
			open_boot_selection()

		KEY_ESCAPE:

			state = State.BOOT
			continue_boot()

func open_boot_selection() -> void:

	state = State.PAGE
	output.clear()

	if hidden_unlocked:

		var selected: String = hidden_items[boot_index]

		match selected:

			"Source Access":
				output.append_text("""
Accessing Source...

Permission denied.

You are not ready.

ESC Return
""")

			"Architect Session":
				output.append_text("""
The first Matrix
was designed to be perfect.

It failed.

ESC Return
""")

			"White Rabbit":
				output.append_text("""
Follow the White Rabbit.

ESC Return
""")

			"There Is No Spoon":
				output.append_text("""
There is no spoon.

It is only yourself.

ESC Return
""")

			"Wake Up":
				output.append_text("""
Wake up, Operator.

The system cannot tell you
who you are.

You must choose.

ESC Return
""")

		current_page = "boot_hidden"
		return

	var selected_boot: String = boot_items[boot_index]

	match selected_boot:

		"LindOS Installation":
			output.append_text("""
Booting LindOS...

ESC Return
""")

		"Safe Mode":
			output.append_text("""
Booting LindOS Safe Mode...

Reality Filters Disabled
Agent Tracking Disabled

ESC Return
""")

		"Recovery Environment":
			output.append_text("""
Loading Recovery Environment...

Searching backups...
Searching operators...

No backups found.

ESC Return
""")

		"Operator Console":
			output.append_text("""
Authorized Operators

MORPHEUS
TRINITY
TANK
DOZER
ROGAN

ROGAN:
"If you're seeing this,
you're asking the right questions."

ESC Return
""")

		"Hidden Entries":
			output.append_text("""
Hidden entries detected.

Type MATRIX while in the boot menu.

ESC Return
""")

	current_page = "boot_menu"
