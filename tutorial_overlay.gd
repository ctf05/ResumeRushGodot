extends Control

var current_step = 0
var tutorial_steps = [
	{"text": "Welcome to ResumeRush! Let's get started.", "highlight": null},
	{"text": "As a CEO, you'll review candidate resumes here.", "highlight": "candidate_list"},
	{"text": "Make offers to candidates using this input.", "highlight": "offer_input"},
	{"text": "As a Candidate, you'll see offers here.", "highlight": "offer_list"},
	{"text": "Keep an eye on the timer!", "highlight": "timer"},
	{"text": "You're all set! Good luck!", "highlight": null}
]

func _ready():
	set_process_input(true)
	_show_current_step()

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		_next_step()

func _show_current_step():
	var step = tutorial_steps[current_step]
	$Label.text = step.text
	if step.highlight:
		_highlight_element(step.highlight)
	else:
		_clear_highlight()

func _next_step():
	current_step += 1
	if current_step >= tutorial_steps.size():
		queue_free()
	else:
		_show_current_step()

func _highlight_element(element_name):
	var element = get_node("../" + element_name)
	if element:
		var highlight = ColorRect.new()
		highlight.color = Color(1, 1, 0, 0.3)
		highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		element.add_child(highlight)

func _clear_highlight():
	for node in get_tree().get_nodes_in_group("tutorial_highlight"):
		node.queue_free()
