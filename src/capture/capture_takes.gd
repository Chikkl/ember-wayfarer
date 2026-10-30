class_name CaptureTakes
extends RefCounted
## Takes for capture mode: what the player does in front of the camera.
## A take may give items before the first frame ("items") and move the player
## ("start", tiles from the campfire). Step kinds: see CaptureDirector.
## Decision: docs/decisions.md, 2026-10-30.

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
