class_name CaptureTakes
extends RefCounted
## Takes for capture mode: what the player does in front of the camera.
## A take may give items before the first frame ("items") and move the player
## ("start", tiles from the campfire). Step kinds: see CaptureDirector.
## Guide: docs/captures.md, "Режим съёмки".

const ALL := {
	# Reel "who I am and what the game is": the walk to the fire, gathering,
	# two trees, the bundle on the back and the way back to the fire.
	"reel-intro":
	{
		"items": {"stone_axe": 1},
		# The player walks in to the fire from the right.
		"start": Vector2(4.5, 1.0),
		"steps":
		[
			{"do": "wait", "time": 0.5},
			{"do": "walk_to", "target": "fire"},
			{"do": "wait", "time": 3.0},
			{"do": "walk_to", "target": "ground_stick"},
			{"do": "work"},
			{"do": "walk_to", "target": "ground_stone"},
			{"do": "work"},
			{"do": "walk_to", "target": "tree"},
			{"do": "work"},
			{"do": "collect"},
			{"do": "walk_to", "target": "tree"},
			{"do": "work"},
			{"do": "collect"},
			{"do": "zoom", "zoom": 3.0},
			{"do": "wait", "time": 2.0},
			{"do": "zoom", "zoom": 1.5},
			{"do": "walk_to", "target": "fire"},
			{"do": "zoom", "zoom": 3.0},
			{"do": "wait", "time": 3.0},
		],
	},
	# The chopper fells a tree with light quick strikes and leaves a stump
	# it cannot uproot.
	"chopper-tree":
	{
		"items": {"chopper": 1},
		"steps":
		[
			{"do": "walk_to", "target": "tree"},
			{"do": "zoom", "zoom": 2.5},
			{"do": "work"},
			{"do": "collect"},
			{"do": "wait", "time": 1.5},
		],
	},
	# The recipe tree on the first level: open the screen, take the first node.
	"tree-first-node":
	{
		"xp": 30,
		"steps":
		[
			{"do": "wait", "time": 1.0},
			{"do": "press", "action": "tree"},
			{"do": "wait", "time": 1.5},
			{"do": "click_tree_node", "node": "stonework"},
			{"do": "wait", "time": 2.0},
			{"do": "press", "action": "tree"},
			{"do": "wait", "time": 1.0},
		],
	},
	# The first axe from scratch: stones into a chopper, a shaped stick, a plait,
	# a tree felled with the chopper for the first level, the first node, the axe.
	"first-axe":
	{
		"steps":
		[
			{"do": "press", "action": "craft"},
			{"do": "wait", "time": 1.5},
			{"do": "walk_to", "target": "ground_stone"},
			{"do": "work"},
			{"do": "walk_to", "target": "ground_stone"},
			{"do": "work"},
			{"do": "click_recipe", "recipe": "chopper"},
			{"do": "wait", "time": 2.4},
			{"do": "walk_to", "target": "ground_stick"},
			{"do": "work"},
			{"do": "click_recipe", "recipe": "shaped_stick"},
			{"do": "wait", "time": 2.4},
			{"do": "walk_to", "target": "bush"},
			{"do": "work"},
			{"do": "click_recipe", "recipe": "plait"},
			{"do": "wait", "time": 1.4},
			{"do": "walk_to", "target": "tree"},
			{"do": "work"},
			{"do": "collect"},
			{"do": "press", "action": "tree"},
			{"do": "wait", "time": 1.2},
			{"do": "click_tree_node", "node": "stonework"},
			{"do": "wait", "time": 1.2},
			{"do": "press", "action": "craft"},
			{"do": "wait", "time": 1.0},
			{"do": "click_recipe", "recipe": "stone_axe"},
			{"do": "wait", "time": 2.4},
			{"do": "walk_to", "target": "tree"},
			{"do": "work"},
			{"do": "collect"},
			{"do": "wait", "time": 1.5},
		],
	},
	# Reel close-up of the stamina ring: work until exhaustion near the camp,
	# then sit by the fire while the ring fills.
	"reel-ring":
	{
		"items": {"stone_axe": 1},
		"steps":
		[
			{"do": "walk_to", "target": "tree"},
			{"do": "work", "until": "exhausted"},
			{"do": "walk_to", "target": "fire"},
			{"do": "rest"},
			{"do": "zoom", "zoom": 3.0},
			{"do": "wait", "time": 4.0},
		],
	},
}
